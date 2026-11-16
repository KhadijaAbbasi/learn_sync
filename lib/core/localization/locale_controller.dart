import 'package:flutter/material.dart';

class LocaleController extends ChangeNotifier {
  LocaleController({this._locale = const Locale('en')});

  Locale _locale;

  Locale get locale => _locale;

  bool get isArabic => _locale.languageCode == 'ar';

  void setLocale(Locale nextLocale) {
    if (_locale == nextLocale) {
      return;
    }
    _locale = nextLocale;
    notifyListeners();
  }

  void toggle() {
    setLocale(isArabic ? const Locale('en') : const Locale('ar'));
  }
}
