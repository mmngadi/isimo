import 'package:isimo/isimo.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A [StorageEngine] adapter backed by `SharedPreferencesAsync`.
///
/// Used by isimo's `persist` to hydrate and save the todo list.
class SharedPrefsStorage implements StorageEngine {
  SharedPrefsStorage(this._prefs);

  final SharedPreferencesAsync _prefs;

  @override
  Future<String?> getItem(String key) => _prefs.getString(key);

  @override
  Future<void> setItem(String key, String value) =>
      _prefs.setString(key, value);

  @override
  Future<void> removeItem(String key) => _prefs.remove(key);
}