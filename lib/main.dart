import 'package:flutter/material.dart';
import 'services/hive_service.dart';
import 'services/airport_service.dart';
import 'pages/aircraft_list_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const rPerfApp());
}

class rPerfApp extends StatelessWidget {
  const rPerfApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'rPerf',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder()),
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await HiveService.init();
      AirportService.checkAndUpdate();
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const AircraftListPage()),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/Splash-Screen.jpg',
            fit: BoxFit.cover,
          ),
          Container(color: Colors.white.withValues(alpha: 0.7)),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset('assets/images/rperf_logo.png', width: 120, height: 120),
                const SizedBox(height: 16),
                const Text('rPerf', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black87)),
                const SizedBox(height: 8),
                const Text('Takeoff & Landing Performance', style: TextStyle(fontSize: 14, color: Colors.black54)),
                const SizedBox(height: 32),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text('Failed to initialize: $_error\n\nTry clearing app data.',
                      textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                  )
                else
                  const CircularProgressIndicator(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
