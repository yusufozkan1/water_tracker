import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../models/water_entry.dart';
import '../services/water_history_service.dart';
import '../widgets/animated_water_visual.dart';
import '../widgets/quick_intake_selector.dart';
import '../widgets/today_intake_list.dart';

class TrackerScreen extends StatefulWidget {
  final VoidCallback? onNavigateToSettings;
  final VoidCallback? onNavigateToTimer;

  const TrackerScreen({
    super.key,
    this.onNavigateToSettings,
    this.onNavigateToTimer,
  });

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen>
    with WidgetsBindingObserver {
  DailyLog? _todayLog;
  int _dailyGoal = 3000;
  bool _isLoading = true;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadData();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    final historyService = WaterHistoryService();
    final today = WaterHistoryService.today();

    final goal = await historyService.getDailyGoal();
    final log = await historyService.getDailyLog(today);

    if (mounted) {
      setState(() {
        _dailyGoal = goal;
        _todayLog = log ?? DailyLog(date: today, goalMl: goal, entries: const []);
        _isLoading = false;
      });
    }
  }

  Future<void> _addWater(int amount, String beverageType) async {
    if (_isBusy) return;
    _isBusy = true;

    try {
      final updatedLog = await WaterHistoryService().addWaterEntry(
        amountMl: amount,
        beverageType: beverageType,
      );

      if (mounted) {
        setState(() {
          _todayLog = updatedLog;
        });

        // Show celebratory or feedback snackbar
        if (updatedLog.isGoalMet &&
            (updatedLog.totalIntakeMl - amount) < updatedLog.goalMl) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("🎉 Congratulations! You reached your daily goal!"),
              backgroundColor: Colors.teal,
              duration: Duration(seconds: 3),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Added +$amount ml ($beverageType)'),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () {
                  if (updatedLog.entries.isNotEmpty) {
                    _deleteEntry(updatedLog.entries.last.id);
                  }
                },
              ),
            ),
          );
        }
      }
    } finally {
      _isBusy = false;
    }
  }

  Future<void> _deleteEntry(String entryId) async {
    final updated = await WaterHistoryService().removeWaterEntry(entryId);
    if (mounted && updated != null) {
      setState(() {
        _todayLog = updated;
      });
    }
  }

  Future<void> _confirmReset() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset Today\'s Progress?'),
        content: const Text(
          'This will clear all logged drinks for today. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await WaterHistoryService().resetToday();
      _loadData();
    }
  }

  String _getMotivationalMessage(int current, int goal) {
    if (goal <= 0) return 'Set your daily goal to begin tracking!';
    final remaining = goal - current;
    final progress = current / goal;

    if (progress >= 1.0) {
      return 'Amazing! Daily goal completed. Keep staying hydrated!';
    } else if (progress >= 0.75) {
      return 'Almost there! Only ${remaining}ml left to hit your goal.';
    } else if (progress >= 0.5) {
      return 'Halfway done! Keep up the good momentum.';
    } else if (progress >= 0.25) {
      return 'Great progress! Drink regularly throughout your day.';
    } else if (current > 0) {
      return 'Good start! Remember to sip water consistently.';
    } else {
      return 'Start your day with a fresh glass of water! 💧';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final currentIntake = _todayLog?.totalIntakeMl ?? 0;
    final progress = (_dailyGoal > 0) ? (currentIntake / _dailyGoal) : 0.0;
    final motivationalText = _getMotivationalMessage(currentIntake, _dailyGoal);
    final entries = _todayLog?.entries ?? <WaterEntry>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Water Tracker',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        actions: [
          if (widget.onNavigateToTimer != null)
            IconButton(
              icon: const Icon(Icons.timer_outlined),
              tooltip: 'Countdown Timer',
              onPressed: widget.onNavigateToTimer,
            ),
          if (widget.onNavigateToSettings != null)
            IconButton(
              icon: const Icon(Icons.settings_outlined),
              tooltip: 'Settings',
              onPressed: () async {
                widget.onNavigateToSettings!();
              },
            ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Column(
              children: [
                // Motivational Quote Banner
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.water_drop_rounded,
                        color: theme.colorScheme.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          motivationalText,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Animated Fluid Visual Gauge
                AnimatedWaterVisual(
                  progress: progress,
                  currentIntake: currentIntake,
                  dailyGoal: _dailyGoal,
                ),
                const SizedBox(height: 32),

                // Quick Intake Cup Buttons
                QuickIntakeSelector(onAddWater: _addWater),
                const SizedBox(height: 28),

                // Today's Drink Logs Timeline
                TodayIntakeList(
                  entries: entries,
                  onDeleteEntry: _deleteEntry,
                ),
                const SizedBox(height: 20),

                // Reset Action Button
                if (currentIntake > 0)
                  TextButton.icon(
                    onPressed: _confirmReset,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Reset Today\'s Intake'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.red.shade400,
                    ),
                  ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
