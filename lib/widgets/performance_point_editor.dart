import 'package:flutter/material.dart';
import '../models/performance_point.dart';

class PerformancePointEditor extends StatefulWidget {
  final PerformancePoint? existing;
  const PerformancePointEditor({super.key, this.existing});

  @override
  State<PerformancePointEditor> createState() => _PerformancePointEditorState();
}

class _PerformancePointEditorState extends State<PerformancePointEditor> {
  String runwayType = 'concrete';
  final weightCtrl = TextEditingController();
  final altCtrl = TextEditingController();
  final deltaCtrl = TextEditingController();
  final toGrCtrl = TextEditingController();
  final to50Ctrl = TextEditingController();
  final ldGrCtrl = TextEditingController();
  final ld50Ctrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    if (widget.existing != null) {
      final p = widget.existing!;
      runwayType = p.runwayType;
      weightCtrl.text = p.weightKg.toString();
      altCtrl.text = p.pressureAltitudeFt.toString();
      deltaCtrl.text = p.deltaIsaC.toString();
      toGrCtrl.text = p.takeoffGroundRollM.toString();
      to50Ctrl.text = p.takeoffOver50M.toString();
      ldGrCtrl.text = p.landingGroundRollM.toString();
      ld50Ctrl.text = p.landingOver50M.toString();
    }
  }

  @override
  void dispose() {
    weightCtrl.dispose();
    altCtrl.dispose();
    deltaCtrl.dispose();
    toGrCtrl.dispose();
    to50Ctrl.dispose();
    ldGrCtrl.dispose();
    ld50Ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.existing == null ? 'Add Performance Point' : 'Edit Performance Point'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              value: runwayType,
              decoration: const InputDecoration(labelText: 'Runway Type'),
              items: const [
                DropdownMenuItem(value: 'concrete', child: Text('Concrete')),
                DropdownMenuItem(value: 'grass', child: Text('Grass')),
              ],
              onChanged: (v) => setState(() => runwayType = v ?? 'concrete'),
            ),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: altCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Pressure Altitude (ft)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: deltaCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Delta ISA (°C)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Align(alignment: Alignment.centerLeft, child: Text('Distances (meters)')),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: toGrCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'TO Ground Roll'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: to50Ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'TO Over 50 ft / 15 m'),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: ldGrCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'LDG Ground Roll'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: ld50Ctrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'LDG Over 50 ft / 15 m'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final p = PerformancePoint(
              runwayType: runwayType,
              weightKg: double.tryParse(weightCtrl.text.trim()) ?? 0.0,
              pressureAltitudeFt: double.tryParse(altCtrl.text.trim()) ?? 0.0,
              deltaIsaC: double.tryParse(deltaCtrl.text.trim()) ?? 0.0,
              takeoffGroundRollM: double.tryParse(toGrCtrl.text.trim()) ?? 0.0,
              takeoffOver50M: double.tryParse(to50Ctrl.text.trim()) ?? 0.0,
              landingGroundRollM: double.tryParse(ldGrCtrl.text.trim()) ?? 0.0,
              landingOver50M: double.tryParse(ld50Ctrl.text.trim()) ?? 0.0,
            );
            Navigator.pop(context, p);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}