import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import '../models/airport.dart';

/// OpenAIP-backed airport service.
/// Fetches airport+runway data on demand per ICAO and caches locally.
/// Cache is invalidated each AIRAC cycle (28 days).
class AirportService {
  static const _baseUrl = 'https://api.core.openaip.net/api';

  static const _metaBoxName = 'airport_meta';
  static const _airportsBoxName = 'airports_box';
  static const _runwaysBoxName = 'runways_box';

  static late Box _metaBox;
  static late Box<Map> _airportsBox;
  static late Box<List> _runwaysBox;

  static final ValueNotifier<AirportDataStatus> status =
      ValueNotifier(AirportDataStatus.notInitialized);

  static bool get isReady => status.value == AirportDataStatus.ready;

  static String get apiKey => _metaBox.get('openaipApiKey', defaultValue: '');
  static Future<void> setApiKey(String key) => _metaBox.put('openaipApiKey', key.trim());
  static bool get hasApiKey => apiKey.isNotEmpty;

  static Future<void> init() async {
    debugPrint('[AirportService] init: opening Hive boxes…');
    _metaBox = await Hive.openBox(_metaBoxName);
    _airportsBox = await Hive.openBox<Map>(_airportsBoxName);
    _runwaysBox = await Hive.openBox<List>(_runwaysBoxName);
    debugPrint('[AirportService] init: ${_airportsBox.length} airports in cache');
    // With on-demand fetching, we're always "ready" — data is fetched per query
    status.value = AirportDataStatus.ready;
  }

  /// AIRAC cycle identifier (e.g. "2506").
  /// Uses a known reference date and counts 28-day cycles forward,
  /// then derives year + ordinal from the cycle's effective date.
  static String currentAiracCycle() {
    // Reference: AIRAC 2501 effective 2025-01-23
    final ref = DateTime.utc(2025, 1, 23);
    final now = DateTime.now().toUtc();
    final days = now.difference(ref).inDays;
    // Effective date of the current cycle
    final effectiveDate = ref.add(Duration(days: (days < 0 ? days - 27 : days) ~/ 28 * 28));
    // Count how many cycles started on or after Jan 1 of that year
    final jan1 = DateTime.utc(effectiveDate.year, 1, 1);
    final ordinal = (effectiveDate.difference(jan1).inDays ~/ 28) + 1;
    final yy = effectiveDate.year % 100;
    return '${yy.toString().padLeft(2, '0')}${ordinal.toString().padLeft(2, '0')}';
  }

  /// Check if cache should be cleared for new AIRAC cycle.
  static Future<void> checkAndUpdate() async {
    final lastCycle = _metaBox.get('lastAiracCycle', defaultValue: '');
    final current = currentAiracCycle();
    debugPrint('[AirportService] AIRAC check: last=$lastCycle current=$current');
    if (lastCycle != current) {
      debugPrint('[AirportService] New AIRAC cycle — clearing cache');
      await _airportsBox.clear();
      await _runwaysBox.clear();
      await _metaBox.put('lastAiracCycle', current);
    }
    status.value = AirportDataStatus.ready;
  }

  static String? get lastUpdateInfo {
    final cycle = _metaBox.get('lastAiracCycle', defaultValue: '');
    if (cycle.isEmpty) return null;
    return 'AIRAC $cycle • ${_airportsBox.length} airports cached';
  }

  static String get statusMessage {
    switch (status.value) {
      case AirportDataStatus.notInitialized:
        return 'Airport service not initialized';
      case AirportDataStatus.ready:
        return lastUpdateInfo ?? 'Ready';
      case AirportDataStatus.error:
        return 'Failed to fetch airport data. Check your internet connection and API key.';
    }
  }

