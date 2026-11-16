import 'package:flutter/material.dart';

import '../core/di/app_scope.dart';
import '../core/theme/app_colors.dart';

class LanguageToggle extends StatelessWidget {
  const LanguageToggle({super.key, this.onDark = true});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).localeController;
    final isArabic = controller.isArabic;

    return _HeaderChip(
      onDark: onDark,
      onTap: controller.toggle,
      child: Text(isArabic ? 'EN' : 'عربي'),
    );
  }
}

class ThemeToggle extends StatelessWidget {
  const ThemeToggle({super.key, this.onDark = true});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final controller = AppScope.of(context).themeController;
    final isDark = controller.isDark(context);

    return _HeaderChip(
      onDark: onDark,
      onTap: () => controller.toggle(context),
      child: Icon(
        isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
        size: 18,
        color: onDark
            ? Colors.white
            : AppColors.textPrimary(Theme.of(context).brightness),
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({
    required this.onTap,
    required this.child,
    this.onDark = true,
  });

  final VoidCallback onTap;
  final Widget child;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: onDark
          ? Colors.white.withValues(alpha: 0.16)
          : AppColors.border(Theme.of(context).brightness).withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: DefaultTextStyle(
            style: TextStyle(
              color: onDark
                  ? Colors.white
                  : AppColors.textPrimary(Theme.of(context).brightness),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
