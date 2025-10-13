import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter_file_dialog/flutter_file_dialog.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../models/aircraft.dart';
import '../models/performance_point.dart';
import '../models/correction_factors.dart';
import 'hive_service.dart';

class ImportExportService {
  // SHARE variants (existing behavior)
  static Future<void> exportAllToJsonShare() async {
    final content = _buildJsonContent();
    final file = await _writeTempFile('aircraft_export.json', content);
    await Share.shareXFiles([XFile(file.path)], text: 'AirPerf Aircraft Export (JSON)');
  }

  static Future<void> exportAllToCsvShare() async {
    final content = _buildCsvContent();
    final file = await _writeTempFile('aircraft_export.csv', content);
    await Share.shareXFiles([XFile(file.path)], text: 'AirPerf Aircraft Export (CSV)');
  }

  // SAVE variants (new)
  static Future<String?> exportAllToJsonSave() async {
    final content = _buildJsonContent();
    return _saveToUserLocation('aircraft_export.json', content, mimeType: 'application/json');
  }

  static Future<String?> exportAllToCsvSave() async {
    final content = _buildCsvContent();
    return _saveToUserLocation('aircraft_export.csv', content, mimeType: 'text/csv');
  }

  // Helpers to build content
  static String _buildJsonContent() {
    final box = HiveService.aircraftBox();
    final list = box.values.map((a) => a.toJson()).toList();
    return const JsonEncoder.withIndent('  ').convert(list);
  }

  static String _buildCsvContent() {
    final box = HiveService.aircraftBox();
    final rows = <List<String>>[];
    rows.add([
      'aircraftId',
      'registration',
      'name',
      'mtowKg',
      'grassPenaltyPercentIfNoGrassData',
      'runwayType',
      'weightKg',
      'pressureAltitudeFt',
      'deltaIsaC',
      'takeoffGroundRollM',
      'takeoffOver50M',
      'landingGroundRollM',
      'landingOver50M',
      'headwindTO%/kt',
      'tailwindTO%/kt',
      'headwindLDG%/kt',
      'tailwindLDG%/kt',
      'slopeTO%/%',
      'slopeLDG%/%'
    ]);
    for (final a in box.values) {
      if (a.points.isEmpty) {
        rows.add([
          a.id,
          a.registration,
          a.name,
          a.mtowKg.toString(),
          (a.grassPenaltyPercentIfNoGrassData ?? '').toString(),
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
          a.correctionFactors.headwindTakeoffPercentPerKt.toString(),
          a.correctionFactors.tailwindTakeoffPercentPerKt.toString(),
          a.correctionFactors.headwindLandingPercentPerKt.toString(),
          a.correctionFactors.tailwindLandingPercentPerKt.toString(),
          a.correctionFactors.slopeTakeoffPercentPerPercent.toString(),
          a.correctionFactors.slopeLandingPercentPerPercent.toString(),
        ]);
      } else {
        for (final p in a.points) {
          rows.add([
            a.id,
            a.registration,
            a.name,
            a.mtowKg.toString(),
            (a.grassPenaltyPercentIfNoGrassData ?? '').toString(),
            p.runwayType,
            p.weightKg.toString(),
            p.pressureAltitudeFt.toString(),
            p.deltaIsaC.toString(),
            p.takeoffGroundRollM.toString(),
            p.takeoffOver50M.toString(),
            p.landingGroundRollM.toString(),
            p.landingOver50M.toString(),
            a.correctionFactors.headwindTakeoffPercentPerKt.toString(),
            a.correctionFactors.tailwindTakeoffPercentPerKt.toString(),
            a.correctionFactors.headwindLandingPercentPerKt.toString(),
            a.correctionFactors.tailwindLandingPercentPerKt.toString(),
            a.correctionFactors.slopeTakeoffPercentPerPercent.toString(),
            a.correctionFactors.slopeLandingPercentPerPercent.toString(),
          ]);
        }
      }
    }
    final csv = rows.map((r) => r.map(_csvEscape).join(',')).join('\n');
    return csv;
  }

  static String _csvEscape(String s) {
    if (s.contains(',') || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  static Future<File> _writeTempFile(String name, String content) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$name');
    await file.writeAsString(content);
    return file;
  }

  // Save to user-selected location:
  // - iOS: Files Save dialog (UIDocumentPicker)
  // - Android: Storage Access Framework (Create Document)
  // - Desktop: Downloads directory
  static Future<String?> _saveToUserLocation(String filename, String content, {required String mimeType}) async {
    // Web not supported
    if (kIsWeb) return null;

    final bytes = utf8.encode(content);

    if (Platform.isAndroid || Platform.isIOS) {
      // Create a temp file because FlutterFileDialog can save from sourceFilePath
      final temp = await _writeTempFile(filename, content);
      final params = SaveFileDialogParams(sourceFilePath: temp.path, fileName: filename);
      try {
        final savedPath = await FlutterFileDialog.saveFile(params: params);
        return savedPath; // may be null if user cancels
      } catch (e) {
        // Fallback: try share if save dialog fails
        final xf = XFile(temp.path, mimeType: mimeType);
        await Share.shareXFiles([xf], text: 'AirPerf export: $filename');
        return null;
      }
    } else {
      // Desktop fallback: write to Downloads
      final downloadsDir = await getDownloadsDirectory();
      final dir = downloadsDir ?? await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    }
  }

  // Existing import flow unchanged
  static Future<void> importFromFilePicker() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = File(result.files.single.path!);
    final ext = file.path.split('.').last.toLowerCase();

    if (ext == 'json') {
      final text = await file.readAsString();
      final List<dynamic> arr = jsonDecode(text);
      for (final item in arr) {
        final map = Map<String, dynamic>.from(item);
        var ac = Aircraft.fromJson(map);
        if (ac.id.isEmpty || HiveService.aircraftBox().containsKey(ac.id)) {
          ac = Aircraft(
            id: const Uuid().v4(),
            registration: ac.registration,
            name: ac.name,
            mtowKg: ac.mtowKg,
            correctionFactors: ac.correctionFactors,
            grassPenaltyPercentIfNoGrassData: ac.grassPenaltyPercentIfNoGrassData,
            points: ac.points,
          );
        }
        await HiveService.addAircraft(ac);
      }
    } else if (ext == 'csv') {
      final text = await file.readAsString();
      await _importCsvText(text);
    }
  }

  static Future<void> _importCsvText(String csv) async {
    final lines = csv.split(RegExp(r'\r?\n')).where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) return;
    final header = _parseCsvLine(lines.first);
    final col = {for (var i = 0; i < header.length; i++) header[i]: i};

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
        pts.add(PerformancePoint(
          runwayType: rt,
          weightKg: double.tryParse(_getCell(r, col, 'weightKg') ?? '') ?? 0.0,
          pressureAltitudeFt: double.tryParse(_getCell(r, col, 'pressureAltitudeFt') ?? '') ?? 0.0,
          deltaIsaC: double.tryParse(_getCell(r, col, 'deltaIsaC') ?? '') ?? 0.0,
          takeoffGroundRollM: double.tryParse(_getCell(r, col, 'takeoffGroundRollM') ?? '') ?? 0.0,
          takeoffOver50M: double.tryParse(_getCell(r, col, 'takeoffOver50M') ?? '') ?? 0.0,
          landingGroundRollM: double.tryParse(_getCell(r, col, 'landingGroundRollM') ?? '') ?? 0.0,
          landingOver50M: double.tryParse(_getCell(r, col, 'landingOver50M') ?? '') ?? 0.0,
        ));
      }

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
}