  /// Fetch airport by ICAO — returns cached data or fetches from OpenAIP.
  static Future<Airport?> fetchAirport(String icao) async {
    final key = icao.toUpperCase();

    // Check cache — only use if we also have runways cached
    final cached = _airportsBox.get(key);
    final cachedRunways = _runwaysBox.get(key);
    if (cached != null && cachedRunways != null) {
      debugPrint('[AirportService] Cache hit: $key');
      return Airport.fromJson(Map<String, dynamic>.from(cached));
    }

    // Fetch from OpenAIP
    if (!hasApiKey) {
      debugPrint('[AirportService] No API key configured — cannot fetch');
      return null;
    }
    debugPrint('[AirportService] Fetching $key from OpenAIP…');
    try {
      final uri = Uri.parse('$_baseUrl/airports').replace(queryParameters: {
        'search': key,
        'searchOptional': 'icaoCode',
        'limit': '5',
        'apiKey': apiKey,
      });
      final resp = await http.get(uri, headers: {'Accept': 'application/json'});
      debugPrint('[AirportService] OpenAIP response: ${resp.statusCode} (${resp.body.length} bytes)');

      if (resp.statusCode != 200) {
        debugPrint('[AirportService] ERROR: HTTP ${resp.statusCode}: ${resp.body}');
        return null;
      }

      final json = jsonDecode(resp.body);
      final items = json['items'] as List<dynamic>? ?? [];

      for (final item in items) {
        final ap = _parseAirport(item);
        if (ap == null) continue;
        // Cache it
        await _airportsBox.put(ap.icao, ap.toJson());
        // Parse and cache runways (always store, even if empty)
        final runways = _parseRunways(item, ap.icao);
        await _runwaysBox.put(ap.icao, runways.map((r) => r.toJson()).toList());
        debugPrint('[AirportService] Cached ${ap.icao}: ${ap.name}, ${runways.length} runways');
        if (ap.icao == key) return ap;
      }

      debugPrint('[AirportService] No match for $key in OpenAIP results');
      return null;
    } catch (e, stack) {
      debugPrint('[AirportService] ERROR fetching $key: $e');
      debugPrint('[AirportService] Stack: $stack');
      return null;
    }
  }

  /// Lookup airport from cache only (for sync access).
  static Airport? getAirport(String icao) {
    final map = _airportsBox.get(icao.toUpperCase());
    if (map == null) return null;
    return Airport.fromJson(Map<String, dynamic>.from(map));
  }

