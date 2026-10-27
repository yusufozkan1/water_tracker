import 'package:shared_preferences/shared_preferences.dart';
import 'package:synchronized/synchronized.dart';

class PreferencesManager {
  // Singleton: Uygulama boyunca tek bir yönetici olsun (Bellek Tasarrufu)
  static final PreferencesManager _instance = PreferencesManager._internal();
  factory PreferencesManager() => _instance;
  PreferencesManager._internal();

  SharedPreferences? _prefs;
  final _lock = Lock(); // Trafik Polisi

  // In-memory cache for frequently accessed values
  final Map<String, dynamic> _cache = {};

  // Başlatma (Lazy Loading)
  Future<void> init() async {
    if (_prefs != null) return;

    // Aynı anda 10 yerden çağrılsa bile sıraya sokar (Race Condition Önleyici)
    await _lock.synchronized(() async {
      _prefs ??= await SharedPreferences.getInstance();
    });
  }

  // --- GENERIC OKUMA (Tip Güvenli + Cache) ---
  Future<T?> get<T>(String key, [T? defaultValue]) async {
    // Check cache first
    if (_cache.containsKey(key)) {
      return _cache[key] as T? ?? defaultValue;
    }

    await init();
    return _lock.synchronized(() {
      T? value;
      if (T == int) {
        value = _prefs?.getInt(key) as T?;
      } else if (T == bool) {
        value = _prefs?.getBool(key) as T?;
      } else if (T == String) {
        value = _prefs?.getString(key) as T?;
      } else if (T == double) {
        value = _prefs?.getDouble(key) as T?;
      }

      // Cache the result
      if (value != null) {
        _cache[key] = value;
      }

      return value ?? defaultValue;
    });
  }

  // --- GENERIC YAZMA (Asenkron & Güvenli + Cache Invalidation) ---
  Future<bool> set<T>(String key, T value) async {
    await init();
    return _lock.synchronized(() async {
      if (_prefs == null) return false;

      bool result = false;
      if (value is int) {
        result = await _prefs!.setInt(key, value);
      } else if (value is bool) {
        result = await _prefs!.setBool(key, value);
      } else if (value is String) {
        result = await _prefs!.setString(key, value);
      } else if (value is double) {
        result = await _prefs!.setDouble(key, value);
      }

      // Update cache on successful write
      if (result) {
        _cache[key] = value;
      }

      return result;
    });
  }

  // Synchronous cache read - use after initial load for faster UI updates
  T? getCached<T>(String key, [T? defaultValue]) {
    return _cache[key] as T? ?? defaultValue;
  }

  // Clear cache (useful for testing or logout)
  void clearCache() => _cache.clear();

  // Clear cache and underlying storage (useful for testing)
  Future<void> clearAll() async {
    _cache.clear();
    await init();
    await _lock.synchronized(() async {
      await _prefs?.clear();
    });
  }

  // Reset instance for testing
  void resetForTesting() {
    _cache.clear();
    _prefs = null;
  }

  // --- KEY REMOVAL (Asenkron & Güvenli + Cache Invalidation) ---
  Future<bool> remove(String key) async {
    await init();
    return _lock.synchronized(() async {
      _cache.remove(key);
      if (_prefs == null) return false;
      return await _prefs!.remove(key);
    });
  }

  // --- KEY EXISTENCE CHECK ---
  Future<bool> containsKey(String key) async {
    await init();
    return _lock.synchronized(() {
      if (_cache.containsKey(key)) return true;
      return _prefs?.containsKey(key) ?? false;
    });
  }
}
