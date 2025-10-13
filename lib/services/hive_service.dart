import 'package:hive_flutter/hive_flutter.dart';
import '../models/aircraft.dart';
import '../models/performance_point.dart';
import '../models/correction_factors.dart';

class HiveService {
  static const aircraftBoxName = 'aircraft_box';

  static Future<void> init() async {
    await Hive.initFlutter();
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(AircraftAdapter());
    if (!Hive.isAdapterRegistered(1)) Hive.registerAdapter(PerformancePointAdapter());
    if (!Hive.isAdapterRegistered(2)) Hive.registerAdapter(CorrectionFactorsAdapter());
    await Hive.openBox<Aircraft>(aircraftBoxName);
  }

  static Box<Aircraft> aircraftBox() => Hive.box<Aircraft>(aircraftBoxName);

  static Future<void> addAircraft(Aircraft a) async {
    final box = aircraftBox();
    await box.put(a.id, a);
  }

  static Future<void> deleteAircraft(String id) async {
    final box = aircraftBox();
    await box.delete(id);
  }
}