import 'package:flutter/material.dart';

import '../models/airport.dart';
import '../services/hive_service.dart';
import '../services/calculations.dart';
import '../services/interpolation.dart';
import '../services/airport_service.dart' show AirportService, AirportDataStatus;
import '../widgets/stepper_field.dart';
import '../widgets/runway_visualization.dart';
import '../widgets/wind_arrow.dart';
import '../widgets/performance_gauge.dart';

class ComputePage extends StatefulWidget {
  final String aircraftId;
  const ComputePage({super.key, required this.aircraftId});

  @override
  State<ComputePage> createState() => _ComputePageState();
}

class _ComputePageState extends State<ComputePage> {
  final fieldElevCtrl = TextEditingController(text: '0');
  final qnhCtrl = TextEditingController(text: '1013');
  String qnhUnit = 'hPa';
  final tempCtrl = TextEditingController(text: '15');
  bool isExtrapolated = false;
  final weightCtrl = TextEditingController(text: '0');
  final windCtrl = TextEditingController(text: '0');
  final windDirCtrl = TextEditingController();
  final slopeCtrl = TextEditingController(text: '0');
  String runwayType = 'concrete';
  String distType = 'Over 50 ft / 15 m';
  double marginPercent = 20;

  double? outPressureAlt;
  double? outDeltaIsa;
  double? outDensityAlt;
  double? outIsaTemp;
  double? outTO;
  double? outLD;
  double? outTOMargin;
  double? outLDMargin;

  // Airport / runway selection
  final icaoCtrl = TextEditingController();
  List<Airport> _icaoSuggestions = [];
  Airport? _selectedAirport;
  List<Runway> _runways = [];
  Runway? _selectedRunway;
  bool _useLeDirection = true;
  bool _fetchingAirport = false;

