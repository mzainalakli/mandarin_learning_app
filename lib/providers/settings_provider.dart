import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const minSessionSize = 1;
  static const maxSessionSize = 1000;
  static const defaultSessionSize = 20;
  static const minTimerSeconds = 5;
  static const maxTimerSeconds = 60;

  static const _multipleChoiceKey = 'isMultipleChoice';
  static const _timerEnabledKey = 'isTimerEnabled';
  static const _timerDurationKey = 'timerDurationSeconds';
  static const _sessionSizeKey = 'sessionSize';
  static const _noLimitStored = 0;

  bool _isMultipleChoice = true;
  bool get isMultipleChoice => _isMultipleChoice;

  bool _isTimerEnabled = false;
  bool get isTimerEnabled => _isTimerEnabled;

  int _timerDurationSeconds = 10;
  int get timerDurationSeconds => _timerDurationSeconds;

  int? _sessionSize = defaultSessionSize;

  /// Number of questions per session, or `null` for "no limit".
  int? get sessionSize => _sessionSize;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _isMultipleChoice = preferences.getBool(_multipleChoiceKey) ?? true;
    _isTimerEnabled = preferences.getBool(_timerEnabledKey) ?? false;
    _timerDurationSeconds = _normalizeDuration(
      preferences.getInt(_timerDurationKey) ?? 10,
    );
    final storedSize = preferences.getInt(_sessionSizeKey);
    _sessionSize = storedSize == null
        ? defaultSessionSize
        : storedSize == _noLimitStored
        ? null
        : _normalizeSessionSize(storedSize);
    notifyListeners();
  }

  Future<void> setMultipleChoice(bool value) async {
    _isMultipleChoice = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_multipleChoiceKey, value);
  }

  Future<void> setTimerEnabled(bool value) async {
    _isTimerEnabled = value;
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(_timerEnabledKey, value);
  }

  Future<void> setTimerDurationSeconds(int value) async {
    _timerDurationSeconds = _normalizeDuration(value);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_timerDurationKey, _timerDurationSeconds);
  }

  /// Sets the questions per session; `null` means no limit.
  Future<void> setSessionSize(int? value) async {
    _sessionSize = value == null ? null : _normalizeSessionSize(value);
    notifyListeners();
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_sessionSizeKey, _sessionSize ?? _noLimitStored);
  }

  int _normalizeDuration(int value) =>
      value.clamp(minTimerSeconds, maxTimerSeconds);

  int _normalizeSessionSize(int value) =>
      value.clamp(minSessionSize, maxSessionSize);
}