  /// Get runways from cache.
  static List<Runway> getRunways(String icao) {
    final list = _runwaysBox.get(icao.toUpperCase());
    if (list == null) return [];
    return list.map((e) => Runway.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  /// Clear all cached airport/runway data.
  static Future<void> clearCache() async {
    await _airportsBox.clear();
    await _runwaysBox.clear();
    debugPrint('[AirportService] Cache cleared manually');
  }

  /// Search cached airports by ICAO prefix (for autocomplete).
  static List<Airport> search(String query, {int limit = 10}) {
    if (query.isEmpty) return [];
    final q = query.toUpperCase();
    final results = <Airport>[];
    for (final key in _airportsBox.keys) {
      if (key.toString().startsWith(q)) {
        final map = _airportsBox.get(key);
        if (map != null) {
          results.add(Airport.fromJson(Map<String, dynamic>.from(map)));
          if (results.length >= limit) break;
        }
      }
    }
    return results;
  }

  // ── OpenAIP JSON parsing ──

  static Airport? _parseAirport(Map<String, dynamic> item) {
    final icao = (item['icaoCode'] ?? '').toString().toUpperCase();
    if (icao.length != 4) return null;

    final geo = item['geometry'] as Map<String, dynamic>?;
    final coords = (geo?['coordinates'] as List<dynamic>?) ?? [];
    final lon = coords.isNotEmpty ? (coords[0] as num).toDouble() : 0.0;
    final lat = coords.length > 1 ? (coords[1] as num).toDouble() : 0.0;

    final elevM = (item['elevation']?['value'] ?? 0).toDouble();
    final elevUnit = (item['elevation']?['unit'] ?? 0);
    // OpenAIP elevation unit: 0 = meters, 1 = feet
    final elevFt = elevUnit == 1 ? elevM : elevM * 3.28084;

    return Airport(
      icao: icao,
      name: (item['name'] ?? '').toString(),
      elevationFt: elevFt,
      latDeg: lat,
      lonDeg: lon,
    );
  }

  static List<Runway> _parseRunways(Map<String, dynamic> item, String icao) {
    final rwyList = item['runways'] as List<dynamic>? ?? [];
    // OpenAIP returns one entry per runway direction.
    // Pair reciprocals by trueHeading (diff ≈ 180°) and same physical length.
    final entries = <Map<String, dynamic>>[
      for (final r in rwyList)
        if (r['operations'] != 3) Map<String, dynamic>.from(r),
    ];

    final results = <Runway>[];
    final used = <int>{};

    for (int i = 0; i < entries.length; i++) {
      if (used.contains(i)) continue;
      used.add(i);
      final a = entries[i];
      final aHdg = (a['trueHeading'] ?? 0).toDouble();
      final aLen = _dimToMeters(a['dimension']?['length']);

      // Find reciprocal: heading diff ≈ 180° and same physical length
      int? pairIdx;
      for (int j = i + 1; j < entries.length; j++) {
        if (used.contains(j)) continue;
        final b = entries[j];
        final bHdg = (b['trueHeading'] ?? 0).toDouble();
        final bLen = _dimToMeters(b['dimension']?['length']);
        final hdgDiff = (aHdg - bHdg).abs();
        if ((hdgDiff - 180).abs() < 10 && (aLen - bLen).abs() < 1) {
          pairIdx = j;
          break;
        }
      }

      final leIdent = (a['designator'] ?? '').toString();
      final lengthM = aLen;
      final widthM = _dimToMeters(a['dimension']?['width']);
      final surface = _parseSurface(a['surface']?['mainComposite'] ?? 0);
      final lighted = a['lighted'] == true;

      if (pairIdx != null) {
        used.add(pairIdx);
        final b = entries[pairIdx];
        final heIdent = (b['designator'] ?? '').toString();
        results.add(Runway(
          airportIcao: icao, leIdent: leIdent, heIdent: heIdent,
          lengthM: lengthM, widthM: widthM, surface: surface, lighted: lighted,
          le: _parseDirection(a, leIdent, lengthM),
          he: _parseDirection(b, heIdent, lengthM),
        ));
      } else {
        results.add(Runway(
          airportIcao: icao, leIdent: leIdent, heIdent: '',
          lengthM: lengthM, widthM: widthM, surface: surface, lighted: lighted,
          le: _parseDirection(a, leIdent, lengthM),
          he: RunwayDirection.fromPhysical(ident: '', lengthM: lengthM),
        ));
      }
    }

    return results;
  }

  static RunwayDirection _parseDirection(
      Map<String, dynamic> data, String ident, double physicalLengthM) {
    final dd = data['declaredDistance'];
    if (dd == null || dd is! Map) {
      return RunwayDirection.fromPhysical(ident: ident, lengthM: physicalLengthM);
    }
    final ddMap = Map<String, dynamic>.from(dd);

    final tora = _ddToMeters(ddMap['tora'], physicalLengthM);
    final toda = _ddToMeters(ddMap['toda'], tora);
    final lda = _ddToMeters(ddMap['lda'], physicalLengthM);

    return RunwayDirection(ident: ident, toraM: tora, todaM: toda, ldaM: lda);
  }

  static double _ddToMeters(Map<String, dynamic>? dd, double fallback) {
    if (dd == null) return fallback;
    final value = (dd['value'] ?? 0).toDouble();
    if (value <= 0) return fallback;
    final unit = dd['unit'] ?? 0;
    // 0 = meters, 1 = feet
    return unit == 1 ? value * 0.3048 : value;
  }

  static double _dimToMeters(Map<String, dynamic>? dim) {
    if (dim == null) return 0;
    final value = (dim['value'] ?? 0).toDouble();
    final unit = dim['unit'] ?? 0;
    return unit == 1 ? value * 0.3048 : value;
  }

  static String _parseSurface(int code) {
    const map = {
      0: 'Unknown', 1: 'Grass', 2: 'Asphalt', 3: 'Concrete',
      4: 'Sand', 5: 'Water', 6: 'Gravel', 7: 'Ice', 8: 'Snow',
      9: 'Soil', 10: 'Mixed',
    };
    return map[code] ?? 'Unknown';
  }
}

enum AirportDataStatus {
  notInitialized,
  ready,
  error,
}
