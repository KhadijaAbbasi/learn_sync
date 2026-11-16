import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/app_sidebar.dart';
import '../../widgets/pending_join_requests_badge.dart';
import '../common/profile_settings_screen.dart';
import 'teacher_analytics_screen.dart';
import 'teacher_dashboard.dart';
import 'teacher_joining_requests_screen.dart';
import 'teacher_meetings_screen.dart';

/// Owns teacher root navigation: Home, Meetings, Joining, Analytics, Profile.
class TeacherShellController extends ChangeNotifier {
  TeacherShellController([int initialIndex = 0])
      : _index = initialIndex.clamp(0, 4);

  int _index;
  int get index => _index;

  void goTo(int value) {
    final next = value.clamp(0, 4);
    if (_index == next) {
      return;
    }
    _index = next;
    notifyListeners();
  }
}

class TeacherShellScope extends InheritedNotifier<TeacherShellController> {
  const TeacherShellScope({
    super.key,
    required TeacherShellController controller,
    required super.child,
  }) : super(notifier: controller);

  static TeacherShellController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<TeacherShellScope>()
        ?.notifier;
  }

  static TeacherShellController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'TeacherShellScope not found');
    return controller!;
  }
}

class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  late final TeacherShellController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TeacherShellController(widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Bottom bar: Meetings · Joining · Home · Analytics · Profile
  int _barIndexForShell(int shellIndex) {
    switch (shellIndex) {
      case 1:
        return 0;
      case 2:
        return 1;
      case 0:
        return 2;
      case 3:
        return 3;
      case 4:
        return 4;
      default:
        return 2;
    }
  }

  void _onBarSelected(int barIndex) {
    switch (barIndex) {
      case 0:
        _controller.goTo(1);
      case 1:
        _controller.goTo(2);
      case 2:
        _controller.goTo(0);
      case 3:
        _controller.goTo(3);
      case 4:
        _controller.goTo(4);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final desktop = AppResponsive.isDesktop(context);
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final pageColor =
        isDark ? AppColors.darkBackground : AppColors.lightSurface;
    final barColor = isDark ? AppColors.darkSurface : AppColors.lightBackground;
    final barBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final pages = const <Widget>[
      TeacherDashboard(embeddedInShell: true),
      TeacherMeetingsScreen(embeddedInShell: true),
      TeacherJoiningRequestsScreen(embeddedInShell: true),
      TeacherAnalyticsScreen(embeddedInShell: true),
      ProfileSettingsScreen(embeddedInShell: true),
    ];

    return TeacherShellScope(
      controller: _controller,
      child: ListenableBuilder(
        listenable: _controller,
        builder: (context, _) {
          final body = IndexedStack(
            index: _controller.index,
            children: pages,
          );

          final navBar = NavigationBar(
            height: 62,
            elevation: 0,
            backgroundColor: barColor,
            indicatorColor: AppColors.teal.withValues(alpha: 0.18),
            labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
            selectedIndex: _barIndexForShell(_controller.index),
            onDestinationSelected: _onBarSelected,
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.event_available_outlined),
                selectedIcon: const Icon(Icons.event_available_rounded),
                label: l10n.navMeetings,
              ),
              NavigationDestination(
                icon: const PendingJoinRequestsBadge(
                  child: Icon(Icons.person_add_alt_1_outlined),
                ),
                selectedIcon: const PendingJoinRequestsBadge(
                  child: Icon(Icons.person_add_alt_1_rounded),
                ),
                label: l10n.joiningRequests,
              ),
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l10n.navDashboard,
              ),
              NavigationDestination(
                icon: const Icon(Icons.insights_rounded),
                selectedIcon: const Icon(Icons.insights_rounded),
                label: l10n.teacherAnalytics,
              ),
              NavigationDestination(
                icon: const Icon(Icons.person_outline_rounded),
                selectedIcon: const Icon(Icons.person_rounded),
                label: l10n.navProfile,
              ),
            ],
          );

          if (desktop) {
            return ColoredBox(
              color: AppColors.navyDark,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(
                    width: 268,
                    child: Material(
                      color: Colors.transparent,
                      child: AppSidebar(),
                    ),
                  ),
                  Expanded(
                    child: ColoredBox(
                      color: pageColor,
                      child: body,
                    ),
                  ),
                ],
              ),
            );
          }

          return Scaffold(
            backgroundColor: pageColor,
            body: body,
            bottomNavigationBar: DecoratedBox(
              decoration: BoxDecoration(
                color: barColor,
                border: Border(top: BorderSide(color: barBorder, width: 1)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: navBar,
              ),
            ),
          );
        },
      ),
    );
  }
}