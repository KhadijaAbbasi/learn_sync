import 'package:learnsync/l10n/app_localizations.dart';

abstract final class Validators {
  static final _upper = RegExp(r'[A-Z]');
  static final _lower = RegExp(r'[a-z]');
  static final _digit = RegExp(r'[0-9]');
  static final _special = RegExp(r'[^A-Za-z0-9]');

  static String? memberId(String? value, AppLocalizations l10n) {
    final requiredError = requiredField(value, l10n);
    if (requiredError != null) {
      return requiredError;
    }
    final id = value!.trim();
    final valid = RegExp(r'^[A-Za-z0-9_-]{3,32}$').hasMatch(id);
    if (!valid) {
      return l10n.memberIdInvalid;
    }
    return null;
  }

  static String? requiredField(String? value, AppLocalizations l10n) {
    if (value == null || value.trim().isEmpty) {
      return l10n.requiredField;
    }
    return null;
  }

  static String? email(String? value, AppLocalizations l10n) {
    final requiredError = requiredField(value, l10n);
    if (requiredError != null) {
      return requiredError;
    }
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(value!.trim())) {
      return l10n.invalidEmail;
    }
    return null;
  }

  static String? emailOrUsername(String? value, AppLocalizations l10n) {
    return requiredField(value, l10n);
  }

  static String? password(String? value, AppLocalizations l10n) {
    final requiredError = requiredField(value, l10n);
    if (requiredError != null) {
      return requiredError;
    }
    final password = value!;
    final isStrong =
        password.length >= 8 &&
        _upper.hasMatch(password) &&
        _lower.hasMatch(password) &&
        _digit.hasMatch(password) &&
        _special.hasMatch(password);
    if (!isStrong) {
      return l10n.passwordRequirements;
    }
    return null;
  }

  static String? confirmPassword({
    required String? value,
    required String original,
    required AppLocalizations l10n,
  }) {
    final passwordError = password(value, l10n);
    if (passwordError != null) {
      return passwordError;
    }
    if (value != original) {
      return l10n.passwordsDoNotMatch;
    }
    return null;
  }

  static String? creditHours(String? value, AppLocalizations l10n) {
    final requiredError = requiredField(value, l10n);
    if (requiredError != null) {
      return requiredError;
    }
    final hours = int.tryParse(value!.trim());
    if (hours == null || hours < 1 || hours > 5) {
      return l10n.creditHoursInvalid;
    }
    return null;
  }

  /// True when the value looks like an email (contains @).
  static bool looksLikeEmail(String value) => value.trim().contains('@');

  /// Normalize a typed phone: strip spaces/dashes/parens; add leading + if
  /// the user typed 92… / 966… without it.
  static String normalizePhone(String value) {
    var s = value.trim().replaceAll(RegExp(r'[\s\-()]'), '');
    if (!s.startsWith('+') &&
        (s.startsWith('92') || s.startsWith('966'))) {
      s = '+$s';
    }
    return s;
  }

  /// Pakistan (+92 + 10 digits) or Saudi Arabia (+966 + 9 digits) only.
  static bool isSupportedPhone(String value) {
    final phone = normalizePhone(value);
    return RegExp(r'^\+92\d{10}$').hasMatch(phone) ||
        RegExp(r'^\+966\d{9}$').hasMatch(phone);
  }

  /// Signup/login contact: email OR PK/SA phone in E.164 (+92… / +966…).
  static String? emailOrSupportedPhone(String? value, AppLocalizations l10n) {
    final requiredError = requiredField(value, l10n);
    if (requiredError != null) {
      return requiredError;
    }
    final raw = value!.trim();
    if (looksLikeEmail(raw)) {
      return email(raw, l10n);
    }
    if (!isSupportedPhone(raw)) {
      return l10n.invalidEmailOrPhone;
    }
    return null;
  }

}
