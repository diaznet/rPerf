import '../models/performance_point.dart';

class InterpolatedResult {
  final double toGround;
  final double toOver50;
  final double ldGround;
  final double ldOver50;
  final bool isExtrapolated;

  // Interpolated per-point correction factors (null = use aircraft defaults)
  final double? headwindTakeoffPercentPerKt;
  final double? tailwindTakeoffPercentPerKt;
  final double? headwindLandingPercentPerKt;
  final double? tailwindLandingPercentPerKt;
  final double? slopeTakeoffPercentPerPercent;
  final double? slopeLandingPercentPerPercent;

  InterpolatedResult({
    required this.toGround,
    required this.toOver50,
    required this.ldGround,
    required this.ldOver50,
    this.isExtrapolated = false,
    this.headwindTakeoffPercentPerKt,
    this.tailwindTakeoffPercentPerKt,
    this.headwindLandingPercentPerKt,
    this.tailwindLandingPercentPerKt,
    this.slopeTakeoffPercentPerPercent,
    this.slopeLandingPercentPerPercent,
  });

  static InterpolatedResult nan({bool isExtrapolated = false}) => InterpolatedResult(
    toGround: double.nan, toOver50: double.nan,
    ldGround: double.nan, ldOver50: double.nan,
    isExtrapolated: isExtrapolated,
  );
}

class Interpolator {
  static InterpolatedResult interpolate(
    List<PerformancePoint> points,
    String runwayType,
    double weightKg,
    double paFt,
    double deltaIsaC,
  ) {
    final pts = points.where((p) => p.runwayType == runwayType).toList();
    if (pts.isEmpty) return InterpolatedResult.nan();

    final weights = pts.map((e) => e.weightKg).toSet().toList()..sort();

    // Check if outside data envelope
    final allAlts = pts.map((e) => e.pressureAltitudeFt).toSet().toList()..sort();
    final allDeltas = pts.map((e) => e.deltaIsaC).toSet().toList()..sort();
    final extrapolated = weightKg < weights.first || weightKg > weights.last ||
        paFt < allAlts.first || paFt > allAlts.last ||
        deltaIsaC < allDeltas.first || deltaIsaC > allDeltas.last;

    // Separate weight grids for takeoff and landing (they may differ)
    final toWeights = pts.where((p) => p.takeoffGroundRollM != 0 || p.takeoffOver50M != 0)
        .map((e) => e.weightKg).toSet().toList()..sort();
    final ldWeights = pts.where((p) => p.landingGroundRollM != 0 || p.landingOver50M != 0)
        .map((e) => e.weightKg).toSet().toList()..sort();

    // Interpolate takeoff on its weight grid
    InterpolatedResult? toResult;
    if (toWeights.isNotEmpty) {
      final twb = _bracket(toWeights, weightKg);
      final r0 = _bilinearAtWeight(pts, twb.lo, paFt, deltaIsaC);
      final r1 = twb.lo == twb.hi ? r0 : _bilinearAtWeight(pts, twb.hi, paFt, deltaIsaC);
      if (r0 != null || r1 != null) {
        if (r0 == null) { toResult = r1; }
        else if (r1 == null || twb.lo == twb.hi) { toResult = r0; }
        else {
          final t = (weightKg - twb.lo) / (twb.hi - twb.lo);
          toResult = _lerpResults(r0, r1, t);
        }
      }
    }

    // Interpolate landing on its weight grid
    InterpolatedResult? ldResult;
    if (ldWeights.isNotEmpty) {
      final lwb = _bracket(ldWeights, weightKg);
      final r0 = _bilinearAtWeight(pts, lwb.lo, paFt, deltaIsaC);
      final r1 = lwb.lo == lwb.hi ? r0 : _bilinearAtWeight(pts, lwb.hi, paFt, deltaIsaC);
      if (r0 != null || r1 != null) {
        if (r0 == null) { ldResult = r1; }
        else if (r1 == null || lwb.lo == lwb.hi) { ldResult = r0; }
        else {
          final t = (weightKg - lwb.lo) / (lwb.hi - lwb.lo);
          ldResult = _lerpResults(r0, r1, t);
        }
      }
    }

    if (toResult == null && ldResult == null) return InterpolatedResult.nan(isExtrapolated: extrapolated);

    return InterpolatedResult(
      toGround: toResult?.toGround ?? 0,
      toOver50: toResult?.toOver50 ?? 0,
      ldGround: ldResult?.ldGround ?? toResult?.ldGround ?? 0,
      ldOver50: ldResult?.ldOver50 ?? toResult?.ldOver50 ?? 0,
      isExtrapolated: extrapolated,
      headwindTakeoffPercentPerKt: toResult?.headwindTakeoffPercentPerKt,
      tailwindTakeoffPercentPerKt: toResult?.tailwindTakeoffPercentPerKt,
      headwindLandingPercentPerKt: ldResult?.headwindLandingPercentPerKt,
      tailwindLandingPercentPerKt: ldResult?.tailwindLandingPercentPerKt,
      slopeTakeoffPercentPerPercent: toResult?.slopeTakeoffPercentPerPercent,
      slopeLandingPercentPerPercent: ldResult?.slopeLandingPercentPerPercent,
    );
  }

