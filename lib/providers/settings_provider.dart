import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider extends ChangeNotifier {
  static const _multipleChoiceKey = 'isMultipleChoice';
  static const _timerEnabledKey = 'isTimerEnabled';
  static const _timerDurationKey = 'timerDurationSeconds';

  bool _isMultipleChoice = true;
  bool get isMultipleChoice => _isMultipleChoice;

  bool _isTimerEnabled = false;
  bool get isTimerEnabled => _isTimerEnabled;

  int _timerDurationSeconds = 10;
  int get timerDurationSeconds => _timerDurationSeconds;

  Future<void> load() async {
    final preferences = await SharedPreferences.getInstance();
    _isMultipleChoice = preferences.getBool(_multipleChoiceKey) ?? true;
    _isTimerEnabled = preferences.getBool(_timerEnabledKey) ?? false;
    _timerDurationSeconds = _normalizeDuration(
      preferences.getInt(_timerDurationKey) ?? 10,
    );
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

  int _normalizeDuration(int value) => value.clamp(5, 60);
}
