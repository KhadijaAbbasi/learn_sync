import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static const _simplifiedArabic = 'Simplified Arabic';

  static ThemeData light({Locale locale = const Locale('en')}) => _build(
    brightness: Brightness.light,
    locale: locale,
    scheme: const ColorScheme.light(
      primary: AppColors.navy,
      secondary: AppColors.teal,
      surface: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      error: AppColors.error,
    ),
    scaffold: AppColors.lightSurface,
    fill: AppColors.lightBackground,
    hint: AppColors.lightMuted,
    border: AppColors.lightBorder,
    text: AppColors.lightText,
  );

  static ThemeData dark({Locale locale = const Locale('en')}) => _build(
    brightness: Brightness.dark,
    locale: locale,
    scheme: const ColorScheme.dark(
      primary: AppColors.teal,
      secondary: AppColors.gold,
      surface: AppColors.darkBackground,
      onSurface: AppColors.darkText,
      error: Color(0xFFFF8A80),
    ),
    scaffold: AppColors.darkBackground,
    fill: AppColors.darkSurface,
    hint: AppColors.darkMuted,
    border: AppColors.darkBorder,
    text: AppColors.darkText,
  );

  static TextTheme textThemeFor(Locale locale, Brightness brightness) {
    final base = ThemeData(brightness: brightness).textTheme;
    final color = brightness == Brightness.dark
        ? AppColors.darkText
        : AppColors.lightText;
    if (locale.languageCode == 'ar') {
      GoogleFonts.notoNaskhArabic();
      return base.apply(
        fontFamily: _simplifiedArabic,
        bodyColor: color,
        displayColor: color,
      );
    }
    return GoogleFonts.interTextTheme(base).apply(
      bodyColor: color,
      displayColor: color,
    );
  }

  static String? _fontFamily(Locale locale) {
    return locale.languageCode == 'ar'
        ? _simplifiedArabic
        : GoogleFonts.inter().fontFamily;
  }

  static List<String>? _fontFallback(Locale locale) {
    if (locale.languageCode != 'ar') {
      return null;
    }
    return [
      GoogleFonts.notoNaskhArabic().fontFamily ?? 'Noto Naskh Arabic',
      'Tahoma',
    ];
  }

  static ThemeData _build({
    required Brightness brightness,
    required Locale locale,
    required ColorScheme scheme,
    required Color scaffold,
    required Color fill,
    required Color hint,
    required Color border,
    required Color text,
  }) {
    final textTheme = textThemeFor(locale, brightness);
    final family = _fontFamily(locale);
    final base = ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      fontFamily: family,
      fontFamilyFallback: _fontFallback(locale),
      textTheme: textTheme,
    );

    return base.copyWith(
      scaffoldBackgroundColor: scaffold,
      appBarTheme: AppBarTheme(
        titleTextStyle: textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontSize: 17,
          fontWeight: FontWeight.w700,
          fontFamily: family,
        ),
        toolbarTextStyle: textTheme.bodyMedium?.copyWith(
          color: Colors.white,
          fontFamily: family,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            fontFamily: family,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          textStyle: textTheme.labelLarge?.copyWith(fontFamily: family),
        ),
      ),
      chipTheme: ChipThemeData(
        labelStyle: textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w600,
          fontFamily: family,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: fill,
        hintStyle: TextStyle(color: hint),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        prefixIconColor: hint,
        suffixIconColor: hint,
        border: _outline(border),
        enabledBorder: _outline(border),
        focusedBorder: _outline(AppColors.teal, width: 1.6),
        errorBorder: _outline(scheme.error),
        focusedErrorBorder: _outline(scheme.error, width: 1.6),
      ),
    );
  }

  static OutlineInputBorder _outline(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}