  static InterpolatedResult? _bilinearAtWeight(
      List<PerformancePoint> pts, double weightKg, double paFt, double dIsa) {
    final pool = pts.where((p) => (p.weightKg - weightKg).abs() < 1e-6).toList();
    if (pool.isEmpty) return null;

    // Separate pools: takeoff data vs landing data
    final toPool = pool.where((p) => p.takeoffGroundRollM != 0 || p.takeoffOver50M != 0).toList();
    final ldPool = pool.where((p) => p.landingGroundRollM != 0 || p.landingOver50M != 0).toList();

    // Interpolate takeoff using only points that have takeoff data
    InterpolatedResult? toResult;
    if (toPool.isNotEmpty) {
      final toAlts = toPool.map((e) => e.pressureAltitudeFt).toSet().toList()..sort();
      final toAb = _bracket(toAlts, paFt);
      final toRLo = _interpDeltaAtAlt(toPool, weightKg, toAb.lo, dIsa);
      final toRHi = toAb.lo == toAb.hi ? toRLo : _interpDeltaAtAlt(toPool, weightKg, toAb.hi, dIsa);
      if (toRLo != null || toRHi != null) {
        if (toRLo == null) { toResult = toRHi; }
        else if (toRHi == null || toAb.lo == toAb.hi) { toResult = toRLo; }
        else {
          final t = (paFt - toAb.lo) / (toAb.hi - toAb.lo);
          toResult = _lerpResults(toRLo, toRHi, t);
        }
      }
    }

    // Interpolate landing using only points that have landing data
    InterpolatedResult? ldResult;
    if (ldPool.isNotEmpty) {
      final ldAlts = ldPool.map((e) => e.pressureAltitudeFt).toSet().toList()..sort();
      final ldAb = _bracket(ldAlts, paFt);
      final ldRLo = _interpDeltaAtAlt(ldPool, weightKg, ldAb.lo, dIsa);
      final ldRHi = ldAb.lo == ldAb.hi ? ldRLo : _interpDeltaAtAlt(ldPool, weightKg, ldAb.hi, dIsa);
      if (ldRLo != null || ldRHi != null) {
        if (ldRLo == null) { ldResult = ldRHi; }
        else if (ldRHi == null || ldAb.lo == ldAb.hi) { ldResult = ldRLo; }
        else {
          final t = (paFt - ldAb.lo) / (ldAb.hi - ldAb.lo);
          ldResult = _lerpResults(ldRLo, ldRHi, t);
        }
      }
    }

    if (toResult == null && ldResult == null) return null;

    // Merge: use takeoff from toResult and landing from ldResult
    return InterpolatedResult(
      toGround: toResult?.toGround ?? 0,
      toOver50: toResult?.toOver50 ?? 0,
      ldGround: ldResult?.ldGround ?? 0,
      ldOver50: ldResult?.ldOver50 ?? 0,
      headwindTakeoffPercentPerKt: toResult?.headwindTakeoffPercentPerKt ?? ldResult?.headwindTakeoffPercentPerKt,
      tailwindTakeoffPercentPerKt: toResult?.tailwindTakeoffPercentPerKt ?? ldResult?.tailwindTakeoffPercentPerKt,
      headwindLandingPercentPerKt: ldResult?.headwindLandingPercentPerKt ?? toResult?.headwindLandingPercentPerKt,
      tailwindLandingPercentPerKt: ldResult?.tailwindLandingPercentPerKt ?? toResult?.tailwindLandingPercentPerKt,
      slopeTakeoffPercentPerPercent: toResult?.slopeTakeoffPercentPerPercent ?? ldResult?.slopeTakeoffPercentPerPercent,
      slopeLandingPercentPerPercent: ldResult?.slopeLandingPercentPerPercent ?? toResult?.slopeLandingPercentPerPercent,
    );
  }

  static InterpolatedResult? _interpDeltaAtAlt(
      List<PerformancePoint> pool, double w, double alt, double dIsa) {
    final atAlt = pool.where((p) => (p.pressureAltitudeFt - alt).abs() < 1e-6).toList();
    if (atAlt.isEmpty) return null;

    final deltas = atAlt.map((e) => e.deltaIsaC).toSet().toList()..sort();
    final db = _bracket(deltas, dIsa);

    final pLo = _find(atAlt, w, alt, db.lo);
    final pHi = _find(atAlt, w, alt, db.hi);

    if (pLo == null && pHi == null) return null;
    if (pLo == null) return _pointToResult(pHi!);
    if (pHi == null || db.lo == db.hi) return _pointToResult(pLo);

    final t = (dIsa - db.lo) / (db.hi - db.lo);
    return _lerpPointResults(pLo, pHi, t);
  }

