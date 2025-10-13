import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/aircraft.dart';
import '../models/performance_point.dart';
import '../services/hive_service.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/performance_point_editor.dart';

class AircraftEditPage extends StatefulWidget {
  final String aircraftId;
  const AircraftEditPage({super.key, required this.aircraftId});

  @override
  State<AircraftEditPage> createState() => _AircraftEditPageState();
}

class _AircraftEditPageState extends State<AircraftEditPage> {
  late TextEditingController regCtrl;
  late TextEditingController nameCtrl;
  late TextEditingController mtowCtrl;
  late TextEditingController grassPenaltyCtrl;

  // Correction factors
  late TextEditingController hwToCtrl;
  late TextEditingController twToCtrl;
  late TextEditingController hwLdCtrl;
  late TextEditingController twLdCtrl;
  late TextEditingController slopeToCtrl;
  late TextEditingController slopeLdCtrl;

  @override
  void initState() {
    super.initState();
    final a = HiveService.aircraftBox().get(widget.aircraftId)!;
    regCtrl = TextEditingController(text: a.registration);
    nameCtrl = TextEditingController(text: a.name);
    mtowCtrl = TextEditingController(text: a.mtowKg.toString());
    grassPenaltyCtrl = TextEditingController(text: (a.grassPenaltyPercentIfNoGrassData ?? 0).toString());

    hwToCtrl = TextEditingController(text: a.correctionFactors.headwindTakeoffPercentPerKt.toString());
    twToCtrl = TextEditingController(text: a.correctionFactors.tailwindTakeoffPercentPerKt.toString());
    hwLdCtrl = TextEditingController(text: a.correctionFactors.headwindLandingPercentPerKt.toString());
    twLdCtrl = TextEditingController(text: a.correctionFactors.tailwindLandingPercentPerKt.toString());
    slopeToCtrl = TextEditingController(text: a.correctionFactors.slopeTakeoffPercentPerPercent.toString());
    slopeLdCtrl = TextEditingController(text: a.correctionFactors.slopeLandingPercentPerPercent.toString());
  }

  @override
  void dispose() {
    regCtrl.dispose();
    nameCtrl.dispose();
    mtowCtrl.dispose();
    grassPenaltyCtrl.dispose();
    hwToCtrl.dispose(); twToCtrl.dispose(); hwLdCtrl.dispose(); twLdCtrl.dispose(); slopeToCtrl.dispose(); slopeLdCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final box = HiveService.aircraftBox();
    final a = box.get(widget.aircraftId)!;
    a.registration = regCtrl.text.trim();
    a.name = nameCtrl.text.trim();
    a.mtowKg = double.tryParse(mtowCtrl.text.trim()) ?? a.mtowKg;
    a.grassPenaltyPercentIfNoGrassData = double.tryParse(grassPenaltyCtrl.text.trim());

    a.correctionFactors.headwindTakeoffPercentPerKt = double.tryParse(hwToCtrl.text.trim()) ?? 0.0;
    a.correctionFactors.tailwindTakeoffPercentPerKt = double.tryParse(twToCtrl.text.trim()) ?? 0.0;
    a.correctionFactors.headwindLandingPercentPerKt = double.tryParse(hwLdCtrl.text.trim()) ?? 0.0;
    a.correctionFactors.tailwindLandingPercentPerKt = double.tryParse(twLdCtrl.text.trim()) ?? 0.0;
    a.correctionFactors.slopeTakeoffPercentPerPercent = double.tryParse(slopeToCtrl.text.trim()) ?? 0.0;
    a.correctionFactors.slopeLandingPercentPerPercent = double.tryParse(slopeLdCtrl.text.trim()) ?? 0.0;

    await a.save();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final box = HiveService.aircraftBox();
    final a = box.get(widget.aircraftId)!;
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit ${a.registration}'),
        actions: [
          IconButton(onPressed: _save, icon: const Icon(Icons.save)),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: box.listenable(keys: [widget.aircraftId]),
        builder: (context, Box<Aircraft> b, _) {
          final ac = b.get(widget.aircraftId)!;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                LabeledTextField(label: 'Registration', controller: regCtrl),
                LabeledTextField(label: 'Name', controller: nameCtrl),
                LabeledTextField(label: 'MTOW (kg)', controller: mtowCtrl, keyboardType: TextInputType.number),
                LabeledTextField(label: 'Grass Penalty % (if no grass data)', controller: grassPenaltyCtrl, keyboardType: TextInputType.number),
                const SizedBox(height: 12),
                const Text('Correction Factors (percent per unit)', style: TextStyle(fontWeight: FontWeight.bold)),
                Row(children: [
                  Expanded(child: LabeledTextField(label: 'Headwind TO %/kt', controller: hwToCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: LabeledTextField(label: 'Tailwind TO %/kt', controller: twToCtrl, keyboardType: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(child: LabeledTextField(label: 'Headwind LDG %/kt', controller: hwLdCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: LabeledTextField(label: 'Tailwind LDG %/kt', controller: twLdCtrl, keyboardType: TextInputType.number)),
                ]),
                Row(children: [
                  Expanded(child: LabeledTextField(label: 'Slope TO %/%', controller: slopeToCtrl, keyboardType: TextInputType.number)),
                  const SizedBox(width: 8),
                  Expanded(child: LabeledTextField(label: 'Slope LDG %/%', controller: slopeLdCtrl, keyboardType: TextInputType.number)),
                ]),
                const SizedBox(height: 16),
                Row(
                  children: [
                    const Text('Performance Points', style: TextStyle(fontWeight: FontWeight.bold)),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () async {
                        final p = await showDialog<PerformancePoint>(
                          context: context,
                          builder: (ctx) => PerformancePointEditor(),
                        );
                        if (p != null) {
                          ac.points.add(p);
                          await ac.save();
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: const Text('Add Point'),
                    ),
                  ],
                ),
                if (ac.points.isEmpty)
                  const Text('No performance points yet. Add points from POH (pressure altitude & Delta ISA grid).')
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ac.points.length,
                    itemBuilder: (ctx, i) {
                      final p = ac.points[i];
                      return Card(
                        child: ListTile(
                          title: Text('${p.runwayType} • W ${p.weightKg.toStringAsFixed(0)} kg • PA ${p.pressureAltitudeFt.toStringAsFixed(0)} ft • ΔISA ${p.deltaIsaC.toStringAsFixed(0)} °C'),
                          subtitle: Text('TO: GR ${p.takeoffGroundRollM} m / O50 ${p.takeoffOver50M} m • LDG: GR ${p.landingGroundRollM} m / O50 ${p.landingOver50M} m'),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: () async {
                              ac.points.removeAt(i);
                              await ac.save();
                            },
                          ),
                          onTap: () async {
                            final edited = await showDialog<PerformancePoint>(
                              context: context,
                              builder: (ctx) => PerformancePointEditor(existing: p),
                            );
                            if (edited != null) {
                              ac.points[i] = edited;
                              await ac.save();
                            }
                          },
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 24),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text('Save Changes'),
                ),
                const SizedBox(height: 40),
              ],
            ),
          );
        },
      ),
    );
  }
}