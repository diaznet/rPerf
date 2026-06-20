import 'package:hive/hive.dart';

part 'performance_point.g.dart';

@HiveType(typeId: 1)
class PerformancePoint extends HiveObject {
  @HiveField(0)
  String runwayType; // 'concrete' or 'grass'
  @HiveField(1)
  double weightKg;
  @HiveField(2)
  double pressureAltitudeFt;
  @HiveField(3)
  double deltaIsaC;

  // Distances in meters
  @HiveField(4)
  double takeoffGroundRollM;
  @HiveField(5)
  double takeoffOver50M;
  @HiveField(6)
  double landingGroundRollM;
  @HiveField(7)
  double landingOver50M;

  // Optional per-point correction factors (override aircraft-level defaults)
  @HiveField(8)
  double? headwindTakeoffPercentPerKt;
  @HiveField(9)
  double? tailwindTakeoffPercentPerKt;
  @HiveField(10)
  double? headwindLandingPercentPerKt;
  @HiveField(11)
  double? tailwindLandingPercentPerKt;
  @HiveField(12)
  double? slopeTakeoffPercentPerPercent;
  @HiveField(13)
  double? slopeLandingPercentPerPercent;

  PerformancePoint({
    required this.runwayType,
    required this.weightKg,
    required this.pressureAltitudeFt,
    required this.deltaIsaC,
    required this.takeoffGroundRollM,
    required this.takeoffOver50M,
    required this.landingGroundRollM,
    required this.landingOver50M,
    this.headwindTakeoffPercentPerKt,
    this.tailwindTakeoffPercentPerKt,
    this.headwindLandingPercentPerKt,
    this.tailwindLandingPercentPerKt,
    this.slopeTakeoffPercentPerPercent,
    this.slopeLandingPercentPerPercent,
  });
}
