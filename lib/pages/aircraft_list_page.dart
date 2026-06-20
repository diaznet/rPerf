import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/aircraft.dart';
import '../models/correction_factors.dart';
import '../services/hive_service.dart';
import '../services/import_export_service.dart';
import '../services/airport_service.dart';
import 'aircraft_edit_page.dart';
import 'compute_page.dart';

class AircraftListPage extends StatelessWidget {
  const AircraftListPage({super.key});

  @override
  Widget build(BuildContext context) {
    final box = HiveService.aircraftBox();

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/images/rperf_logo.png', width: 32, height: 32),
            const SizedBox(width: 10),
            const Text('rPerf', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Import',
            onPressed: () => _showImportDialog(context),
            icon: const Icon(Icons.file_open),
          ),
          PopupMenuButton<String>(
            tooltip: 'Settings',
            onSelected: (v) async {
              if (v == 'openaip_key') {
                final ctrl = TextEditingController(text: AirportService.apiKey);
                final saved = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('OpenAIP API Key'),
                    content: TextField(
                      controller: ctrl,
                      decoration: const InputDecoration(
                        hintText: 'Paste your API key',
                        helperText: 'Get a free key at openaip.net',
                      ),
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
                    ],
                  ),
                );
                if (saved == true) {
                  await AirportService.setApiKey(ctrl.text);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('API key saved')),
                    );
                  }
                }
              } else if (v == 'flush_airports') {
                await AirportService.clearCache();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Airport cache cleared')),
                  );
                }
              } else if (v == 'about') {
                showAboutDialog(
                  context: context,
                  applicationName: 'rPerf',
                  applicationVersion: '1.0.0',
                  applicationIcon: Image.asset('assets/images/rperf_logo.png', width: 48, height: 48),
                  children: [
                    const Text('Takeoff & Landing Performance Calculator'),
                    const SizedBox(height: 12),
                    const Text('Photo Credits', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    const Text(
                      'Splash screen: "Cockpit of a Robin DR400 aircraft in flight" by Giles Laurent, '
                      'Wikimedia Commons, licensed under CC BY-SA 4.0.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                );
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'openaip_key', child: Text('OpenAIP API key…')),
              PopupMenuItem(value: 'flush_airports', child: Text('Flush airport cache')),
              PopupMenuDivider(),
              PopupMenuItem(value: 'about', child: Text('About')),
            ],
            icon: const Icon(Icons.settings),
          ),
          PopupMenuButton<String>(
            tooltip: 'Export all aircraft',
            onSelected: (v) async {
              if (v == 'share') {
                await ImportExportService.exportAllShare();
              } else if (v == 'save') {
                final path = await ImportExportService.exportAllSave();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(path == null ? 'Save canceled' : 'Saved: $path')),
                  );
                }
              }
            },
            itemBuilder: (ctx) => const [
              PopupMenuItem(value: 'share', child: Text('Share all aircraft (CSV)')),
              PopupMenuItem(value: 'save', child: Text('Save to file (CSV)')),
            ],
            icon: const Icon(Icons.ios_share),
          )
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFE8F0FE),
                    Color(0xFFF5F8FF),
                    Color(0xFFFFFFFF),
                  ],
                  stops: [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          ValueListenableBuilder(
            valueListenable: box.listenable(),
            builder: (context, Box<Aircraft> b, _) {
              final list = b.values.toList();
              if (list.isEmpty) {
                return const Center(
                  child: Text('No aircraft yet. Tap + to add or use Import.'),
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Text(
                      'Tap to calculate performance · Long-press for more',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: list.length,
                      separatorBuilder: (_, __) => const Divider(height: 0),
                      itemBuilder: (context, idx) {
                        final a = list[idx];
                        return ListTile(
                          leading: Icon(Icons.airplanemode_active, color: Colors.blue.shade700, size: 28),
                          title: Text('${a.registration} — ${a.name}'),
                          subtitle: Text('MTOW: ${a.mtowKg.toStringAsFixed(0)} kg • Points: ${a.points.length}'),
                          onTap: () {
                            Navigator.of(context).push(MaterialPageRoute(builder: (_) => ComputePage(aircraftId: a.id)));
                          },
                          onLongPress: () => _showAircraftMenu(context, a),
                        );
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ],
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
          // ignore: use_build_context_synchronously
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => AircraftEditPage(aircraftId: id)));
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showImportDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(12),
              child: Text('Import Aircraft', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('Import from file (CSV)'),
              onTap: () async {
                Navigator.pop(ctx);
                await ImportExportService.importFromFilePicker();
              },
            ),
            const Divider(height: 0),
            const Padding(
              padding: EdgeInsets.only(left: 16, top: 12, bottom: 4),
              child: Align(alignment: Alignment.centerLeft, child: Text('Sample aircraft', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: Colors.grey))),
            ),
            ...ImportExportService.sampleAircraft.map((s) => ListTile(
              leading: const Icon(Icons.airplanemode_active),
              title: Text(s['name']!),
              onTap: () async {
                Navigator.pop(ctx);
                await ImportExportService.importSample(s['file']!);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('${s['name']} imported')),
                  );
                }
              },
            )),
          ],
        ),
      ),
    );
  }

  void _showAircraftMenu(BuildContext context, Aircraft a) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text('${a.registration} — ${a.name}', style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
            const Divider(height: 0),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Edit'),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => AircraftEditPage(aircraftId: a.id)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('Duplicate'),
              onTap: () async {
                Navigator.pop(ctx);
                final newId = const Uuid().v4();
                final dup = Aircraft(
                  id: newId,
                  registration: '${a.registration}-COPY',
                  name: a.name,
                  mtowKg: a.mtowKg,
                  correctionFactors: a.correctionFactors,
                  grassPenaltyPercentIfNoGrassData: a.grassPenaltyPercentIfNoGrassData,
                  points: a.points,
                );
                await HiveService.addAircraft(dup);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: const Text('Export (share)'),
              onTap: () async {
                Navigator.pop(ctx);
                await ImportExportService.exportSingleShare(a);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete, color: Colors.red),
              title: const Text('Delete', style: TextStyle(color: Colors.red)),
              onTap: () async {
                Navigator.pop(ctx);
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (dCtx) => AlertDialog(
                    title: const Text('Delete Aircraft'),
                    content: Text('Delete ${a.registration} — ${a.name} and all its performance data?'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(dCtx, false), child: const Text('Cancel')),
                      TextButton(onPressed: () => Navigator.pop(dCtx, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
                    ],
                  ),
                ) ?? false;
                if (confirm) await HiveService.deleteAircraft(a.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