  static InterpolatedResult _pointToResult(PerformancePoint p) =>
      InterpolatedResult(
        toGround: p.takeoffGroundRollM, toOver50: p.takeoffOver50M,
        ldGround: p.landingGroundRollM, ldOver50: p.landingOver50M,
        headwindTakeoffPercentPerKt: p.headwindTakeoffPercentPerKt,
        tailwindTakeoffPercentPerKt: p.tailwindTakeoffPercentPerKt,
        headwindLandingPercentPerKt: p.headwindLandingPercentPerKt,
        tailwindLandingPercentPerKt: p.tailwindLandingPercentPerKt,
        slopeTakeoffPercentPerPercent: p.slopeTakeoffPercentPerPercent,
        slopeLandingPercentPerPercent: p.slopeLandingPercentPerPercent,
      );

  static InterpolatedResult _lerpPointResults(PerformancePoint p0, PerformancePoint p1, double t) {
    return InterpolatedResult(
      toGround: _lerp(p0.takeoffGroundRollM, p1.takeoffGroundRollM, t),
      toOver50: _lerp(p0.takeoffOver50M, p1.takeoffOver50M, t),
      ldGround: _lerp(p0.landingGroundRollM, p1.landingGroundRollM, t),
      ldOver50: _lerp(p0.landingOver50M, p1.landingOver50M, t),
      headwindTakeoffPercentPerKt: _lerpOpt(p0.headwindTakeoffPercentPerKt, p1.headwindTakeoffPercentPerKt, t),
      tailwindTakeoffPercentPerKt: _lerpOpt(p0.tailwindTakeoffPercentPerKt, p1.tailwindTakeoffPercentPerKt, t),
      headwindLandingPercentPerKt: _lerpOpt(p0.headwindLandingPercentPerKt, p1.headwindLandingPercentPerKt, t),
      tailwindLandingPercentPerKt: _lerpOpt(p0.tailwindLandingPercentPerKt, p1.tailwindLandingPercentPerKt, t),
      slopeTakeoffPercentPerPercent: _lerpOpt(p0.slopeTakeoffPercentPerPercent, p1.slopeTakeoffPercentPerPercent, t),
      slopeLandingPercentPerPercent: _lerpOpt(p0.slopeLandingPercentPerPercent, p1.slopeLandingPercentPerPercent, t),
    );
  }

  static InterpolatedResult _lerpResults(InterpolatedResult a, InterpolatedResult b, double t) {
    return InterpolatedResult(
      toGround: _lerp(a.toGround, b.toGround, t),
      toOver50: _lerp(a.toOver50, b.toOver50, t),
      ldGround: _lerp(a.ldGround, b.ldGround, t),
      ldOver50: _lerp(a.ldOver50, b.ldOver50, t),
      headwindTakeoffPercentPerKt: _lerpOpt(a.headwindTakeoffPercentPerKt, b.headwindTakeoffPercentPerKt, t),
      tailwindTakeoffPercentPerKt: _lerpOpt(a.tailwindTakeoffPercentPerKt, b.tailwindTakeoffPercentPerKt, t),
      headwindLandingPercentPerKt: _lerpOpt(a.headwindLandingPercentPerKt, b.headwindLandingPercentPerKt, t),
      tailwindLandingPercentPerKt: _lerpOpt(a.tailwindLandingPercentPerKt, b.tailwindLandingPercentPerKt, t),
      slopeTakeoffPercentPerPercent: _lerpOpt(a.slopeTakeoffPercentPerPercent, b.slopeTakeoffPercentPerPercent, t),
      slopeLandingPercentPerPercent: _lerpOpt(a.slopeLandingPercentPerPercent, b.slopeLandingPercentPerPercent, t),
    );
  }

  static PerformancePoint? _find(List<PerformancePoint> list, double w, double a, double d) {
    for (final p in list) {
      if ((p.weightKg - w).abs() < 1e-6 &&
          (p.pressureAltitudeFt - a).abs() < 1e-6 &&
          (p.deltaIsaC - d).abs() < 1e-6) {
        return p;
      }
    }
    return null;
  }

  static _Bracket _bracket(List<double> sorted, double value) {
    double lo = sorted.first;
    double hi = sorted.last;
    for (final v in sorted) {
      if (v <= value) lo = v;
      if (v >= value) { hi = v; break; }
    }
    return _Bracket(lo, hi);
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);

  /// Lerp two optional values. Returns null if both are null; uses the non-null one if only one is set.
  static double? _lerpOpt(double? a, double? b, double t) {
    if (a == null && b == null) return null;
    if (a == null) return b;
    if (b == null) return a;
    return _lerp(a, b, t);
  }
}

class _Bracket {
  final double lo;
  final double hi;
  const _Bracket(this.lo, this.hi);
}
