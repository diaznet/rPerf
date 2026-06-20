import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/foundation.dart' show debugPrint, kIsWeb;

import '../models/aircraft.dart';
import '../models/performance_point.dart';
import '../models/correction_factors.dart';
import 'hive_service.dart';

class ImportExportService {
  // ── Export (share) ──

  static Future<void> exportAllShare() async {
    final content = _buildCsvContent();
    final file = await _writeTempFile('aircraft_export.csv', content);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: 'rPerf Aircraft Export'));
  }

  static Future<void> exportSingleShare(Aircraft a) async {
    final content = _buildCsvContentForAircraft(a);
    final file = await _writeTempFile('${a.registration}.csv', content);
    await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], text: '${a.registration} (CSV)'));
  }

  // ── Export (save to file) ──

  static Future<String?> exportAllSave() async {
    final content = _buildCsvContent();
    return _saveToUserLocation('aircraft_export.csv', content);
  }

  static Future<String?> exportSingleSave(Aircraft a) async {
    final content = _buildCsvContentForAircraft(a);
    return _saveToUserLocation('${a.registration}.csv', content);
  }

  // ── Import ──

  static Future<void> importFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final text = await file.readAsString();
    await _importCsvText(text);
  }

  // ── Sample aircraft ──

  static const sampleAircraft = [
    {'name': 'Evektor SportStar RTC', 'file': 'plane_samples/sample-evss.csv'},
    {'name': 'Robin DR400 140b', 'file': 'plane_samples/sample-dr40.csv'},
    {'name': 'Diamond DA-20', 'file': 'plane_samples/sample-da20.csv'},
  ];

  static Future<void> importSample(String assetPath) async {
    final text = await rootBundle.loadString(assetPath);
    await _importCsvText(text);
  }

  // ── CSV building ──

  static List<String> _csvHeader() => [
    'aircraftId', 'registration', 'name', 'mtowKg', 'grassPenaltyPercentIfNoGrassData',
    'runwayType', 'weightKg', 'pressureAltitudeFt', 'temperatureC',
    'takeoffGroundRollM', 'takeoffOver50M', 'landingGroundRollM', 'landingOver50M',
    'headwindTO%/kt', 'tailwindTO%/kt', 'headwindLDG%/kt', 'tailwindLDG%/kt',
    'slopeTO%/%', 'slopeLDG%/%',
  ];

  static String _buildCsvContent() {
    final box = HiveService.aircraftBox();
    final rows = <List<String>>[_csvHeader()];
    for (final a in box.values) {
      if (a.points.isEmpty) {
        rows.add(_csvRowEmpty(a));
      } else {
        for (final p in a.points) {
          rows.add(_csvRowForPoint(a, p));
        }
      }
    }
    return rows.map((r) => r.map(_csvEscape).join(',')).join('\n');
  }

  static String _buildCsvContentForAircraft(Aircraft a) {
    final rows = <List<String>>[_csvHeader()];
    for (final p in a.points) {
      rows.add(_csvRowForPoint(a, p));
    }
    return rows.map((r) => r.map(_csvEscape).join(',')).join('\n');
  }

  static List<String> _csvRowEmpty(Aircraft a) => [
    a.id, a.registration, a.name, a.mtowKg.toString(),
    (a.grassPenaltyPercentIfNoGrassData ?? '').toString(),
    '', '', '', '', '', '', '', '',
    a.correctionFactors.headwindTakeoffPercentPerKt.toString(),
    a.correctionFactors.tailwindTakeoffPercentPerKt.toString(),
    a.correctionFactors.headwindLandingPercentPerKt.toString(),
    a.correctionFactors.tailwindLandingPercentPerKt.toString(),
    a.correctionFactors.slopeTakeoffPercentPerPercent.toString(),
    a.correctionFactors.slopeLandingPercentPerPercent.toString(),
  ];

  static List<String> _csvRowForPoint(Aircraft a, PerformancePoint p) {
    final tempC = p.deltaIsaC + (15.0 - 1.9812 * p.pressureAltitudeFt / 1000);
    return [
      a.id, a.registration, a.name, a.mtowKg.toString(),
      (a.grassPenaltyPercentIfNoGrassData ?? '').toString(),
      p.runwayType, p.weightKg.toString(), p.pressureAltitudeFt.toString(),
      tempC.toStringAsFixed(2),
      p.takeoffGroundRollM.toString(), p.takeoffOver50M.toString(),
      p.landingGroundRollM.toString(), p.landingOver50M.toString(),
      (p.headwindTakeoffPercentPerKt ?? a.correctionFactors.headwindTakeoffPercentPerKt).toString(),
      (p.tailwindTakeoffPercentPerKt ?? a.correctionFactors.tailwindTakeoffPercentPerKt).toString(),
      (p.headwindLandingPercentPerKt ?? a.correctionFactors.headwindLandingPercentPerKt).toString(),
      (p.tailwindLandingPercentPerKt ?? a.correctionFactors.tailwindLandingPercentPerKt).toString(),
      (p.slopeTakeoffPercentPerPercent ?? a.correctionFactors.slopeTakeoffPercentPerPercent).toString(),
      (p.slopeLandingPercentPerPercent ?? a.correctionFactors.slopeLandingPercentPerPercent).toString(),
    ];
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  // ── CSV parsing ──

  static Future<void> _importCsvText(String csv) async {
    final lines = csv.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    debugPrint('[Import] CSV: ${csv.length} chars, ${lines.length} lines');
    if (lines.isEmpty) return;
    final header = _parseCsvLine(lines.first);
    final col = {for (var i = 0; i < header.length; i++) header[i]: i};
    debugPrint('[Import] Header columns: $col');

    final byAc = <String, List<List<String>>>{};
    for (int i = 1; i < lines.length; i++) {
      final row = _parseCsvLine(lines[i]);
      if (row.isEmpty) continue;
      final aid = (col.containsKey('aircraftId') && col['aircraftId']! < row.length && row[col['aircraftId']!].isNotEmpty)
          ? row[col['aircraftId']!]
          : (col.containsKey('registration') ? row[col['registration']!] : 'unknown');
      byAc.putIfAbsent(aid, () => []).add(row);
    }

    for (final entry in byAc.entries) {
      final rows = entry.value;
      String id = const Uuid().v4();
      String reg = _getCell(rows.first, col, 'registration') ?? 'N/A';
      String name = _getCell(rows.first, col, 'name') ?? 'Aircraft';
      double mtow = double.tryParse(_getCell(rows.first, col, 'mtowKg') ?? '') ?? 0.0;
      double? grassPenalty = double.tryParse(_getCell(rows.first, col, 'grassPenaltyPercentIfNoGrassData') ?? '');

      final cf = CorrectionFactors(
        headwindTakeoffPercentPerKt: double.tryParse(_getCell(rows.first, col, 'headwindTO%/kt') ?? '') ?? 0.0,
        tailwindTakeoffPercentPerKt: double.tryParse(_getCell(rows.first, col, 'tailwindTO%/kt') ?? '') ?? 0.0,
        headwindLandingPercentPerKt: double.tryParse(_getCell(rows.first, col, 'headwindLDG%/kt') ?? '') ?? 0.0,
        tailwindLandingPercentPerKt: double.tryParse(_getCell(rows.first, col, 'tailwindLDG%/kt') ?? '') ?? 0.0,
        slopeTakeoffPercentPerPercent: double.tryParse(_getCell(rows.first, col, 'slopeTO%/%') ?? '') ?? 0.0,
        slopeLandingPercentPerPercent: double.tryParse(_getCell(rows.first, col, 'slopeLDG%/%') ?? '') ?? 0.0,
      );

      final pts = <PerformancePoint>[];
      for (final r in rows) {
        final rt = _getCell(r, col, 'runwayType') ?? '';
        if (rt.isEmpty) continue;
        final pa = double.tryParse(_getCell(r, col, 'pressureAltitudeFt') ?? '') ?? 0.0;
        final tempC = double.tryParse(_getCell(r, col, 'temperatureC') ?? '') ?? 15.0;
        final dIsa = tempC - (15.0 - 1.9812 * pa / 1000);
        final hwTo = double.tryParse(_getCell(r, col, 'headwindTO%/kt') ?? '');
        final twTo = double.tryParse(_getCell(r, col, 'tailwindTO%/kt') ?? '');
        final hwLd = double.tryParse(_getCell(r, col, 'headwindLDG%/kt') ?? '');
        final twLd = double.tryParse(_getCell(r, col, 'tailwindLDG%/kt') ?? '');
        final slTo = double.tryParse(_getCell(r, col, 'slopeTO%/%') ?? '');
        final slLd = double.tryParse(_getCell(r, col, 'slopeLDG%/%') ?? '');
        pts.add(PerformancePoint(
          runwayType: rt,
          weightKg: double.tryParse(_getCell(r, col, 'weightKg') ?? '') ?? 0.0,
          pressureAltitudeFt: pa,
          deltaIsaC: dIsa,
          takeoffGroundRollM: double.tryParse(_getCell(r, col, 'takeoffGroundRollM') ?? '') ?? 0.0,
          takeoffOver50M: double.tryParse(_getCell(r, col, 'takeoffOver50M') ?? '') ?? 0.0,
          landingGroundRollM: double.tryParse(_getCell(r, col, 'landingGroundRollM') ?? '') ?? 0.0,
          landingOver50M: double.tryParse(_getCell(r, col, 'landingOver50M') ?? '') ?? 0.0,
          headwindTakeoffPercentPerKt: hwTo,
          tailwindTakeoffPercentPerKt: twTo,
          headwindLandingPercentPerKt: hwLd,
          tailwindLandingPercentPerKt: twLd,
          slopeTakeoffPercentPerPercent: slTo,
          slopeLandingPercentPerPercent: slLd,
        ));
      }

      debugPrint('[Import] Aircraft "$reg" ($name): ${pts.length} points, mtow=$mtow');
      final ac = Aircraft(
        id: id,
        registration: reg,
        name: name,
        mtowKg: mtow,
        grassPenaltyPercentIfNoGrassData: grassPenalty,
        correctionFactors: cf,
        points: pts,
      );
      await HiveService.addAircraft(ac);
    }
  }

  static String? _getCell(List<String> row, Map<String, int> col, String key) {
    final idx = col[key];
    if (idx == null || idx >= row.length) return null;
    return row[idx];
  }

  static List<String> _parseCsvLine(String line) {
    final res = <String>[];
    final sb = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (inQuotes) {
        if (c == '"') {
          if (i + 1 < line.length && line[i + 1] == '"') {
            sb.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          sb.write(c);
        }
      } else {
        if (c == ',') {
          res.add(sb.toString());
          sb.clear();
        } else if (c == '"') {
          inQuotes = true;
        } else {
          sb.write(c);
        }
      }
    }
    res.add(sb.toString());
    return res;
  }

  // ── File helpers ──

  static Future<File> _writeTempFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    return file;
  }

  static Future<String?> _saveToUserLocation(String filename, String content) async {
    if (kIsWeb) return null;
    final bytes = utf8.encode(content);

    if (Platform.isAndroid || Platform.isIOS) {
      final temp = await _writeTempFile(filename, content);
      final params = SaveFileDialogParams(sourceFilePath: temp.path, fileName: filename);
      try {
        return await FlutterFileDialog.saveFile(params: params);
      } catch (e) {
        final xf = XFile(temp.path, mimeType: 'text/csv');
        await SharePlus.instance.share(ShareParams(files: [xf], text: 'rPerf export: $filename'));
        return null;
      }
    } else {
      final downloadsDir = await getDownloadsDirectory();
      final dir = downloadsDir ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }
}