  // Editable declared distances
  final toraCtrl = TextEditingController();
  final todaCtrl = TextEditingController();
  final ldaCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final a = HiveService.aircraftBox().get(widget.aircraftId)!;
    weightCtrl.text = a.mtowKg.toStringAsFixed(0);
    _compute();
    AirportService.status.addListener(_onAirportStatusChanged);
  }

  void _onAirportStatusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    AirportService.status.removeListener(_onAirportStatusChanged);
    fieldElevCtrl.dispose();
    qnhCtrl.dispose();
    tempCtrl.dispose();
    weightCtrl.dispose();
    windCtrl.dispose();
    windDirCtrl.dispose();
    slopeCtrl.dispose();
    icaoCtrl.dispose();
    toraCtrl.dispose();
    todaCtrl.dispose();
    ldaCtrl.dispose();
    super.dispose();
  }

  void _stepQnh(int direction) {
    final step = qnhUnit == 'hPa' ? 1.0 : 0.01;
    final precision = qnhUnit == 'hPa' ? 0 : 2;
    final v = (double.tryParse(qnhCtrl.text.trim()) ?? (qnhUnit == 'hPa' ? 1013 : 29.92)) + step * direction;
    qnhCtrl.text = v.toStringAsFixed(precision);
    _compute();
  }

  void _switchQnhUnit(String v) {
    final oldUnit = qnhUnit;
    final oldVal = double.tryParse(qnhCtrl.text.trim());
    setState(() { qnhUnit = v; });
    if (oldVal != null && oldUnit != v) {
      qnhCtrl.text = v == 'inHg'
          ? (oldVal / 33.8639).toStringAsFixed(2)
          : (oldVal * 33.8639).toStringAsFixed(0);
    }
    _compute();
  }

  void _compute() {
    final a = HiveService.aircraftBox().get(widget.aircraftId)!;

    final elevFt = double.tryParse(fieldElevCtrl.text) ?? 0.0;
    final qnh = double.tryParse(qnhCtrl.text) ?? (qnhUnit == 'hPa' ? 1013.0 : 29.92);
    final oat = double.tryParse(tempCtrl.text) ?? 15.0;
    final w = double.tryParse(weightCtrl.text) ?? a.mtowKg;
    final wind = double.tryParse(windCtrl.text) ?? 0.0;
    final slope = double.tryParse(slopeCtrl.text) ?? 0.0;

    final pa = Calc.pressureAltitudeFt(fieldElevationFt: elevFt, qnh: qnh, qnhUnit: qnhUnit);
    final dIsa = Calc.deltaIsaC(pressureAltitudeFt: pa, oatC: oat);

    final hasGrass = a.hasRunwayType('grass');
    final chosenType = runwayType;

    var interp = Interpolator.interpolate(a.points, chosenType, w, pa, dIsa);

    bool appliedGrassPenalty = false;
    if (chosenType == 'grass' && !hasGrass) {
      interp = Interpolator.interpolate(a.points, 'concrete', w, pa, dIsa);
      appliedGrassPenalty = true;
    }

    double toDist = distType == 'Ground roll' ? interp.toGround : interp.toOver50;
    double ldDist = distType == 'Ground roll' ? interp.ldGround : interp.ldOver50;

    toDist = Calc.applyCorrections(
      base: toDist, windKts: wind, slopePercent: slope,
      headwindPercentPerKt: interp.headwindTakeoffPercentPerKt ?? a.correctionFactors.headwindTakeoffPercentPerKt,
      tailwindPercentPerKt: interp.tailwindTakeoffPercentPerKt ?? a.correctionFactors.tailwindTakeoffPercentPerKt,
      slopePercentPerPercent: interp.slopeTakeoffPercentPerPercent ?? a.correctionFactors.slopeTakeoffPercentPerPercent,
      isTakeoff: true,
    );
    ldDist = Calc.applyCorrections(
      base: ldDist, windKts: wind, slopePercent: slope,
      headwindPercentPerKt: interp.headwindLandingPercentPerKt ?? a.correctionFactors.headwindLandingPercentPerKt,
      tailwindPercentPerKt: interp.tailwindLandingPercentPerKt ?? a.correctionFactors.tailwindLandingPercentPerKt,
      slopePercentPerPercent: interp.slopeLandingPercentPerPercent ?? a.correctionFactors.slopeLandingPercentPerPercent,
      isTakeoff: false,
    );

    if (appliedGrassPenalty && a.grassPenaltyPercentIfNoGrassData != null) {
      final factor = 1.0 + (a.grassPenaltyPercentIfNoGrassData! / 100.0);
      toDist *= factor;
      ldDist *= factor;
    }

    final marginFactor = 1.0 + (marginPercent / 100.0);

    setState(() {
      isExtrapolated = interp.isExtrapolated;
      outPressureAlt = pa;
      outDeltaIsa = dIsa;
      outDensityAlt = Calc.densityAltitudeFt(pressureAltitudeFt: pa, oatC: oat);
      outIsaTemp = Calc.isaTempCAt(pa);
      outTO = toDist;
      outLD = ldDist;
      outTOMargin = toDist * marginFactor;
      outLDMargin = ldDist * marginFactor;
    });
  }

  RunwayDirection? get _activeDirection {
    if (_selectedRunway == null) return null;
    return _useLeDirection ? _selectedRunway!.le : _selectedRunway!.he;
  }

  bool get _windComponentsAvailable {
    final windSpeed = (double.tryParse(windCtrl.text.trim()) ?? 0).abs();
    final windDir = double.tryParse(windDirCtrl.text.trim());
    final rwyHdg = _runwayHeading;
    return windDir != null && rwyHdg != null && windSpeed > 0;
  }

  double? get _runwayHeading {
    final dir = _activeDirection;
    if (dir == null || dir.ident.isEmpty) return null;
    final numeric = int.tryParse(dir.ident.replaceAll(RegExp(r'[^0-9]'), ''));
    if (numeric == null) return null;
    return numeric * 10.0;
  }

  double get _headwindComponent {
    final windSpeed = (double.tryParse(windCtrl.text.trim()) ?? 0).abs();
    final windDir = double.tryParse(windDirCtrl.text.trim()) ?? 0;
    final rwyHdg = _runwayHeading ?? 0;
    final comp = Calc.windComponents(windDirDeg: windDir, runwayHdgDeg: rwyHdg, windSpeedKts: windSpeed);
    return comp.headwind;
  }

  String get _headwindLabel {
    final hw = _headwindComponent;
    if (hw >= 0) {
      return 'Headwind: ${hw.toStringAsFixed(0)} kt';
    } else {
      return 'Tailwind: ${(-hw).toStringAsFixed(0)} kt';
    }
  }

  double get _crosswindComponent {
    final windSpeed = (double.tryParse(windCtrl.text.trim()) ?? 0).abs();
    final windDir = double.tryParse(windDirCtrl.text.trim()) ?? 0;
    final rwyHdg = _runwayHeading ?? 0;
    final comp = Calc.windComponents(windDirDeg: windDir, runwayHdgDeg: rwyHdg, windSpeedKts: windSpeed);
    return comp.crosswind;
  }

  String get _crosswindLabel {
    final xw = _crosswindComponent;
    final abs = xw.abs().toStringAsFixed(0);
    if (xw.abs() < 0.5) return 'Crosswind: 0 kt';
    if (xw > 0) return 'Crosswind: $abs kt from right';
    return 'Crosswind: $abs kt from left';
  }

  double get _toAvailable {
    final dir = _activeDirection;
    if (dir == null) return 0;
    // Use editable field value if pilot overrode it, else model value
    if (distType == 'Ground roll') {
      return double.tryParse(toraCtrl.text.trim()) ?? dir.toraM;
    }
    return double.tryParse(todaCtrl.text.trim()) ?? dir.todaM;
  }

  double get _ldAvailable {
    final dir = _activeDirection;
    if (dir == null) return 0;
    return double.tryParse(ldaCtrl.text.trim()) ?? dir.ldaM;
  }

  void _onIcaoChanged(String value) {
    final q = value.trim().toUpperCase();
    if (q.length < 2) {
      setState(() { _icaoSuggestions = []; _selectedAirport = null; _runways = []; _selectedRunway = null; _fetchingAirport = false; });
      return;
    }

    final results = AirportService.search(q, limit: 8);
    setState(() => _icaoSuggestions = results);

    final exact = results.where((a) => a.icao == q).toList();
    if (exact.isNotEmpty) {
      _selectAirport(exact.first);
      return;
    }

    if (q.length == 4) {
      if (!AirportService.hasApiKey) {
        _showNoApiKeyMessage();
        return;
      }
      setState(() { _fetchingAirport = true; _selectedAirport = null; _runways = []; _selectedRunway = null; });
      AirportService.fetchAirport(q).then((ap) {
        if (!mounted || icaoCtrl.text.trim().toUpperCase() != q) return;
        setState(() => _fetchingAirport = false);
        if (ap != null) {
          _selectAirport(ap);
        }
      });
    } else {
      setState(() { _selectedAirport = null; _runways = []; _selectedRunway = null; });
    }
  }

  void _showNoApiKeyMessage() {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('No OpenAIP API key configured. Set one in Settings on the aircraft list page.'),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'Go to Settings',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }

  void _selectAirport(Airport airport) {
    final runways = AirportService.getRunways(airport.icao);
    setState(() {
      _selectedAirport = airport;
      _icaoSuggestions = [];
      _runways = runways;
      _selectedRunway = runways.isNotEmpty ? runways.first : null;
      _useLeDirection = true;
      icaoCtrl.text = airport.icao;
    });
    fieldElevCtrl.text = airport.elevationFt.toStringAsFixed(0);
    _fillDeclaredDistances();
    _compute();
  }

  void _fillDeclaredDistances() {
    final dir = _activeDirection;
    if (dir == null) {
      toraCtrl.clear();
      todaCtrl.clear();
      ldaCtrl.clear();
    } else {
      toraCtrl.text = dir.toraM.toStringAsFixed(0);
      todaCtrl.text = dir.todaM.toStringAsFixed(0);
      ldaCtrl.text = dir.ldaM.toStringAsFixed(0);
    }
  }

  // ── Color-coded input helpers ──

  Color? _weightFieldColor() {
    final a = HiveService.aircraftBox().get(widget.aircraftId)!;
    final w = double.tryParse(weightCtrl.text.trim());
    if (w == null) return null;
    final ratio = w / a.mtowKg;
    if (ratio >= 0.95) return Colors.red.withValues(alpha: 0.08);
    if (ratio >= 0.85) return Colors.orange.withValues(alpha: 0.08);
    return Colors.green.withValues(alpha: 0.06);
  }

  Color? _tempFieldColor() {
    final t = double.tryParse(tempCtrl.text.trim());
    if (t == null) return null;
    if (t > 35) return Colors.red.withValues(alpha: 0.08);
    if (t > 30) return Colors.orange.withValues(alpha: 0.08);
    if (t < 5) return Colors.green.withValues(alpha: 0.06);
    return null;
  }

  Color? _windFieldColor() {
    final w = double.tryParse(windCtrl.text.trim());
    if (w == null) return null;
    if (w < -10) return Colors.red.withValues(alpha: 0.08);
    if (w < 0) return Colors.orange.withValues(alpha: 0.08);
    if (w > 0) return Colors.green.withValues(alpha: 0.06);
    return null;
  }

  double _toPercent() {
    if (outTOMargin == null || _toAvailable <= 0) return 0;
    return (outTOMargin! / _toAvailable) * 100;
  }

  double _ldPercent() {
    if (outLDMargin == null || _ldAvailable <= 0) return 0;
    return (outLDMargin! / _ldAvailable) * 100;
  }

  @override
  Widget build(BuildContext context) {
    final ac = HiveService.aircraftBox().get(widget.aircraftId)!;
    final labelsStyle = Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey[600]);

    return Scaffold(
      appBar: AppBar(title: Text('Compute — ${ac.registration}')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12, runSpacing: 12,
              children: [
                SizedBox(width: 200, child: StepperField(label: 'Weight (kg)', controller: weightCtrl, step: 5, min: 0, precision: 0, onChanged: _compute, fillColor: _weightFieldColor())),
                SizedBox(width: 200, child: StepperField(label: 'Field Elevation (ft)', controller: fieldElevCtrl, step: 50, min: 0, precision: 0, onChanged: _compute)),
                SizedBox(width: 200, child: StepperField(label: 'Temperature (°C)', controller: tempCtrl, step: 1, precision: 0, onChanged: _compute, fillColor: _tempFieldColor())),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: qnhCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'QNH ($qnhUnit)',
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 32, child: IconButton(padding: EdgeInsets.zero, iconSize: 20, tooltip: 'Decrease', icon: const Icon(Icons.remove), onPressed: () => _stepQnh(-1))),
                          SizedBox(width: 32, child: IconButton(padding: EdgeInsets.zero, iconSize: 20, tooltip: 'Increase', icon: const Icon(Icons.add), onPressed: () => _stepQnh(1))),
                          SizedBox(width: 32, child: PopupMenuButton<String>(
                            padding: EdgeInsets.zero,
                            tooltip: 'Change unit',
                            onSelected: _switchQnhUnit,
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'hPa', child: Text('hPa')),
                              PopupMenuItem(value: 'inHg', child: Text('inHg')),
                            ],
                            icon: const Icon(Icons.swap_vert, size: 20),
                          )),
                        ],
                      ),
                    ),
                    onChanged: (_) => _compute(),
                  ),
                ),
                SizedBox(width: 200, child: StepperField(label: 'Wind (kts) +head/-tail', controller: windCtrl, step: 1, precision: 0, onChanged: _compute, fillColor: _windFieldColor())),
                SizedBox(
                  width: 200,
                  child: TextField(
                    controller: windDirCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Wind direction (°)',
                      hintText: 'e.g. 270',
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                SizedBox(width: 200, child: StepperField(label: 'Slope (%) +up/-down', controller: slopeCtrl, step: 1, precision: 0, onChanged: _compute)),
                SizedBox(
                  width: 248,
                  child: DropdownButtonFormField<String>(
                    initialValue: runwayType,
                    items: const [
                      DropdownMenuItem(value: 'concrete', child: Text('Concrete')),
                      DropdownMenuItem(value: 'grass', child: Text('Grass')),
                    ],
                    onChanged: (v) { setState(() => runwayType = v ?? 'concrete'); _compute(); },
                    decoration: const InputDecoration(labelText: 'Runway type'),
                  ),
                ),
                SizedBox(
                  width: 248,
                  child: DropdownButtonFormField<String>(
                    initialValue: distType,
                    items: const [
                      DropdownMenuItem(value: 'Over 50 ft / 15 m', child: Text('Over 50 ft / 15 m obstacle')),
                      DropdownMenuItem(value: 'Ground roll', child: Text('Ground roll')),
                    ],
                    onChanged: (v) { setState(() => distType = v ?? 'Over 50 ft / 15 m'); _compute(); },
                    decoration: const InputDecoration(labelText: 'Distance type'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(children: [
              Text('Margin: ${marginPercent.toStringAsFixed(0)}%'),
              Expanded(child: Slider(min: 0, max: 100, divisions: 20, value: marginPercent, onChanged: (v) { setState(() => marginPercent = v); _compute(); })),
            ]),
            const SizedBox(height: 12),
            if (outPressureAlt != null && outDeltaIsa != null)
              Wrap(
                spacing: 16, runSpacing: 4,
                children: [
                  Text('PA: ${outPressureAlt!.toStringAsFixed(0)} ft'),
                  Text('DA: ${outDensityAlt!.toStringAsFixed(0)} ft'),
                  Text('ISA: ${outIsaTemp!.toStringAsFixed(1)} °C'),
                  Text('ΔISA: ${outDeltaIsa! >= 0 ? '+' : ''}${outDeltaIsa!.toStringAsFixed(1)} °C'),
                  if (_windComponentsAvailable) ...[
                    Text(_headwindLabel),
                    Text(_crosswindLabel),
                  ],
                ],
              ),
            if (isExtrapolated)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(top: 8, bottom: 8),
                decoration: BoxDecoration(color: Colors.orange.shade100, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.orange.shade700)),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('Outside data envelope — results clamped to nearest POH data. Enter more performance points for accuracy.')),
                ]),
              ),
            const SizedBox(height: 8),
            Card(child: Padding(padding: const EdgeInsets.all(16.0), child: _resultTable(labelsStyle))),
            const SizedBox(height: 24),
            // ── Airport & Runway Section ──
            const Divider(),
            const SizedBox(height: 8),
            const Text('Airport & Runway', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            if (!AirportService.isReady)
              _airportStatusBanner()
            else ...[
              // ICAO + Runway + Direction selectors
              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  SizedBox(
                    width: 200,
                    child: TextField(
                      controller: icaoCtrl,
                      textCapitalization: TextCapitalization.characters,
                      decoration: InputDecoration(
                        labelText: 'Airport ICAO',
                        hintText: 'e.g. LFPG',
                        helperText: !AirportService.hasApiKey ? 'API key not set' : null,
                        helperStyle: const TextStyle(color: Colors.orange),
                        prefixIcon: const Icon(Icons.flight_land),
                        suffixIcon: _fetchingAirport
                            ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
                            : null,
                      ),
                      onChanged: _onIcaoChanged,
                    ),
                  ),
                  if (_runways.isNotEmpty)
                    SizedBox(
                      width: 220,
                      child: DropdownButtonFormField<int>(
                        initialValue: _selectedRunway != null ? _runways.indexOf(_selectedRunway!) : null,
                        items: _runways.asMap().entries.map((e) => DropdownMenuItem(
                          value: e.key,
                          child: Text('${e.value.displayName}  (${e.value.lengthM.toStringAsFixed(0)} m)'),
                        )).toList(),
                        onChanged: (idx) {
                          if (idx != null) {
                            setState(() { _selectedRunway = _runways[idx]; _useLeDirection = true; });
                            _fillDeclaredDistances();
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Runway'),
                      ),
                    ),
                  if (_selectedRunway != null)
                    SizedBox(
                      width: 160,
                      child: DropdownButtonFormField<bool>(
                        initialValue: _useLeDirection,
                        items: [
                          DropdownMenuItem(value: true, child: Text('RWY ${_selectedRunway!.leIdent}')),
                          DropdownMenuItem(value: false, child: Text('RWY ${_selectedRunway!.heIdent}')),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _useLeDirection = v);
                            _fillDeclaredDistances();
                          }
                        },
                        decoration: const InputDecoration(labelText: 'Direction'),
                      ),
                    ),
                ],
              ),
              // ICAO autocomplete
              if (_icaoSuggestions.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxHeight: 200),
                  margin: const EdgeInsets.only(top: 4),
                  decoration: BoxDecoration(border: Border.all(color: Colors.grey.shade300), borderRadius: BorderRadius.circular(4)),
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: _icaoSuggestions.length,
                    itemBuilder: (ctx, i) {
                      final ap = _icaoSuggestions[i];
                      return ListTile(
                        dense: true,
                        title: Text('${ap.icao} — ${ap.name}'),
                        subtitle: Text('Elev: ${ap.elevationFt.toStringAsFixed(0)} ft'),
                        onTap: () => _selectAirport(ap),
                      );
                    },
                  ),
                ),
              if (_selectedAirport != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text('${_selectedAirport!.name} — Elev: ${_selectedAirport!.elevationFt.toStringAsFixed(0)} ft', style: labelsStyle),
                ),
              if (_selectedRunway != null && _activeDirection != null) ...[
                const SizedBox(height: 12),
                Text(
                  'Runway ${_selectedRunway!.displayName} • ${_selectedRunway!.lengthM.toStringAsFixed(0)} m × ${_selectedRunway!.widthM.toStringAsFixed(0)} m • ${_selectedRunway!.surface}',
                  style: labelsStyle,
                ),
                const SizedBox(height: 8),
                Text('Declared distances for RWY ${_activeDirection!.ident} (editable — verify against AIP)', style: labelsStyle),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12, runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: toraCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'TORA (m)', helperText: 'Take-Off Run Available'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: todaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'TODA (m)', helperText: 'Take-Off Dist. Available'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                    SizedBox(
                      width: 160,
                      child: TextField(
                        controller: ldaCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'LDA (m)', helperText: 'Landing Dist. Available'),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // ── Performance Gauges + Wind Arrow ──
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    PerformanceGauge(
                      percentage: _toPercent(),
                      label: 'Takeoff',
                      distanceM: outTOMargin,
                      availableM: _toAvailable > 0 ? _toAvailable : null,
                    ),
                    if (_windComponentsAvailable)
                      WindArrow(
                        windDirDeg: double.tryParse(windDirCtrl.text.trim()) ?? 0,
                        runwayHdgDeg: _runwayHeading ?? 0,
                        windSpeedKts: (double.tryParse(windCtrl.text.trim()) ?? 0).abs(),
                        headwindKts: _headwindComponent,
                        crosswindKts: _crosswindComponent,
                      ),
                    PerformanceGauge(
                      percentage: _ldPercent(),
                      label: 'Landing',
                      distanceM: outLDMargin,
                      availableM: _ldAvailable > 0 ? _ldAvailable : null,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Takeoff — RWY ${_activeDirection!.ident}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                RunwayVisualization(
                  leIdent: _selectedRunway!.leIdent,
                  heIdent: _selectedRunway!.heIdent,
                  runwayLengthM: _selectedRunway!.lengthM,
                  availableM: _toAvailable,
                  availableLabel: distType == 'Ground roll' ? 'TORA' : 'TODA',
                  operationLabel: 'Takeoff',
                  distFromLeft: _useLeDirection,
                  distanceM: outTOMargin,
                ),
                const SizedBox(height: 16),
                Text('Landing — RWY ${_activeDirection!.ident}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                RunwayVisualization(
                  leIdent: _selectedRunway!.leIdent,
                  heIdent: _selectedRunway!.heIdent,
                  runwayLengthM: _selectedRunway!.lengthM,
                  availableM: _ldAvailable,
                  availableLabel: 'LDA',
                  operationLabel: 'Landing',
                  distFromLeft: _useLeDirection,
                  distanceM: outLDMargin,
                ),
              ],
              if (AirportService.lastUpdateInfo != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(AirportService.lastUpdateInfo!, style: labelsStyle),
                ),
            ],
            const SizedBox(height: 16),
            Text(
              'Tip: Enter points from POH Section 5 as a grid of Pressure Altitude (ft) vs Delta ISA (°C) at specific weights. '
              'If grass data is not available, set a grass penalty in the Aircraft editor.',
              style: labelsStyle,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _airportStatusBanner() {
    final isError = AirportService.status.value == AirportDataStatus.error;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? Colors.red.shade50 : Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(children: [
        if (isError)
          Icon(Icons.error_outline, size: 20, color: Colors.red.shade700)
        else
          const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
        const SizedBox(width: 12),
        Expanded(child: Text(AirportService.statusMessage)),
        if (isError)
          TextButton(onPressed: () => AirportService.checkAndUpdate(), child: const Text('Retry')),
      ]),
    );
  }

  Widget _resultTable(TextStyle? labelsStyle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Results (meters)'),
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
            TableRow(children: [
              Padding(padding: const EdgeInsets.all(8), child: Text('Takeoff: ${_fmt(outTO)} m')),
              Padding(padding: const EdgeInsets.all(8), child: Text('Takeoff: ${_fmt(outTOMargin)} m')),
            ]),
            TableRow(children: [
              Padding(padding: const EdgeInsets.all(8), child: Text('Landing: ${_fmt(outLD)} m')),
              Padding(padding: const EdgeInsets.all(8), child: Text('Landing: ${_fmt(outLDMargin)} m')),
            ]),
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
