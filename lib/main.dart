import 'package:flutter/material.dart';
import 'services/hive_service.dart';
import 'pages/aircraft_list_page.dart';
void main() async { WidgetsFlutterBinding.ensureInitialized(); await HiveService.init(); runApp(const rPerfApp()); }
class rPerfApp extends StatelessWidget { const rPerfApp({super.key});
  @override Widget build(BuildContext context) {
    return MaterialApp(title: 'rPerf', theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue), useMaterial3: true, inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(),)), home: const AircraftListPage());
  }
}