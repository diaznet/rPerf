import 'package:hive/hive.dart';
import 'performance_point.dart';
import 'correction_factors.dart';

part 'aircraft.g.dart';

@HiveType(typeId: 0)
class Aircraft extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String registration;
  @HiveField(2)
  String name;
  @HiveField(3)
  double mtowKg;
  @HiveField(4)
  double? grassPenaltyPercentIfNoGrassData;
  @HiveField(5)
  CorrectionFactors correctionFactors;
  @HiveField(6)
  List<PerformancePoint> points;

  Aircraft({
    required this.id,
    required this.registration,
    required this.name,
    required this.mtowKg,
    required this.correctionFactors,
    this.grassPenaltyPercentIfNoGrassData,
    List<PerformancePoint>? points,
  }) : points = points ?? [];

  bool hasRunwayType(String type) => points.any((p) => p.runwayType == type);
}