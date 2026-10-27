import 'package:flutter/material.dart';
import 'package:water_tracker/screens/countdown_timer_page.dart';
import 'package:water_tracker/screens/settings_screen.dart';
import 'package:water_tracker/screens/statistics_screen.dart';
import 'package:water_tracker/screens/tracker_screen.dart';
import 'package:water_tracker/services/notification_service.dart';
import 'package:water_tracker/services/preferences_manager.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final Future<bool> _initFuture;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _initFuture = _initApp();
  }

  Future<bool> _initApp() async {
    await Future.wait([
      PreferencesManager().init(),
      NotificationService().init(),
    ]);
    return true;
  }

  void _onTabSelected(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading Water Tracker...',
                    style: TextStyle(fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),
          );
        }

        final pages = [
          TrackerScreen(
            onNavigateToSettings: () => _onTabSelected(3),
            onNavigateToTimer: () => _onTabSelected(2),
          ),
          const StatisticsScreen(),
          const CountdownTimerPage(),
          const SettingsScreen(),
        ];

        return Scaffold(
          body: IndexedStack(
            index: _currentIndex,
            children: pages,
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.water_drop_outlined),
                selectedIcon: Icon(Icons.water_drop, color: Colors.blue),
                label: 'Today',
              ),
              NavigationDestination(
                icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart, color: Colors.blue),
                label: 'Stats',
              ),
              NavigationDestination(
                icon: Icon(Icons.timer_outlined),
                selectedIcon: Icon(Icons.timer, color: Colors.blue),
                label: 'Timer',
              ),
              NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: Colors.blue),
                label: 'Settings',
              ),
            ],
          ),
        );
      },
    );
  }
}
