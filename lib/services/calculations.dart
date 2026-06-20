import 'dart:math';

class Calc {
  static double pressureAltitudeFt({
    required double fieldElevationFt,
    required double qnh,
    required String qnhUnit,
  }) {
    if (qnhUnit == 'hPa') {
      return fieldElevationFt + (1013.25 - qnh) * 27.0;
    } else {
      return fieldElevationFt + (29.92 - qnh) * 1000.0;
    }
  }

  static double isaTempCAt(double pressureAltitudeFt) {
    return 15.0 - 1.9812 * (pressureAltitudeFt / 1000.0);
  }

  static double deltaIsaC({
    required double pressureAltitudeFt,
    required double oatC,
  }) {
    final isa = isaTempCAt(pressureAltitudeFt);
    return oatC - isa;
  }

  /// Density altitude using the standard approximation:
  /// DA = PA + 120 × (OAT − ISA at PA)
  static double densityAltitudeFt({
    required double pressureAltitudeFt,
    required double oatC,
  }) {
    final isa = isaTempCAt(pressureAltitudeFt);
    return pressureAltitudeFt + 120.0 * (oatC - isa);
  }

  /// Decompose wind into headwind and crosswind components.
  /// [windDirDeg] = direction the wind is coming FROM (meteorological).
  /// [runwayHdgDeg] = runway heading.
  /// [windSpeedKts] = total wind speed.
  /// Returns (headwind, crosswind) — positive headwind = into the wind,
  /// positive crosswind = from the right.
  static ({double headwind, double crosswind}) windComponents({
    required double windDirDeg,
    required double runwayHdgDeg,
    required double windSpeedKts,
  }) {
    final angleDeg = windDirDeg - runwayHdgDeg;
    final angleRad = angleDeg * pi / 180.0;
    final headwind = windSpeedKts * cos(angleRad);
    final crosswind = windSpeedKts * sin(angleRad);
    return (headwind: headwind, crosswind: crosswind);
  }

  static double applyCorrections({
    required double base,
    required double windKts,
    required double slopePercent,
    required double headwindPercentPerKt,
    required double tailwindPercentPerKt,
    required double slopePercentPerPercent,
    required bool isTakeoff,
  }) {
    double factor = 1.0;
    if (windKts > 0) {
      factor *= (1.0 - (headwindPercentPerKt / 100.0) * windKts);
      if (factor < 0.1) factor = 0.1;
    } else if (windKts < 0) {
      factor *= (1.0 + (tailwindPercentPerKt / 100.0) * (-windKts));
    }
    // Uphill slope increases TO distance but decreases LDG distance
    final slopeSign = isTakeoff ? 1.0 : -1.0;
    factor *= (1.0 + (slopePercentPerPercent / 100.0) * slopePercent * slopeSign);
    if (factor < 0.1) factor = 0.1;
    return base * factor;
  }
}
