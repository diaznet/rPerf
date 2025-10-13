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
    return 15.0 - 1.98 * (pressureAltitudeFt / 1000.0);
  }

  static double deltaIsaC({
    required double pressureAltitudeFt,
    required double oatC,
  }) {
    final isa = isaTempCAt(pressureAltitudeFt);
    return oatC - isa;
  }

  static double applyCorrections({
    required double base,
    required double windKts,
    required double slopePercent,
    required double headwindPercentPerKt,
    required double tailwindPercentPerKt,
    required double slopePercentPerPercent,
  }) {
    double factor = 1.0;
    if (windKts > 0) {
      factor *= (1.0 - (headwindPercentPerKt / 100.0) * windKts);
      if (factor < 0.1) factor = 0.1;
    } else if (windKts < 0) {
      factor *= (1.0 + (tailwindPercentPerKt / 100.0) * (-windKts));
    }
    factor *= (1.0 + (slopePercentPerPercent / 100.0) * slopePercent);
    return base * factor;
  }
}