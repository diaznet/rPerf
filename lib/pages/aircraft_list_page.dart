import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/aircraft.dart';
import '../models/correction_factors.dart';
import '../services/hive_service.dart';
import '../services/import_export_service.dart';
import 'aircraft_edit_page.dart';
import 'compute_page.dart';

class AircraftListPage extends StatelessWidget {
  const AircraftListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = HiveService.aircraftBox();

    return Scaffold(
      appBar: AppBar(
        title: const Text('rPerf - Aircrafts'),
        actions: [
          IconButton(
            tooltip: 'Import (JSON/CSV)',
            onPressed: () async {
              await ImportExportService.importFromFilePicker();
            },
            icon: const Icon(Icons.file_open),
          ),
          PopupMenuButton<String>(
            onSelected: (v) async {
              if (v == 'json_share') {
                await ImportExportService.exportAllToJsonShare();
              } else if (v == 'csv_share') {
                await ImportExportService.exportAllToCsvShare();
              } else if (v == 'json_save') {
                final path = await ImportExportService.exportAllToJsonSave();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(path == null ? 'Save canceled' : 'Saved: $path')),
                  );
                }
              } else if (v == 'csv_save') {
                final path = await ImportExportService.exportAllToCsvSave();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(path == null ? 'Save canceled' : 'Saved: $path')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'json_share', child: Text('Export All (JSON) — Share')),
              PopupMenuItem(value: 'csv_share', child: Text('Export All (CSV) — Share')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'json_save', child: Text('Save to Files (JSON)')),
              PopupMenuItem(value: 'csv_save', child: Text('Save to Files (CSV)')),
            ],
            icon: const Icon(Icons.ios_share),
          )
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(),
        builder: (context, Box<Aircraft> b, _) {
          final list = b.values.toList();
          if (list.isEmpty) {
            return const Center(
              child: Text('No aircraft yet. Tap + to add or use Import.'),
            );
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 0),
            itemBuilder: (context, idx) {
              final a = list[idx];
              return Dismissible(
                key: Key(a.id),
                background: Container(color: Colors.redAccent, alignment: Alignment.centerLeft, padding: const EdgeInsets.only(left: 16), child: const Icon(Icons.delete, color: Colors.white)),
                secondaryBackground: Container(color: Colors.redAccent, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 16), child: const Icon(Icons.delete, color: Colors.white)),
                onDismissed: (_) async {
                  await HiveService.deleteAircraft(a.id);
                },
                child: ListTile(
                  title: Text('${a.registration} — ${a.name}'),
                  subtitle: Text('MTOW: ${a.mtowKg.toStringAsFixed(0)} kg • Points: ${a.points.length}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: 'Calculate',
                        icon: const Icon(Icons.calculate),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComputePage(aircraftId: a.id)));
                        },
                      ),
                      IconButton(
                        tooltip: 'Edit',
                        icon: const Icon(Icons.edit),
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AircraftEditPage(aircraftId: a.id)));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final id = const Uuid().v4();
          final ac = Aircraft(
            id: id,
            registration: 'NEW-REG',
            name: 'New Aircraft',
            mtowKg: 1000,
            correctionFactors: CorrectionFactors(),
            grassPenaltyPercentIfNoGrassData: 0,
            points: [],
          );
          await HiveService.addAircraft(ac);
          // Go edit
          // ignore: use_build_context_synchronously
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AircraftEditPage(aircraftId: id)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}