import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:water_tracker/services/preferences_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    PreferencesManager().clearCache();
    await PreferencesManager().init();
  });

  group('PreferencesManager Unit Tests', () {
    test('stores and retrieves integers with cache', () async {
      final manager = PreferencesManager();

      final initial = await manager.get<int>('test_int', 42);
      expect(initial, 42);

      await manager.set<int>('test_int', 100);

      // Verify cached value
      expect(manager.getCached<int>('test_int'), 100);

      // Verify persistent read
      final saved = await manager.get<int>('test_int');
      expect(saved, 100);
    });

    test('stores and retrieves strings with cache', () async {
      final manager = PreferencesManager();

      await manager.set<String>('last_tracked_date', '2026-10-26');
      expect(manager.getCached<String>('last_tracked_date'), '2026-10-26');

      final readValue = await manager.get<String>('last_tracked_date');
      expect(readValue, '2026-10-26');
    });

    test('removes key and invalidates cache', () async {
      final manager = PreferencesManager();

      await manager.set<String>('temp_key', 'temporary');
      expect(await manager.containsKey('temp_key'), isTrue);

      await manager.remove('temp_key');

      expect(manager.getCached<String>('temp_key'), isNull);
      expect(await manager.containsKey('temp_key'), isFalse);
      expect(await manager.get<String>('temp_key'), isNull);
    });

    test('correctly returns default value for absent keys', () async {
      final manager = PreferencesManager();

      final val = await manager.get<int>('absent_key', 3000);
      expect(val, 3000);
    });
  });
}
