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

  PerformancePoint({
    required this.runwayType,
    required this.weightKg,
    required this.pressureAltitudeFt,
    required this.deltaIsaC,
    required this.takeoffGroundRollM,
    required this.takeoffOver50M,
    required this.landingGroundRollM,
    required this.landingOver50M,
  });

  Map<String, dynamic> toJson() => {
        'runwayType': runwayType,
        'weightKg': weightKg,
        'pressureAltitudeFt': pressureAltitudeFt,
        'deltaIsaC': deltaIsaC,
        'takeoffGroundRollM': takeoffGroundRollM,
        'takeoffOver50M': takeoffOver50M,
        'landingGroundRollM': landingGroundRollM,
        'landingOver50M': landingOver50M,
      };

  factory PerformancePoint.fromJson(Map<String, dynamic> j) => PerformancePoint(
        runwayType: (j['runwayType'] ?? 'concrete').toString(),
        weightKg: (j['weightKg'] ?? 0).toDouble(),
        pressureAltitudeFt: (j['pressureAltitudeFt'] ?? 0).toDouble(),
        deltaIsaC: (j['deltaIsaC'] ?? 0).toDouble(),
        takeoffGroundRollM: (j['takeoffGroundRollM'] ?? 0).toDouble(),
        takeoffOver50M: (j['takeoffOver50M'] ?? 0).toDouble(),
        landingGroundRollM: (j['landingGroundRollM'] ?? 0).toDouble(),
        landingOver50M: (j['landingOver50M'] ?? 0).toDouble(),
      );
}