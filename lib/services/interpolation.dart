import '../models/performance_point.dart';

class InterpolatedResult {
  final double toGround;
  final double toOver50;
  final double ldGround;
  final double ldOver50;

  InterpolatedResult({
    required this.toGround,
    required this.toOver50,
    required this.ldGround,
    required this.ldOver50,
  });
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
    if (pts.isEmpty) {
      // No data of that type
      return InterpolatedResult(toGround: double.nan, toOver50: double.nan, ldGround: double.nan, ldOver50: double.nan);
    }

    // Group by weight unique levels
    final weights = pts.map((e) => e.weightKg).toSet().toList()..sort();
    double w0 = weights.first;
    double w1 = weights.last;

    // Find bracketing weights
    for (int i = 0; i < weights.length; i++) {
      if (weights[i] <= weightKg) w0 = weights[i];
      if (weights[i] >= weightKg) {
        w1 = weights[i];
        break;
      }
    }

    // Interpolate at w0 and w1 (bilinear), then linear across weight
    final r0 = _bilinearAtWeight(pts, w0, paFt, deltaIsaC);
    final r1 = _bilinearAtWeight(pts, w1, paFt, deltaIsaC);

    if (w0 == w1) {
      return r0;
    } else {
      final t = (weightKg - w0) / (w1 - w0);
      return InterpolatedResult(
        toGround: _lerp(r0.toGround, r1.toGround, t),
        toOver50: _lerp(r0.toOver50, r1.toOver50, t),
        ldGround: _lerp(r0.ldGround, r1.ldGround, t),
        ldOver50: _lerp(r0.ldOver50, r1.ldOver50, t),
      );
    }
  }

  static InterpolatedResult _bilinearAtWeight(
      List<PerformancePoint> pts, double weightKg, double paFt, double dIsa) {
    final wPts = pts.where((p) => (p.weightKg - weightKg).abs() < 1e-6 || p.weightKg == weightKg).toList();
    // If no exact weight matches, pick all with this weight (we will filter below)
    final exactWeightPts = pts.where((p) => p.weightKg == weightKg).toList();
    final List<PerformancePoint> pool = exactWeightPts.isNotEmpty ? exactWeightPts : pts.where((p) => (p.weightKg - weightKg).abs() < 1e-6 || p.weightKg == weightKg).toList();

    // Build axes (alt and delta)
    final alts = pool.map((e) => e.pressureAltitudeFt).toSet().toList()..sort();
    final deltas = pool.map((e) => e.deltaIsaC).toSet().toList()..sort();

    // If the pool is empty (no specific points at that weight), fallback to nearest weight set
    final byWeight = pts.where((p) => p.weightKg == weightKg).toList();
    final use = byWeight.isNotEmpty ? byWeight : pts;

    // Find bracketing altitudes and deltas
    double a0 = alts.isNotEmpty ? alts.first : paFt;
    double a1 = alts.isNotEmpty ? alts.last : paFt;
    for (final a in alts) {
      if (a <= paFt) a0 = a;
      if (a >= paFt) {
        a1 = a;
        break;
      }
    }
    double d0 = deltas.isNotEmpty ? deltas.first : dIsa;
    double d1 = deltas.isNotEmpty ? deltas.last : dIsa;
    for (final d in deltas) {
      if (d <= dIsa) d0 = d;
      if (d >= dIsa) {
        d1 = d;
        break;
      }
    }

    PerformancePoint? p00 = _find(use, weightKg, a0, d0);
    PerformancePoint? p10 = _find(use, weightKg, a1, d0);
    PerformancePoint? p01 = _find(use, weightKg, a0, d1);
    PerformancePoint? p11 = _find(use, weightKg, a1, d1);

    // If exact exists
    final exact = _find(use, weightKg, paFt, dIsa);
    if (exact != null) {
      return InterpolatedResult(
        toGround: exact.takeoffGroundRollM,
        toOver50: exact.takeoffOver50M,
        ldGround: exact.landingGroundRollM,
        ldOver50: exact.landingOver50M,
      );
    }

    // Fallbacks if corners missing
    if (a0 == a1 && d0 == d1 && p00 != null) {
      return InterpolatedResult(
        toGround: p00.takeoffGroundRollM,
        toOver50: p00.takeoffOver50M,
        ldGround: p00.landingGroundRollM,
        ldOver50: p00.landingOver50M,
      );
    }

    if (a0 == a1) {
      // Linear in delta
      final q0 = p00 ?? _findNearest(use, weightKg, a0, d0);
      final q1 = p01 ?? _findNearest(use, weightKg, a0, d1);
      final t = (dIsa - d0) / ((d1 - d0).abs() < 1e-9 ? 1 : (d1 - d0));
      return _lerpPoints(q0!, q1!, t);
    }
    if (d0 == d1) {
      // Linear in altitude
      final q0 = p00 ?? _findNearest(use, weightKg, a0, d0);
      final q1 = p10 ?? _findNearest(use, weightKg, a1, d0);
      final t = (paFt - a0) / ((a1 - a0).abs() < 1e-9 ? 1 : (a1 - a0));
      return _lerpPoints(q0!, q1!, t);
    }

    // Bilinear:
    // First interpolate along altitude for both delta rows, then along delta
    final f_d0 = _lerpPoints(
      p00 ?? _findNearest(use, weightKg, a0, d0)!,
      p10 ?? _findNearest(use, weightKg, a1, d0)!,
      (paFt - a0) / ((a1 - a0).abs() < 1e-9 ? 1 : (a1 - a0)),
    );
    final f_d1 = _lerpPoints(
      p01 ?? _findNearest(use, weightKg, a0, d1)!,
      p11 ?? _findNearest(use, weightKg, a1, d1)!,
      (paFt - a0) / ((a1 - a0).abs() < 1e-9 ? 1 : (a1 - a0)),
    );
    final t2 = (dIsa - d0) / ((d1 - d0).abs() < 1e-9 ? 1 : (d1 - d0));
    return InterpolatedResult(
      toGround: _lerp(f_d0.toGround, f_d1.toGround, t2),
      toOver50: _lerp(f_d0.toOver50, f_d1.toOver50, t2),
      ldGround: _lerp(f_d0.ldGround, f_d1.ldGround, t2),
      ldOver50: _lerp(f_d0.ldOver50, f_d1.ldOver50, t2),
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

static PerformancePoint? _findNearest(List<PerformancePoint> list, double w, double a, double d) {
  if (list.isEmpty) return null;
  final sorted = List<PerformancePoint>.from(list)
    ..sort((p1, p2) {
      final e1 = (p1.weightKg - w).abs() + (p1.pressureAltitudeFt - a).abs() + (p1.deltaIsaC - d).abs();
      final e2 = (p2.weightKg - w).abs() + (p2.pressureAltitudeFt - a).abs() + (p2.deltaIsaC - d).abs();
      return e1.compareTo(e2);
    });
  return sorted.first;
}


  static InterpolatedResult _lerpPoints(PerformancePoint p0, PerformancePoint p1, double t) {
    return InterpolatedResult(
      toGround: _lerp(p0.takeoffGroundRollM, p1.takeoffGroundRollM, t),
      toOver50: _lerp(p0.takeoffOver50M, p1.takeoffOver50M, t),
      ldGround: _lerp(p0.landingGroundRollM, p1.landingGroundRollM, t),
      ldOver50: _lerp(p0.landingOver50M, p1.landingOver50M, t),
    );
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t.clamp(0.0, 1.0);
}