import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:water_tracker/screens/home_screen.dart';
import 'package:water_tracker/services/timer_foreground_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Communication port initialization for foreground task
  FlutterForegroundTask.initCommunicationPort();

  // Foreground service initialization
  await TimerForegroundService.init();

  runApp(const WaterTrackerApp());
}

class WaterTrackerApp extends StatelessWidget {
  const WaterTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Water Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0288D1),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0288D1),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      themeMode: ThemeMode.system,
      // WithForegroundTask must be inside MaterialApp to have access to Navigator
      home: const WithForegroundTask(
        child: HomeScreen(),
      ),
    );
  }
}
