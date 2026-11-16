import 'package:flutter/material.dart';

import '../core/theme/app_colors.dart';
import '../core/utils/responsive.dart';
import 'app_back_button.dart';
import 'app_sidebar.dart';
import 'app_wordmark.dart';
import 'circular_logo.dart';

class DashboardScaffold extends StatelessWidget {
  const DashboardScaffold({
    super.key,
    required this.roleLabel,
    required this.body,
    this.floatingActionButton,
    this.showAppBar = true,
    this.header,
    this.appBarTitle,
    this.appBarActions,
    this.appBarBackButton = false,
    this.appBarCenterTitle = false,
    this.embeddedInShell = false,
  });

  final String roleLabel;
  final Widget body;
  final Widget? floatingActionButton;
  final bool showAppBar;
  final Widget? header;
  final String? appBarTitle;
  final List<Widget>? appBarActions;
  final bool appBarBackButton;
  final bool appBarCenterTitle;
  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final padding = AppResponsive.pagePadding(context);
    final desktop = AppResponsive.isDesktop(context);
    final maxWidth = desktop ? 1280.0 : 640.0;
    final brightness = Theme.of(context).brightness;
    final pageColor = brightness == Brightness.dark
        ? AppColors.darkBackground
        : AppColors.lightSurface;

    final scrolled = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(
            padding,
            header == null ? 20 : 24,
            padding,
            100,
          ),
          child: body,
        ),
      ),
    );

    final page = desktop && header != null
        ? SingleChildScrollView(
            child: Column(
              children: [
                header!,
                Align(
                  alignment: Alignment.topCenter,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(padding, 24, padding, 100),
                      child: body,
                    ),
                  ),
                ),
              ],
            ),
          )
        : header == null
        ? scrolled
        : Column(
            children: [
              header!,
              Expanded(child: scrolled),
            ],
          );

    final appBar = showAppBar
        ? AppBar(
            backgroundColor: AppColors.headerNavy,
            foregroundColor: Colors.white,
            elevation: 0,
            toolbarHeight: 64,
            centerTitle: appBarCenterTitle,
            titleSpacing: desktop ? 16 : 0,
            automaticallyImplyLeading: false,
            leading: appBarBackButton
                ? const AppBackButton()
                : (desktop || embeddedInShell)
                ? null
                : Builder(builder: (context) => const AppMenuButton()),
            title: Semantics(
              label: roleLabel,
              child: appBarTitle == null
                  ? const Row(
                      children: [
                        CircularLogo(size: 40),
                        SizedBox(width: 8),
                        AppWordmark(),
                      ],
                    )
                  : Text(
                      appBarTitle!,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
            actions: appBarActions,
          )
        : null;

    if (desktop && !embeddedInShell) {
      return ColoredBox(
        color: AppColors.navyDark,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(
              width: 268,
              child: Material(color: Colors.transparent, child: AppSidebar()),
            ),
            Expanded(
              child: Scaffold(
                backgroundColor: pageColor,
                appBar: appBar,
                floatingActionButton: floatingActionButton,
                body: page,
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: pageColor,
      appBar: appBar,
      drawer: embeddedInShell
          ? null
          : Drawer(
              width: 286,
              backgroundColor: Colors.transparent,
              elevation: 0,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadiusDirectional.horizontal(
                  end: Radius.circular(28),
                ),
              ),
              child: Builder(
                builder: (drawerContext) {
                  return AppSidebar(
                    onClose: () => Navigator.of(drawerContext).pop(),
                  );
                },
              ),
            ),
      floatingActionButton: floatingActionButton,
      body: page,
    );
  }
}
