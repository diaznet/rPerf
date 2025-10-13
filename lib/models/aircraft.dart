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

  Map<String, dynamic> toJson() => {
    'id': id,
    'registration': registration,
    'name': name,
    'mtowKg': mtowKg,
    'grassPenaltyPercentIfNoGrassData': grassPenaltyPercentIfNoGrassData,
    'correctionFactors': correctionFactors.toJson(),
    'points': points.map((e) => e.toJson()).toList(),
  };

  factory Aircraft.fromJson(Map<String, dynamic> j) => Aircraft(
    id: (j['id'] ?? '').toString(),
    registration: (j['registration'] ?? '').toString(),
    name: (j['name'] ?? '').toString(),
    mtowKg: (j['mtowKg'] ?? 0).toDouble(),
    grassPenaltyPercentIfNoGrassData:
      j['grassPenaltyPercentIfNoGrassData'] == null ? null : (j['grassPenaltyPercentIfNoGrassData'] as num).toDouble(),
    correctionFactors: j['correctionFactors'] == null
      ? CorrectionFactors()
      : CorrectionFactors.fromJson(Map<String, dynamic>.from(j['correctionFactors'])),
    points: (j['points'] as List<dynamic>? ?? [])
      .map((e) => PerformancePoint.fromJson(Map<String, dynamic>.from(e)))
      .toList(),
  );
}