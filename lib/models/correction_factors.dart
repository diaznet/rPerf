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
}