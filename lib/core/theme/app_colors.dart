import 'package:flutter/material.dart';

abstract final class AppColors {
  static const Color navy = Color(0xFF0B2545);
  static const Color headerNavy = Color(0xFF163E66);
  static const Color navyDark = Color(0xFF071A32);
  static const Color teal = Color(0xFF1A9B9A);
  static const Color tealDark = Color(0xFF157F7E);
  static const Color gold = Color(0xFFE6A817);
  static const Color coral = Color(0xFFE06A4A);
  static const Color error = Color(0xFFC62828);

  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFF7F9FC);
  static const Color pageWash = Color(0xFFF4F7FB);
  static const Color lightBorder = Color(0xFFD7DEE8);
  static const Color lightText = Color(0xFF0B2545);
  static const Color lightMuted = Color(0xFF7A8699);

  static const Color darkBackground = Color(0xFF08111C);
  static const Color darkSurface = Color(0xFF122033);
  static const Color darkBorder = Color(0xFF2A3B52);
  static const Color darkText = Color(0xFFF3F6FA);
  static const Color darkMuted = Color(0xFF9AA8BA);
  static const Color darkNavyButton = Color(0xFF3D6BB3);

  static Color background(Brightness brightness) {
    return brightness == Brightness.dark ? darkBackground : lightBackground;
  }

  static Color fieldFill(Brightness brightness) {
    return brightness == Brightness.dark ? darkSurface : lightBackground;
  }

  static Color border(Brightness brightness) {
    return brightness == Brightness.dark ? darkBorder : lightBorder;
  }

  static Color textPrimary(Brightness brightness) {
    return brightness == Brightness.dark ? darkText : lightText;
  }

  static Color textSecondary(Brightness brightness) {
    return brightness == Brightness.dark ? darkMuted : lightMuted;
  }

  static Color loginButton(Brightness brightness) {
    return brightness == Brightness.dark ? darkNavyButton : navy;
  }

  static Color signupButton(Brightness _) => teal;
}
