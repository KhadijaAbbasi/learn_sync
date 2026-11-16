import 'package:flutter/material.dart';

class ThemeController extends ChangeNotifier {
  ThemeController({this._mode = ThemeMode.system});

  ThemeMode _mode;

  ThemeMode get mode => _mode;

  bool isDark(BuildContext context) {
    switch (_mode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return MediaQuery.platformBrightnessOf(context) == Brightness.dark;
    }
  }

  void setMode(ThemeMode mode) {
    if (_mode == mode) {
      return;
    }
    _mode = mode;
    notifyListeners();
  }

  void toggle(BuildContext context) {
    setMode(isDark(context) ? ThemeMode.light : ThemeMode.dark);
  }
}
