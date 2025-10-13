import 'package:flutter/material.dart';
//import 'package:hive_flutter/hive_flutter.dart';

//import '../models/aircraft.dart';
import '../services/hive_service.dart';
import '../services/calculations.dart';
import '../services/interpolation.dart';
import '../widgets/stepper_field.dart';


class ComputePage extends StatefulWidget {
  final String aircraftId;
  const ComputePage({super.key, required this.aircraftId});

  @override
  State<ComputePage> createState() => _ComputePageState();
}

class _ComputePageState extends State<ComputePage> {
  final fieldElevCtrl = TextEditingController(text: '0'); // ft
  final qnhCtrl = TextEditingController(text: '1013.25'); // hPa default
  String qnhUnit = 'hPa'; // or inHg
  final tempCtrl = TextEditingController(text: '15'); // C
  final weightCtrl = TextEditingController(text: '0'); // kg, default set to MTOW on init
  final windCtrl = TextEditingController(text: '0'); // kts (+ headwind, - tailwind)
  final slopeCtrl = TextEditingController(text: '0'); // %
  String runwayType = 'concrete';
  String distType = 'Over 50 ft / 15 m'; // or 'Ground roll'
  double marginPercent = 20;

  double? outPressureAlt;
  double? outDeltaIsa;
  double? outTO;
  double? outLD;
  double? outTOMargin;
  double? outLDMargin;

  @override
  void initState() {
    super.initState();
    final a = HiveService.aircraftBox().get(widget.aircraftId)!;
    weightCtrl.text = a.mtowKg.toStringAsFixed(0);
    _compute();
  }

  @override
  void dispose() {
    fieldElevCtrl.dispose();
    qnhCtrl.dispose();
    tempCtrl.dispose();
    weightCtrl.dispose();
    windCtrl.dispose();
    slopeCtrl.dispose();
    super.dispose();
  }

  void _compute() {
    final a = HiveService.aircraftBox().get(widget.aircraftId)!;

    final elevFt = double.tryParse(fieldElevCtrl.text) ?? 0.0;
    final qnh = double.tryParse(qnhCtrl.text) ?? (qnhUnit == 'hPa' ? 1013.25 : 29.92);
    final oat = double.tryParse(tempCtrl.text) ?? 15.0;
    final w = double.tryParse(weightCtrl.text) ?? a.mtowKg;
    final wind = double.tryParse(windCtrl.text) ?? 0.0;
    final slope = double.tryParse(slopeCtrl.text) ?? 0.0;

    final pa = Calc.pressureAltitudeFt(fieldElevationFt: elevFt, qnh: qnh, qnhUnit: qnhUnit);
    final dIsa = Calc.deltaIsaC(pressureAltitudeFt: pa, oatC: oat);

    final hasGrass = a.hasRunwayType('grass');
    final chosenType = runwayType;

    var interp = Interpolator.interpolate(a.points, chosenType, w, pa, dIsa);

    // If user chose grass but no grass data, fallback to concrete and apply penalty if any
    bool appliedGrassPenalty = false;
    if (chosenType == 'grass' && !hasGrass) {
      final concreteInterp = Interpolator.interpolate(a.points, 'concrete', w, pa, dIsa);
      interp = concreteInterp;
      appliedGrassPenalty = true;
    }

    // Choose distance type
    double toDist = distType == 'Ground roll' ? interp.toGround : interp.toOver50;
    double ldDist = distType == 'Ground roll' ? interp.ldGround : interp.ldOver50;

    // Apply wind and slope corrections
    toDist = Calc.applyCorrections(
      base: toDist,
      windKts: wind,
      slopePercent: slope,
      headwindPercentPerKt: a.correctionFactors.headwindTakeoffPercentPerKt,
      tailwindPercentPerKt: a.correctionFactors.tailwindTakeoffPercentPerKt,
      slopePercentPerPercent: a.correctionFactors.slopeTakeoffPercentPerPercent,
    );
    ldDist = Calc.applyCorrections(
      base: ldDist,
      windKts: wind,
      slopePercent: slope,
      headwindPercentPerKt: a.correctionFactors.headwindLandingPercentPerKt,
      tailwindPercentPerKt: a.correctionFactors.tailwindLandingPercentPerKt,
      slopePercentPerPercent: a.correctionFactors.slopeLandingPercentPerPercent,
    );

    // Apply grass penalty if needed
    if (appliedGrassPenalty && a.grassPenaltyPercentIfNoGrassData != null) {
      final factor = 1.0 + (a.grassPenaltyPercentIfNoGrassData! / 100.0);
      toDist *= factor;
      ldDist *= factor;
    }

    final marginFactor = 1.0 + (marginPercent / 100.0);

    setState(() {
      outPressureAlt = pa;
      outDeltaIsa = dIsa;
      outTO = toDist;
      outLD = ldDist;
      outTOMargin = toDist * marginFactor;
      outLDMargin = ldDist * marginFactor;
    });
  }

