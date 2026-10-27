import 'package:flutter/material.dart';
import '../models/water_entry.dart';

class TodayIntakeList extends StatelessWidget {
  final List<WaterEntry> entries;
  final Function(String id) onDeleteEntry;

  const TodayIntakeList({
    super.key,
    required this.entries,
    required this.onDeleteEntry,
  });

  IconData _iconForBeverage(String type) {
    switch (type.toLowerCase()) {
      case 'coffee':
        return Icons.coffee_rounded;
      case 'tea':
        return Icons.emoji_food_beverage_rounded;
      case 'juice':
        return Icons.liquor_rounded;
      case 'electrolytes':
        return Icons.bolt_rounded;
      case 'water':
      default:
        return Icons.water_drop_rounded;
    }
  }

  Color _colorForBeverage(String type, BuildContext context) {
    final theme = Theme.of(context);
    switch (type.toLowerCase()) {
      case 'coffee':
        return Colors.brown;
      case 'tea':
        return Colors.green;
      case 'juice':
        return Colors.orange;
      case 'electrolytes':
        return Colors.amber.shade700;
      case 'water':
      default:
        return theme.colorScheme.primary;
    }
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (entries.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.25),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.water_drop_outlined,
              size: 40,
              color: theme.colorScheme.primary.withValues(alpha: 0.5),
            ),
            const SizedBox(height: 8),
            Text(
              'No drinks logged today yet',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              'Stay hydrated and log your first drink!',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      );
    }

    final reversed = entries.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's History",
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '${entries.length} ${entries.length == 1 ? "entry" : "entries"}',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: reversed.length,
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final entry = reversed[index];
            final color = _colorForBeverage(entry.beverageType, context);

            return Dismissible(
              key: Key(entry.id),
              direction: DismissDirection.endToStart,
              background: Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(right: 20),
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.delete, color: Colors.white),
              ),
              onDismissed: (_) => onDeleteEntry(entry.id),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _iconForBeverage(entry.beverageType),
                        size: 20,
                        color: color,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            entry.beverageType,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          Text(
                            _formatTime(entry.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '+${entry.amountMl} ml',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                      onPressed: () => onDeleteEntry(entry.id),
                      tooltip: 'Remove',
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
