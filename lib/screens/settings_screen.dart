import 'package:flutter/material.dart';
import 'package:water_tracker/services/notification_service.dart';
import 'package:water_tracker/services/preferences_manager.dart';
import 'package:water_tracker/services/water_history_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _goalController = TextEditingController();

  int _dailyGoal = 3000;
  bool _remindersEnabled = true;
  int _reminderInterval = 90; // minutes
  int _startHour = 8; // 8:00 AM
  int _endHour = 22; // 10:00 PM

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _goalController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    final goal = await PreferencesManager().get<int>('daily_goal', 3000) ?? 3000;
    final reminders = await PreferencesManager().get<bool>(
            NotificationService.keyRemindersEnabled, true) ??
        true;
    final interval = await PreferencesManager().get<int>(
            NotificationService.keyReminderIntervalMinutes, 90) ??
        90;
    final start = await PreferencesManager().get<int>(
            NotificationService.keyReminderStartHour, 8) ??
        8;
    final end = await PreferencesManager().get<int>(
            NotificationService.keyReminderEndHour, 22) ??
        22;

    if (mounted) {
      setState(() {
        _dailyGoal = goal;
        _goalController.text = _dailyGoal.toString();
        _remindersEnabled = reminders;
        _reminderInterval = interval;
        _startHour = start;
        _endHour = end;
      });
    }
  }

  Future<void> _saveSettings() async {
    final int? newGoal = int.tryParse(_goalController.text);
    if (newGoal == null || newGoal <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please enter a valid goal amount")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      // 1. Save Goal
      await WaterHistoryService().setDailyGoal(newGoal);

      // 2. Save Reminder Preferences
      await PreferencesManager().set<bool>(
        NotificationService.keyRemindersEnabled,
        _remindersEnabled,
      );
      await PreferencesManager().set<int>(
        NotificationService.keyReminderIntervalMinutes,
        _reminderInterval,
      );
      await PreferencesManager().set<int>(
        NotificationService.keyReminderStartHour,
        _startHour,
      );
      await PreferencesManager().set<int>(
        NotificationService.keyReminderEndHour,
        _endHour,
      );

      // 3. Update Notification Service Schedule
      await NotificationService().syncReminderScheduleFromPreferences();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Settings saved successfully!"),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _testReminder() async {
    await NotificationService().showNotification();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Test notification sent!")),
      );
    }
  }

  String _formatHour(int hour) {
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour);
    return '$displayHour:00 $period';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // DAILY GOAL SECTION
              _SectionHeader(
                title: "Daily Hydration Goal",
                icon: Icons.flag_rounded,
                theme: theme,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: _goalController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: "Target Volume",
                        suffixText: 'ml',
                        border: const OutlineInputBorder(),
                        prefixIcon: const Icon(Icons.water_drop_rounded),
                        filled: true,
                        fillColor: theme.colorScheme.surface,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Quick Presets:",
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [2000, 2500, 3000, 3500].map((preset) {
                        final isSelected =
                            _goalController.text == preset.toString();
                        return ActionChip(
                          avatar: isSelected
                              ? const Icon(Icons.check, size: 16)
                              : null,
                          label: Text('$preset ml'),
                          backgroundColor: isSelected
                              ? theme.colorScheme.primaryContainer
                              : null,
                          onPressed: () {
                            setState(() {
                              _goalController.text = preset.toString();
                            });
                          },
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // REMINDERS SECTION
              _SectionHeader(
                title: "Hydration Reminders",
                icon: Icons.notifications_active_rounded,
                theme: theme,
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
                  ),
                ),
                child: Column(
                  children: [
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        "Periodic Reminders",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        "Receive gentle nudges to drink water throughout the day",
                        style: TextStyle(fontSize: 12),
                      ),
                      value: _remindersEnabled,
                      onChanged: (val) {
                        setState(() => _remindersEnabled = val);
                      },
                    ),
                    if (_remindersEnabled) ...[
                      const Divider(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Remind every:",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          DropdownButton<int>(
                            value: _reminderInterval,
                            underline: const SizedBox(),
                            items: const [
                              DropdownMenuItem(value: 45, child: Text("45 mins")),
                              DropdownMenuItem(value: 60, child: Text("1 hour")),
                              DropdownMenuItem(value: 90, child: Text("1.5 hours")),
                              DropdownMenuItem(value: 120, child: Text("2 hours")),
                              DropdownMenuItem(value: 180, child: Text("3 hours")),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _reminderInterval = val);
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            "Active Hours:",
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          Text(
                            "${_formatHour(_startHour)} – ${_formatHour(_endHour)}",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                        ],
                      ),
                      RangeSlider(
                        values: RangeValues(
                          _startHour.toDouble(),
                          _endHour.toDouble(),
                        ),
                        min: 6,
                        max: 24,
                        divisions: 18,
                        labels: RangeLabels(
                          _formatHour(_startHour),
                          _formatHour(_endHour),
                        ),
                        onChanged: (RangeValues vals) {
                          setState(() {
                            _startHour = vals.start.round();
                            _endHour = vals.end.round();
                          });
                        },
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: _testReminder,
                        icon: const Icon(Icons.notifications_outlined, size: 18),
                        label: const Text("Send Test Notification Now"),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // SAVE BUTTON
              FilledButton.icon(
                onPressed: _isSaving ? null : _saveSettings,
                icon: _isSaving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.save_rounded),
                label: const Text(
                  "Save Settings",
                  style: TextStyle(fontSize: 16),
                ),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(double.infinity, 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // HYDRATION TIP
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.lightbulb_outline, color: Colors.blue),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        "Tip: Drinking a glass of water right after waking up jumpstarts your metabolism and restores morning hydration.",
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final IconData icon;
  final ThemeData theme;

  const _SectionHeader({
    required this.title,
    required this.icon,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
