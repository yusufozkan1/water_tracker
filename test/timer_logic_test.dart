import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Timer Logic & Formatting Tests', () {
    String formatTime(int totalSeconds) {
      final minutes = (totalSeconds ~/ 60).toString().padLeft(2, '0');
      final seconds = (totalSeconds % 60).toString().padLeft(2, '0');
      return '$minutes:$seconds';
    }

    test('formatTime formats seconds into MM:SS correctly', () {
      expect(formatTime(0), '00:00');
      expect(formatTime(9), '00:09');
      expect(formatTime(60), '01:00');
      expect(formatTime(75), '01:15');
      expect(formatTime(3599), '59:59');
      expect(formatTime(300), '05:00');
    });

    test('stale alarm threshold logic correctly classifies expired timers', () {
      bool shouldTriggerAlarm(int diffInSeconds) {
        if (diffInSeconds <= 0 && diffInSeconds >= -30) {
          return true; // Recently finished (within 30 seconds)
        }
        return false;
      }

      // Expired 5 seconds ago -> should trigger
      expect(shouldTriggerAlarm(-5), isTrue);

      // Expired 30 seconds ago -> should trigger
      expect(shouldTriggerAlarm(-30), isTrue);

      // Expired 31 seconds ago -> considered stale / missed
      expect(shouldTriggerAlarm(-31), isFalse);

      // Expired 2 hours ago -> considered stale / missed
      expect(shouldTriggerAlarm(-7200), isFalse);

      // Timer still running (e.g. 10s left) -> not completed yet
      expect(shouldTriggerAlarm(10), isFalse);
    });

    test('daily intake progress calculation clamps between 0.0 and 1.0', () {
      double calculateProgress(int intake, int goal) {
        return (goal > 0) ? (intake / goal).clamp(0.0, 1.0) : 0.0;
      }

      expect(calculateProgress(0, 3000), 0.0);
      expect(calculateProgress(1500, 3000), 0.5);
      expect(calculateProgress(3000, 3000), 1.0);
      expect(calculateProgress(4500, 3000), 1.0); // Clamped to 1.0
      expect(calculateProgress(500, 0), 0.0); // Zero goal edge case
    });
  });
}
