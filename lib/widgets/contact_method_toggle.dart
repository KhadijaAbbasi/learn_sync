import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';
import '../models/contact_method.dart';

/// Small segmented control letting the user pick Email or Phone.
/// Brand-new widget — does not alter any existing screen's old layout,
/// it is only inserted where explicitly added.
class ContactMethodToggle extends StatelessWidget {
  const ContactMethodToggle({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ContactMethod value;
  final ValueChanged<ContactMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          _segment(
            context: context,
            label: l10n.emailAddress,
            icon: Icons.mail_outline_rounded,
            selected: value == ContactMethod.email,
            onTap: () => onChanged(ContactMethod.email),
          ),
          _segment(
            context: context,
            label: l10n.phoneNumber,
            icon: Icons.phone_outlined,
            selected: value == ContactMethod.phone,
            onTap: () => onChanged(ContactMethod.phone),
          ),
        ],
      ),
    );
  }

  Widget _segment({
    required BuildContext context,
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: selected
                    ? theme.colorScheme.onPrimary
                    : theme.colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: selected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
