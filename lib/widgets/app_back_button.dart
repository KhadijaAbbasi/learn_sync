import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/utils/auth_navigation.dart';

class AppBackButton extends StatelessWidget {
  const AppBackButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: l10n.goBack,
      color: color,
      onPressed: () {
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        } else {
          openLogin(context);
        }
      },
      icon: const Icon(Icons.arrow_back_rounded),
    );
  }
}

class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key, this.color = Colors.white});

  final Color color;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);

    return IconButton(
      tooltip: l10n.openMenu,
      color: color,
      onPressed: () => Scaffold.of(context).openDrawer(),
      icon: const Icon(Icons.menu_rounded),
    );
  }
}
