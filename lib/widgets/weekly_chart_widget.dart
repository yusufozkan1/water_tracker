import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/daily_log.dart';

class WeeklyChartWidget extends StatelessWidget {
  final List<DailyLog> logs; // Last 7 days

  const WeeklyChartWidget({super.key, required this.logs});

  String _dayLabel(String dateStr) {
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        final dt = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
        const weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
        return weekdays[dt.weekday - 1];
      }
    } catch (_) {}
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Compute max for scaling
    int maxIntake = 1;
    for (final l in logs) {
      if (l.totalIntakeMl > maxIntake) maxIntake = l.totalIntakeMl;
      if (l.goalMl > maxIntake) maxIntake = l.goalMl;
    }
    // Round max up slightly for nice chart headroom
    final chartMax = (maxIntake * 1.15).ceil();

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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Weekly Intake',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0288D1),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Intake', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 12),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                      color: Colors.amber,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Text('Goal', style: TextStyle(fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 160,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: logs.map((log) {
                final dayName = _dayLabel(log.date);
                final intakeRatio =
                    (log.totalIntakeMl / chartMax).clamp(0.0, 1.0);
                final goalRatio = (log.goalMl / chartMax).clamp(0.0, 1.0);
                final isToday = log.date ==
                    '${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}-${DateTime.now().day.toString().padLeft(2, '0')}';

                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Tooltip or amount text if non-zero
                        if (log.totalIntakeMl > 0)
                          Text(
                            '${(log.totalIntakeMl / 1000).toStringAsFixed(1)}L',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: log.isGoalMet
                                  ? Colors.teal
                                  : theme.colorScheme.primary,
                            ),
                          )
                        else
                          const SizedBox(height: 12),
                        const SizedBox(height: 4),
                        // Bar stack
                        Expanded(
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final maxHeight = constraints.maxHeight;
                              final barHeight =
                                  math.max(maxHeight * intakeRatio, 4.0);
                              final goalLineBottom = maxHeight * goalRatio;

                              return Stack(
                                alignment: Alignment.bottomCenter,
                                children: [
                                  // Background slot track
                                  Container(
                                    width: 18,
                                    height: maxHeight,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),

                                  // Goal dotted / reference marker
                                  Positioned(
                                    bottom: goalLineBottom,
                                    left: 0,
                                    right: 0,
                                    child: Container(
                                      height: 2,
                                      color: Colors.amber.withValues(alpha: 0.7),
                                    ),
                                  ),

                                  // Filled bar
                                  Container(
                                    width: 18,
                                    height: barHeight,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: log.isGoalMet
                                            ? [
                                                const Color(0xFF00B4D8),
                                                const Color(0xFF0077B6)
                                              ]
                                            : [
                                                theme.colorScheme.primary,
                                                theme.colorScheme.primary
                                                    .withValues(alpha: 0.7)
                                              ],
                                      ),
                                      borderRadius: BorderRadius.circular(9),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          dayName,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.normal,
                            color: isToday
                                ? theme.colorScheme.primary
                                : theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
