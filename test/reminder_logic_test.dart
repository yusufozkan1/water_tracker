import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Reminder Scheduling Logic Tests', () {
    List<int> calculateReminderSlotMinutes({
      required int startHour,
      required int endHour,
      required int intervalMinutes,
    }) {
      if (intervalMinutes <= 0 || startHour >= endHour) return [];

      final List<int> slots = [];
      int current = startHour * 60;
      final end = endHour * 60;

      while (current <= end) {
        slots.add(current);
        current += intervalMinutes;
      }
      return slots;
    }

    test('generates expected time slots between 8 AM and 10 PM every 2 hours', () {
      final slots = calculateReminderSlotMinutes(
        startHour: 8,
        endHour: 22,
        intervalMinutes: 120, // every 2 hours
      );

      // 8:00, 10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00 -> 8 slots
      expect(slots.length, 8);
      expect(slots.first, 8 * 60); // 08:00
      expect(slots.last, 22 * 60); // 22:00
    });

    test('generates expected time slots for 90 minute intervals', () {
      final slots = calculateReminderSlotMinutes(
        startHour: 9,
        endHour: 15, // 6 hours = 360 mins
        intervalMinutes: 90,
      );

      // 9:00 (540), 10:30 (630), 12:00 (720), 13:30 (810), 15:00 (900) -> 5 slots
      expect(slots.length, 5);
      expect(slots, [540, 630, 720, 810, 900]);
    });

    test('handles invalid bounds gracefully', () {
      expect(
        calculateReminderSlotMinutes(
          startHour: 20,
          endHour: 8,
          intervalMinutes: 60,
        ),
        isEmpty,
      );
      expect(
        calculateReminderSlotMinutes(
          startHour: 8,
          endHour: 20,
          intervalMinutes: 0,
        ),
        isEmpty,
      );
    });
  });
}
