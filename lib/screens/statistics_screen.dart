import 'package:flutter/material.dart';
import '../models/daily_log.dart';
import '../services/water_history_service.dart';
import '../widgets/streak_card_widget.dart';
import '../widgets/weekly_chart_widget.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  bool _isLoading = true;
  List<DailyLog> _recentLogs = [];
  int _streakDays = 0;
  int _dailyAverage = 0;
  double _completionRate = 0.0;
  int _weeklyTotal = 0;
  final Map<String, int> _beverageBreakdown = {};

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    final historyService = WaterHistoryService();

    final logs = await historyService.getRecentLogs(daysCount: 7);
    final streak = await historyService.calculateCurrentStreak();

    int totalIntake = 0;
    int daysWithData = 0;
    int daysMet = 0;
    final breakdown = <String, int>{};

    for (final log in logs) {
      totalIntake += log.totalIntakeMl;
      if (log.totalIntakeMl > 0) daysWithData++;
      if (log.isGoalMet) daysMet++;

      for (final entry in log.entries) {
        breakdown[entry.beverageType] =
            (breakdown[entry.beverageType] ?? 0) + entry.amountMl;
      }
    }

    final avg = daysWithData > 0 ? (totalIntake / daysWithData).round() : 0;
    final rate = logs.isNotEmpty ? (daysMet / logs.length) : 0.0;

    if (mounted) {
      setState(() {
        _recentLogs = logs;
        _streakDays = streak;
        _dailyAverage = avg;
        _completionRate = rate;
        _weeklyTotal = totalIntake;
        _beverageBreakdown
          ..clear()
          ..addAll(breakdown);
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Hydration Statistics'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _loadStatistics,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollDynamicDelegate(),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                StreakCardWidget(
                  streakDays: _streakDays,
                  dailyAverageMl: _dailyAverage,
                  completionRate: _completionRate,
                ),
                const SizedBox(height: 20),
                WeeklyChartWidget(logs: _recentLogs),
                const SizedBox(height: 20),
                _WeeklySummaryCard(
                  totalMl: _weeklyTotal,
                  dailyAverage: _dailyAverage,
                ),
                if (_beverageBreakdown.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _BeverageBreakdownCard(breakdown: _beverageBreakdown),
                ],
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AlwaysScrollableScrollDynamicDelegate extends ScrollPhysics {
  const AlwaysScrollableScrollDynamicDelegate({super.parent});

  @override
  AlwaysScrollableScrollDynamicDelegate applyTo(ScrollPhysics? ancestor) {
    return AlwaysScrollableScrollDynamicDelegate(parent: buildParent(ancestor));
  }

  @override
  bool shouldAcceptUserOffset(ScrollMetrics position) => true;
}

class _WeeklySummaryCard extends StatelessWidget {
  final int totalMl;
  final int dailyAverage;

  const _WeeklySummaryCard({
    required this.totalMl,
    required this.dailyAverage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final liters = (totalMl / 1000).toStringAsFixed(1);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '7-Day Summary',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${liters}L',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Text(
                      'Total Consumed',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${dailyAverage}ml',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const Text(
                      'Daily Average',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BeverageBreakdownCard extends StatelessWidget {
  final Map<String, int> breakdown;

  const _BeverageBreakdownCard({required this.breakdown});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = breakdown.values.fold<int>(0, (s, e) => s + e);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Beverage Distribution',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...breakdown.entries.map((entry) {
            final percentage = total > 0 ? (entry.value / total) : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        entry.key,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      Text(
                        '${entry.value}ml (${(percentage * 100).round()}%)',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 6,
                      backgroundColor:
                          theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
