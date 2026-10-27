import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:water_tracker/services/preferences_manager.dart';
import 'package:water_tracker/services/notification_service.dart';
import 'package:water_tracker/services/timer_foreground_service.dart';

/// Production-grade countdown timer with BACKGROUND SUPPORT.
///
/// ARCHITECTURE:
/// - Uses absolute endTime (DateTime) for accurate timing
/// - Foreground Service updates notification every second in background
/// - Scheduled notification ensures "Time's up" even if app is killed
/// - State persists across app restarts via SharedPreferences
class CountdownTimerPage extends StatefulWidget {
  const CountdownTimerPage({super.key});

  @override
  State<CountdownTimerPage> createState() => _CountdownTimerPageState();
}

class _CountdownTimerPageState extends State<CountdownTimerPage>
    with WidgetsBindingObserver {
  // UI timer for display updates (foreground only)
  Timer? _uiTimer;

  // Audio player for completion sound
  AudioPlayer? _audioPlayer;

  // End time for the timer
  DateTime? _endTime;

  // Duration selection
  int _selectedMinutes = 5;

  // State flags
  bool _isRunning = false;
  bool _isFinished = false;
  bool _isLoading = true;

  // Constants
  static const int _minMinutes = 1;
  static const int _maxMinutes = 60;
  static const String _durationKey = 'timer_duration_minutes';
  static const String _endTimeKey = 'timer_end_time';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _audioPlayer = AudioPlayer();
    _loadSavedState();

    // Listen for events from foreground service
    FlutterForegroundTask.addTaskDataCallback(_onReceiveTaskData);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    FlutterForegroundTask.removeTaskDataCallback(_onReceiveTaskData);
    _uiTimer?.cancel();
    _audioPlayer?.dispose();
    super.dispose();
  }

  /// Handle events from foreground service (timer_complete)
  void _onReceiveTaskData(Object data) {
    if (data is Map && data['event'] == 'timer_complete') {
      debugPrint('CountdownTimerPage: Received timer_complete from service');
      if (mounted) {
        _onTimerComplete();
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _onAppResumed();
    } else if (state == AppLifecycleState.paused) {
      _onAppPaused();
    }
  }

  void _onAppPaused() {
    // Stop UI timer - foreground service handles background updates
    _uiTimer?.cancel();
    _uiTimer = null;
  }

  void _onAppResumed() {
    if (_isRunning && _endTime != null) {
      final diff = _endTime!.difference(DateTime.now()).inSeconds;
      if (diff <= 0) {
        // If expired recently (within 30 seconds), trigger completion effects
        if (diff >= -30) {
          _onTimerComplete();
        } else {
          // Expired long ago while closed/sleeping; clear silently without playing alarm
          _silentlyClearTimer();
        }
      } else {
        _startUiTimer();
      }
    }
  }

  /// Load saved duration and check for running timer
  Future<void> _loadSavedState() async {
    try {
      final savedDuration =
          await PreferencesManager().get<int>(_durationKey, 5);
      final savedEndTime =
          await PreferencesManager().get<String>(_endTimeKey, null);
      final isServiceRunning = await TimerForegroundService.isRunning;

      if (mounted) {
        setState(() {
          _selectedMinutes = savedDuration ?? 5;
          _isLoading = false;
        });

        // Check for running timer
        if (savedEndTime != null && savedEndTime.isNotEmpty) {
          _endTime = DateTime.tryParse(savedEndTime);
          if (_endTime != null) {
            final diff = _endTime!.difference(DateTime.now()).inSeconds;
            if (diff > 0) {
              // Timer still running - resume
              setState(() => _isRunning = true);
              _startUiTimer();

              // Ensure foreground service is running
              if (!isServiceRunning) {
                await TimerForegroundService.startTimer(_endTime!);
              }
            } else if (diff >= -30) {
              // Timer finished recently (within 30s) - show completion
              _onTimerComplete();
            } else {
              // Expired long ago; clear state silently to avoid blasting audio alarm
              await _silentlyClearTimer();
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading saved state: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _silentlyClearTimer() async {
    await NotificationService().cancelScheduledTimerNotification();
    await TimerForegroundService.stopTimer();
    _uiTimer?.cancel();
    _uiTimer = null;
    _endTime = null;
    await _saveEndTime(null);

    if (mounted) {
      setState(() {
        _isRunning = false;
        _isFinished = false;
      });
    }
  }

  int _getRemainingSeconds() {
    if (_endTime == null) return 0;
    final diff = _endTime!.difference(DateTime.now()).inSeconds;
    return diff > 0 ? diff : 0;
  }

  Future<void> _saveDuration(int minutes) async {
    await PreferencesManager().set<int>(_durationKey, minutes);
  }

  Future<void> _saveEndTime(DateTime? endTime) async {
    if (endTime != null) {
      await PreferencesManager()
          .set<String>(_endTimeKey, endTime.toIso8601String());
    } else {
      await PreferencesManager().remove(_endTimeKey);
    }
  }

  /// Starts the countdown timer with foreground service
  Future<void> _startTimer() async {
    if (_isRunning || _selectedMinutes <= 0) return;

    // Calculate end time
    _endTime = DateTime.now().add(Duration(minutes: _selectedMinutes));

    // Persist end time
    await _saveEndTime(_endTime);

    setState(() {
      _isRunning = true;
      _isFinished = false;
    });

    // 1. Schedule "Time's up" notification at exact endTime
    //    This fires even if app is killed!
    await NotificationService().scheduleTimerCompletionNotification(_endTime!);

    // 2. Start foreground service for live notification updates
    await TimerForegroundService.startTimer(_endTime!);

    // 3. Start UI timer for display updates
    _startUiTimer();
  }

  void _startUiTimer() {
    _uiTimer?.cancel();
    _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      final remaining = _getRemainingSeconds();
      if (remaining <= 0) {
        _onTimerComplete();
      } else {
        setState(() {}); // Refresh UI
      }
    });
  }

  /// Called when timer reaches zero
  Future<void> _onTimerComplete() async {
    // Cancel scheduled notification (may have already fired)
    await NotificationService().cancelScheduledTimerNotification();

    // Stop foreground service
    await TimerForegroundService.stopTimer();

    _uiTimer?.cancel();
    _uiTimer = null;
    _endTime = null;
    await _saveEndTime(null);

    setState(() {
      _isRunning = false;
      _isFinished = true;
    });

    // Play completion sound (offline asset first, URL fallback)
    _playCompletionSound();

    // Show notification if app is in foreground
    await NotificationService().showTimerNotification();
  }

  Future<void> _playCompletionSound() async {
    try {
      // Local bundled asset first (offline safe)
      await _audioPlayer?.play(AssetSource('sounds/timer_alarm.mp3'));
    } catch (e) {
      debugPrint('Error playing local sound asset: $e. Attempting network fallback...');
      try {
        await _audioPlayer?.play(
          UrlSource(
            'https://assets.mixkit.co/active_storage/sfx/2869/2869-preview.mp3',
          ),
        );
      } catch (err) {
        debugPrint('Error playing fallback sound: $err');
      }
    }
  }

  /// Stops the timer (user-initiated)
  Future<void> _stopTimer() async {
    // Cancel scheduled notification
    await NotificationService().cancelScheduledTimerNotification();

    // Stop foreground service
    await TimerForegroundService.stopTimer();

    _uiTimer?.cancel();
    _uiTimer = null;
    _endTime = null;
    await _saveEndTime(null);

    setState(() => _isRunning = false);
  }

  /// Resets the timer
  Future<void> _resetTimer() async {
    await _stopTimer();
    _audioPlayer?.stop();
    setState(() => _isFinished = false);
  }

  void _onDurationChanged(int value) {
    setState(() {
      _selectedMinutes = value;
      _isFinished = false;
    });
    _saveDuration(value);
  }

  String _formatTime(int totalSeconds) {
    final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final remainingSeconds = _isRunning ? _getRemainingSeconds() : 0;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Countdown Timer'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _DurationSelector(
                  selectedMinutes: _selectedMinutes,
                  minMinutes: _minMinutes,
                  maxMinutes: _maxMinutes,
                  enabled: !_isRunning,
                  onChanged: _onDurationChanged,
                ),
                const SizedBox(height: 40),
                _TimerDisplay(
                  formattedTime: _formatTime(remainingSeconds),
                  isFinished: _isFinished,
                ),
                const SizedBox(height: 40),
                _TimerControls(
                  isRunning: _isRunning,
                  onStart: _startTimer,
                  onStop: _stopTimer,
                  onReset: _resetTimer,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============ UI WIDGETS ============

class _DurationSelector extends StatelessWidget {
  final int selectedMinutes;
  final int minMinutes;
  final int maxMinutes;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const _DurationSelector({
    required this.selectedMinutes,
    required this.minMinutes,
    required this.maxMinutes,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          'Duration: $selectedMinutes ${selectedMinutes == 1 ? 'minute' : 'minutes'}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 16),
        Slider(
          value: selectedMinutes.toDouble(),
          min: minMinutes.toDouble(),
          max: maxMinutes.toDouble(),
          divisions: maxMinutes - minMinutes,
          label: '$selectedMinutes min',
          onChanged: enabled ? (value) => onChanged(value.round()) : null,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _QuickSelectButton(
              label: '1 min',
              onPressed: enabled ? () => onChanged(1) : null,
            ),
            _QuickSelectButton(
              label: '5 min',
              onPressed: enabled ? () => onChanged(5) : null,
            ),
            _QuickSelectButton(
              label: '10 min',
              onPressed: enabled ? () => onChanged(10) : null,
            ),
            _QuickSelectButton(
              label: '15 min',
              onPressed: enabled ? () => onChanged(15) : null,
            ),
          ],
        ),
      ],
    );
  }
}

class _QuickSelectButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;

  const _QuickSelectButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      child: Text(label),
    );
  }
}

class _TimerDisplay extends StatelessWidget {
  final String formattedTime;
  final bool isFinished;

  const _TimerDisplay({required this.formattedTime, required this.isFinished});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          formattedTime,
          style: TextStyle(
            fontSize: 72,
            fontWeight: FontWeight.bold,
            fontFamily: 'monospace',
            color: isFinished ? Colors.red : Theme.of(context).primaryColor,
          ),
        ),
        const SizedBox(height: 16),
        AnimatedOpacity(
          opacity: isFinished ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 300),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.shade300),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.alarm, color: Colors.red.shade700),
                const SizedBox(width: 8),
                Text(
                  "Time's up!",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TimerControls extends StatelessWidget {
  final bool isRunning;
  final VoidCallback onStart;
  final VoidCallback onStop;
  final VoidCallback onReset;

  const _TimerControls({
    required this.isRunning,
    required this.onStart,
    required this.onStop,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: 120,
          height: 50,
          child: ElevatedButton.icon(
            onPressed: isRunning ? onStop : onStart,
            icon: Icon(isRunning ? Icons.stop : Icons.play_arrow),
            label: Text(isRunning ? 'Stop' : 'Start'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isRunning ? Colors.orange : Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 16),
        SizedBox(
          width: 120,
          height: 50,
          child: OutlinedButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.refresh),
            label: const Text('Reset'),
          ),
        ),
      ],
    );
  }
}