  @override
  Widget build(BuildContext context) {
    final ac = HiveService.aircraftBox().get(widget.aircraftId)!;

    final labelsStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]);

    return Scaffold(
      appBar: AppBar(
        title: Text('Compute distances for: ${ac.registration}'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                SizedBox(
                  width: 248,
                  child: StepperField(
                    label: 'Weight (kg)',
                    controller: weightCtrl,
                    step: 5, // adjust if you prefer 1 or 10
                    min: 0,
                    precision: 0,
                    onChanged: _compute,
                  ),
                ),
                SizedBox(
                  width: 248,
                  child: StepperField(
                    label: 'Field Elevation (ft)',
                    controller: fieldElevCtrl,
                    step: 50, // ft increments
                    min: 0,
                    precision: 0,
                    onChanged: _compute,
                  ),                ),
                SizedBox(
                  width: 248,
                  child: StepperField(
                    label: 'Temperature (°C)',
                    controller: tempCtrl,
                    step: 1,
                    precision: 0,
                    onChanged: _compute,
                  ),
                ),
                SizedBox(
                  width: 248,
                  child: TextField(
                    controller: qnhCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'QNH (${qnhUnit})',
                      suffixIcon: PopupMenuButton<String>(
                        onSelected: (v) {
                          setState(() {
                            qnhUnit = v;
                          });
                          _compute();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'hPa', child: Text('hPa')),
                          PopupMenuItem(value: 'inHg', child: Text('inHg')),
                        ],
                        icon: const Icon(Icons.swap_vert),
                      ),
                    ),
                    onChanged: (_) => _compute(),
                  ),
                ),
                SizedBox(
                  width: 248,
                  child: StepperField(
                    label: 'Wind (kts) +head/-tail',
                    controller: windCtrl,
                    step: 1,
                    precision: 0,
                    onChanged: _compute,
                  ),
                ),
                SizedBox(
                  width: 248,
                  child: StepperField(
                    label: 'Runway slope (%) +up/-down',
                    controller: slopeCtrl,
                    step: 1,
                    precision: 0,
                    onChanged: _compute,
                  ),
                ),
                SizedBox(
                  width: 248,
                  child: DropdownButtonFormField<String>(
                    value: runwayType,
                    items: const [
                      DropdownMenuItem(value: 'concrete', child: Text('Concrete')),
                      DropdownMenuItem(value: 'grass', child: Text('Grass')),
                    ],
                    onChanged: (v) {
                      setState(() => runwayType = v ?? 'concrete');
                      _compute();
                    },
                    decoration: const InputDecoration(labelText: 'Runway type'),
                  ),
                ),
                SizedBox(
                  width: 248,
                  child: DropdownButtonFormField<String>(
                    value: distType,
                    items: const [
                      DropdownMenuItem(value: 'Over 50 ft / 15 m', child: Text('Over 50 ft / 15 m obstacle')),
                      DropdownMenuItem(value: 'Ground roll', child: Text('Ground roll')),
                    ],
                    onChanged: (v) {
                      setState(() => distType = v ?? 'Over 50 ft / 15 m');
                      _compute();
                    },
                    decoration: const InputDecoration(labelText: 'Distance type'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Text('Margin: ${marginPercent.toStringAsFixed(0)}%'),
                Expanded(
                  child: Slider(
                    min: 0,
                    max: 100,
                    divisions: 20,
                    value: marginPercent,
                    onChanged: (v) {
                      setState(() => marginPercent = v);
                      _compute();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (outPressureAlt != null && outDeltaIsa != null)
              Row(
                children: [
                  Text('Pressure Altitude: ${outPressureAlt!.toStringAsFixed(0)} ft'),
                  const SizedBox(width: 16),
                  Text('ΔISA: ${outDeltaIsa!.toStringAsFixed(1)} °C'),
                ],
              ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: _resultTable(labelsStyle),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Tip: Enter points from POH Section 5 as a grid of Pressure Altitude (ft) vs Delta ISA (°C) at specific weights. '
              'If grass data is not available, set a grass penalty in the Aircraft editor.',
              style: labelsStyle,
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultTable(TextStyle? labelsStyle) {
    final to = outTO;
    final ld = outLD;
    final tom = outTOMargin;
    final ldm = outLDMargin;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Results (meters)'),
        const SizedBox(height: 8),
        Table(
          border: TableBorder.all(color: Colors.grey.shade300),
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          columnWidths: const {0: FlexColumnWidth(1), 1: FlexColumnWidth(1)},
          children: [
            TableRow(
              decoration: BoxDecoration(color: Colors.grey.shade100),
              children: const [
                Padding(padding: EdgeInsets.all(8), child: Text('Base')),
                Padding(padding: EdgeInsets.all(8), child: Text('With Margin')),
              ],
            ),
            TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('Takeoff: ${_fmt(to)} m')),
                Padding(padding: const EdgeInsets.all(8), child: Text('Takeoff: ${_fmt(tom)} m')),
              ],
            ),
            TableRow(
              children: [
                Padding(padding: const EdgeInsets.all(8), child: Text('Landing: ${_fmt(ld)} m')),
                Padding(padding: const EdgeInsets.all(8), child: Text('Landing: ${_fmt(ldm)} m')),
              ],
            ),
          ],
        ),
      ],
    );
  }

  static String _fmt(double? v) {
    if (v == null || v.isNaN) return '—';
    return v.toStringAsFixed(0);
  }
}