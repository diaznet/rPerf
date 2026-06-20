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

  // Per-point correction factors
  final hwToCtrl = TextEditingController();
  final twToCtrl = TextEditingController();
  final hwLdCtrl = TextEditingController();
  final twLdCtrl = TextEditingController();
  final slToCtrl = TextEditingController();
  final slLdCtrl = TextEditingController();
  bool _showCorrections = false;

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
      if (p.headwindTakeoffPercentPerKt != null) hwToCtrl.text = p.headwindTakeoffPercentPerKt.toString();
      if (p.tailwindTakeoffPercentPerKt != null) twToCtrl.text = p.tailwindTakeoffPercentPerKt.toString();
      if (p.headwindLandingPercentPerKt != null) hwLdCtrl.text = p.headwindLandingPercentPerKt.toString();
      if (p.tailwindLandingPercentPerKt != null) twLdCtrl.text = p.tailwindLandingPercentPerKt.toString();
      if (p.slopeTakeoffPercentPerPercent != null) slToCtrl.text = p.slopeTakeoffPercentPerPercent.toString();
      if (p.slopeLandingPercentPerPercent != null) slLdCtrl.text = p.slopeLandingPercentPerPercent.toString();
      _showCorrections = p.headwindTakeoffPercentPerKt != null ||
          p.tailwindTakeoffPercentPerKt != null ||
          p.headwindLandingPercentPerKt != null ||
          p.tailwindLandingPercentPerKt != null ||
          p.slopeTakeoffPercentPerPercent != null ||
          p.slopeLandingPercentPerPercent != null;
    }
  }

  @override
  void dispose() {
    weightCtrl.dispose(); altCtrl.dispose(); deltaCtrl.dispose();
    toGrCtrl.dispose(); to50Ctrl.dispose(); ldGrCtrl.dispose(); ld50Ctrl.dispose();
    hwToCtrl.dispose(); twToCtrl.dispose(); hwLdCtrl.dispose();
    twLdCtrl.dispose(); slToCtrl.dispose(); slLdCtrl.dispose();
    super.dispose();
  }

  double? _opt(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : double.tryParse(t);
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
              initialValue: runwayType,
              decoration: const InputDecoration(labelText: 'Runway Type'),
              items: const [
                DropdownMenuItem(value: 'concrete', child: Text('Concrete')),
                DropdownMenuItem(value: 'grass', child: Text('Grass')),
              ],
              onChanged: (v) => setState(() => runwayType = v ?? 'concrete'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: weightCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Weight (kg)'),
            ),
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            const Align(alignment: Alignment.centerLeft, child: Text('Distances (meters)')),
            const SizedBox(height: 8),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 16),
            // Collapsible correction factors section
            InkWell(
              onTap: () => setState(() => _showCorrections = !_showCorrections),
              child: Row(
                children: [
                  Icon(_showCorrections ? Icons.expand_less : Icons.expand_more, size: 20),
                  const SizedBox(width: 4),
                  const Text('Point-specific corrections', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                  const SizedBox(width: 8),
                  Flexible(child: Text('(optional)', style: TextStyle(fontSize: 11, color: Colors.grey.shade600))),
                ],
              ),
            ),
            if (_showCorrections) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: hwToCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Headwind TO %/kt'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: twToCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tailwind TO %/kt'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: hwLdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Headwind LDG %/kt'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: twLdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Tailwind LDG %/kt'))),
              ]),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(child: TextField(controller: slToCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Slope TO %/%'))),
                const SizedBox(width: 8),
                Expanded(child: TextField(controller: slLdCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Slope LDG %/%'))),
              ]),
            ],
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
              headwindTakeoffPercentPerKt: _opt(hwToCtrl),
              tailwindTakeoffPercentPerKt: _opt(twToCtrl),
              headwindLandingPercentPerKt: _opt(hwLdCtrl),
              tailwindLandingPercentPerKt: _opt(twLdCtrl),
              slopeTakeoffPercentPerPercent: _opt(slToCtrl),
              slopeLandingPercentPerPercent: _opt(slLdCtrl),
            );
            Navigator.pop(context, p);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
