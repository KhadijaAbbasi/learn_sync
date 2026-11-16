import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/auth_navigation.dart';
import '../../widgets/dashboard_scaffold.dart';
import 'profile_settings_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _confirmDelete(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.deleteAccount),
          content: Text(l10n.deleteAccountConfirm),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancel),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(foregroundColor: AppColors.coral),
              child: Text(l10n.deleteAccount),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    try {
      await AppScope.of(context).authService.deleteAccount();
      if (!context.mounted) {
        return;
      }
      await openLogin(context);
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileSaveFailed)),
      );
    }
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    final isArabic = scope.localeController.isArabic;
    final chosen = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(l10n.english),
                trailing: isArabic ? null : const Icon(Icons.check_rounded),
                onTap: () => Navigator.pop(context, false),
              ),
              ListTile(
                title: Text(l10n.arabic),
                trailing: isArabic ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(context, true),
              ),
            ],
          ),
        );
      },
    );
    if (chosen == null) return;
    scope.localeController.setLocale(Locale(chosen ? 'ar' : 'en'));
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);

    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.themeController,
        scope.localeController,
      ]),
      builder: (context, _) {
        final l10n = AppLocalizations.of(context);
        final brightness = Theme.of(context).brightness;
        final isDark = scope.themeController.isDark(context);
        final isArabic = scope.localeController.isArabic;

        return DashboardScaffold(
          roleLabel: l10n.navSettings,
          appBarTitle: l10n.navSettings,
          appBarBackButton: true,
          appBarCenterTitle: true,
          appBarActions: [
            IconButton(
              tooltip: l10n.logout,
              onPressed: () => confirmLogout(context),
              icon: const Icon(Icons.logout_rounded),
            ),
          ],
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SectionLabel(text: l10n.appearance, brightness: brightness),
              const SizedBox(height: 8),
              _SettingsCard(
                brightness: brightness,
                child: _ThemeRow(
                  title: l10n.theme,
                  isDark: isDark,
                  lightLabel: l10n.lightTheme,
                  darkLabel: l10n.darkOption,
                  onLight: () =>
                      scope.themeController.setMode(ThemeMode.light),
                  onDark: () =>
                      scope.themeController.setMode(ThemeMode.dark),
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel(
                text: isArabic ? 'التفضيلات' : 'Preferences',
                brightness: brightness,
              ),
              const SizedBox(height: 8),
              _SettingsCard(
                brightness: brightness,
                child: _NavRow(
                  icon: Icons.language_rounded,
                  iconBg: const Color(0xFFE3F0FF),
                  iconColor: AppColors.headerNavy,
                  title: l10n.language,
                  trailingText: isArabic ? l10n.arabic : l10n.english,
                  brightness: brightness,
                  onTap: () => _pickLanguage(context),
                ),
              ),
              const SizedBox(height: 22),
              _SectionLabel(
                text: isArabic ? 'الحساب' : 'Account',
                brightness: brightness,
              ),
              const SizedBox(height: 8),
              _SettingsCard(
                brightness: brightness,
                child: _NavRow(
                  icon: Icons.person_outline_rounded,
                  iconBg: const Color(0xFFEDE7FF),
                  iconColor: const Color(0xFF6B5B95),
                  title: '${l10n.editItem} ${l10n.navProfile}',
                  brightness: brightness,
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const ProfileSettingsScreen(
                          initialEditing: true,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 28),
              _DeleteAccountButton(
                label: l10n.deleteAccount,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.brightness});

  final String text;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: AppColors.textSecondary(brightness),
        fontSize: 13,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  const _SettingsCard({
    required this.brightness,
    required this.child,
  });

  final Brightness brightness;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: brightness == Brightness.dark ? AppColors.darkSurface : Colors.white,
      elevation: 0,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        child: child,
      ),
    );
  }
}

class _ThemeRow extends StatelessWidget {
  const _ThemeRow({
    required this.title,
    required this.isDark,
    required this.lightLabel,
    required this.darkLabel,
    required this.onLight,
    required this.onDark,
  });

  final String title;
  final bool isDark;
  final String lightLabel;
  final String darkLabel;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      child: Row(
        children: [
          _IconBadge(
            icon: Icons.wb_sunny_outlined,
            bg: const Color(0xFFFFE8D6),
            color: AppColors.coral,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: AppColors.textPrimary(brightness),
                fontWeight: FontWeight.w700,
                fontSize: 15.5,
              ),
            ),
          ),
          _ThemeSegment(
            lightLabel: lightLabel,
            darkLabel: darkLabel,
            isDark: isDark,
            onLight: onLight,
            onDark: onDark,
          ),
        ],
      ),
    );
  }
}

class _ThemeSegment extends StatelessWidget {
  const _ThemeSegment({
    required this.lightLabel,
    required this.darkLabel,
    required this.isDark,
    required this.onLight,
    required this.onDark,
  });

  final String lightLabel;
  final String darkLabel;
  final bool isDark;
  final VoidCallback onLight;
  final VoidCallback onDark;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final track = brightness == Brightness.dark
        ? AppColors.darkBackground
        : const Color(0xFFEEF2F7);

    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: track,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SegChip(
            label: lightLabel,
            selected: !isDark,
            onTap: onLight,
          ),
          _SegChip(
            label: darkLabel,
            selected: isDark,
            onTap: onDark,
          ),
        ],
      ),
    );
  }
}

class _SegChip extends StatelessWidget {
  const _SegChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.navy : Colors.transparent,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: selected
                  ? Colors.white
                  : AppColors.textSecondary(Theme.of(context).brightness),
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavRow extends StatelessWidget {
  const _NavRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.brightness,
    required this.onTap,
    this.trailingText,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String? trailingText;
  final Brightness brightness;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
        child: Row(
          children: [
            _IconBadge(icon: icon, bg: iconBg, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: AppColors.textPrimary(brightness),
                  fontWeight: FontWeight.w700,
                  fontSize: 15.5,
                ),
              ),
            ),
            if (trailingText != null) ...[
              Text(
                trailingText!,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 2),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textSecondary(brightness),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({
    required this.icon,
    required this.bg,
    required this.color,
  });

  final IconData icon;
  final Color bg;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: isDark ? color.withValues(alpha: 0.18) : bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, color: isDark ? color : color, size: 22),
    );
  }
}

class _DeleteAccountButton extends StatelessWidget {
  const _DeleteAccountButton({
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.coral,
        side: const BorderSide(color: AppColors.coral, width: 1.4),
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      icon: const Icon(Icons.delete_outline_rounded),
      label: Text(
        label,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
      ),
    );
  }
}
