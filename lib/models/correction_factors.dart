import 'package:hive/hive.dart';

part 'correction_factors.g.dart';

@HiveType(typeId: 2)
class CorrectionFactors extends HiveObject {
  @HiveField(0)
  double headwindTakeoffPercentPerKt;
  @HiveField(1)
  double tailwindTakeoffPercentPerKt;
  @HiveField(2)
  double headwindLandingPercentPerKt;
  @HiveField(3)
  double tailwindLandingPercentPerKt;
  @HiveField(4)
  double slopeTakeoffPercentPerPercent;
  @HiveField(5)
  double slopeLandingPercentPerPercent;

  CorrectionFactors({
    this.headwindTakeoffPercentPerKt = 0.0,
    this.tailwindTakeoffPercentPerKt = 0.0,
    this.headwindLandingPercentPerKt = 0.0,
    this.tailwindLandingPercentPerKt = 0.0,
    this.slopeTakeoffPercentPerPercent = 0.0,
    this.slopeLandingPercentPerPercent = 0.0,
  });

  Map<String, dynamic> toJson() => {
        'headwindTakeoffPercentPerKt': headwindTakeoffPercentPerKt,
        'tailwindTakeoffPercentPerKt': tailwindTakeoffPercentPerKt,
        'headwindLandingPercentPerKt': headwindLandingPercentPerKt,
        'tailwindLandingPercentPerKt': tailwindLandingPercentPerKt,
        'slopeTakeoffPercentPerPercent': slopeTakeoffPercentPerPercent,
        'slopeLandingPercentPerPercent': slopeLandingPercentPerPercent,
      };

  factory CorrectionFactors.fromJson(Map<String, dynamic> j) => CorrectionFactors(
        headwindTakeoffPercentPerKt: (j['headwindTakeoffPercentPerKt'] ?? 0).toDouble(),
        tailwindTakeoffPercentPerKt: (j['tailwindTakeoffPercentPerKt'] ?? 0).toDouble(),
        headwindLandingPercentPerKt: (j['headwindLandingPercentPerKt'] ?? 0).toDouble(),
        tailwindLandingPercentPerKt: (j['tailwindLandingPercentPerKt'] ?? 0).toDouble(),
        slopeTakeoffPercentPerPercent: (j['slopeTakeoffPercentPerPercent'] ?? 0).toDouble(),
        slopeLandingPercentPerPercent: (j['slopeLandingPercentPerPercent'] ?? 0).toDouble(),
      );
}