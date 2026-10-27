import 'package:flutter/material.dart';

class QuickIntakeSelector extends StatelessWidget {
  final Function(int amount, String beverageType) onAddWater;

  const QuickIntakeSelector({
    super.key,
    required this.onAddWater,
  });

  void _showCustomDialog(BuildContext context) {
    final controller = TextEditingController();
    String selectedBeverage = 'Water';
    final beverages = ['Water', 'Tea', 'Coffee', 'Juice', 'Electrolytes'];

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Add Custom Intake'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: controller,
                    keyboardType: TextInputType.number,
                    autofocus: true,
                    decoration: const InputDecoration(
                      labelText: 'Amount (ml)',
                      suffixText: 'ml',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Beverage Type:',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: beverages.map((bev) {
                      final isSelected = bev == selectedBeverage;
                      return ChoiceChip(
                        label: Text(bev),
                        selected: isSelected,
                        onSelected: (val) {
                          if (val) {
                            setDialogState(() => selectedBeverage = bev);
                          }
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    final val = int.tryParse(controller.text.trim());
                    if (val != null && val > 0) {
                      Navigator.pop(ctx);
                      onAddWater(val, selectedBeverage);
                    }
                  },
                  child: const Text('Add'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final presets = [
      {'name': 'Glass', 'amount': 200, 'icon': Icons.local_bar_rounded},
      {'name': 'Mug', 'amount': 300, 'icon': Icons.coffee_rounded},
      {'name': 'Bottle', 'amount': 500, 'icon': Icons.local_drink_rounded},
      {'name': 'Large', 'amount': 750, 'icon': Icons.sports_gymnastics_rounded},
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Quick Log',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton.icon(
                onPressed: () => _showCustomDialog(context),
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Custom'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: presets.map((preset) {
            final name = preset['name'] as String;
            final amount = preset['amount'] as int;
            final icon = preset['icon'] as IconData;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                child: InkWell(
                  onTap: () => onAddWater(amount, 'Water'),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          color: theme.colorScheme.primary,
                          size: 26,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '+$amount',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        ),
                        Text(
                          name,
                          style: TextStyle(
                            fontSize: 11,
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
