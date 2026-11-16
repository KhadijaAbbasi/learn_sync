import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import 'app_back_button.dart';
import 'app_wordmark.dart';
import 'circular_logo.dart';
import 'user_avatar.dart';

class DashboardHomeHeader extends StatelessWidget {
  const DashboardHomeHeader({
    super.key,
    required this.userName,
    required this.roleLabel,
    required this.subtitle,
    required this.overlay,
    this.photoUrl = '',
    this.appBarActions = const [],
    this.showMenuButton = true,
  });

  final String userName;
  final String roleLabel;
  final String subtitle;
  final Widget overlay;
  final String photoUrl;
  final List<Widget> appBarActions;
  final bool showMenuButton;

  @override
  Widget build(BuildContext context) {
    final padding = AppResponsive.pagePadding(context);
    final desktop = AppResponsive.isDesktop(context);
    final top = MediaQuery.paddingOf(context).top;
    final l10n = AppLocalizations.of(context);
    final name = userName.trim();
    final role = roleLabel.trim();
    final greetWithName =
        name.isNotEmpty && name.toLowerCase() != role.toLowerCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: EdgeInsets.fromLTRB(padding, top + 4, padding, 118),
          decoration: const BoxDecoration(color: AppColors.headerNavy),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    if (!desktop && showMenuButton) const AppMenuButton(),
                    const CircularLogo(size: 40),
                    const SizedBox(width: 8),
                    const AppWordmark(fontSize: 18),
                    const Spacer(),
                    ...appBarActions,
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          greetWithName
                              ? '${l10n.welcomeBackName(name)} 👋'
                              : l10n.welcomeBack,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: desktop ? 24 : 20,
                            height: 1.25,
                          ),
                        ),
                        if (role.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          _RoleTag(label: role),
                        ],
                        const SizedBox(height: 4),
                        Text(
                          subtitle,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  _HeaderAvatar(name: userName, photoUrl: photoUrl),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
        Positioned(
          left: padding,
          right: padding,
          bottom: -22,
          child: overlay,
        ),
      ],
    );
  }
}

class DashboardOverlayCard extends StatelessWidget {
  const DashboardOverlayCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 10,
      shadowColor: Colors.black.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(22),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: child,
      ),
    );
  }
}

class DashboardSearchField extends StatelessWidget {
  const DashboardSearchField({
    super.key,
    required this.controller,
    required this.hintText,
    this.onSubmitted,
    this.onSearch,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onSearch;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return TextField(
      controller: controller,
      textInputAction: TextInputAction.search,
      onSubmitted: onSubmitted,
      onChanged: onChanged,
      style: TextStyle(
        color: AppColors.textPrimary(brightness),
        fontSize: 14.5,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        prefixIcon: onSearch == null
            ? const Icon(Icons.search_rounded)
            : IconButton(
                onPressed: onSearch,
                icon: const Icon(Icons.search_rounded),
              ),
        filled: true,
        fillColor: brightness == Brightness.dark
            ? AppColors.darkBackground
            : const Color(0xFFF4F6FA),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(color: AppColors.border(brightness)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: const BorderSide(color: AppColors.teal, width: 1.4),
        ),
      ),
    );
  }
}

class _RoleTag extends StatelessWidget {
  const _RoleTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withValues(alpha: 0.38)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

class _HeaderAvatar extends StatelessWidget {
  const _HeaderAvatar({required this.name, required this.photoUrl});

  final String name;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return UserAvatar(
      name: name,
      photoUrl: photoUrl,
      radius: 26,
      backgroundColor: Colors.white,
      foregroundColor: AppColors.teal,
    );
  }
}
