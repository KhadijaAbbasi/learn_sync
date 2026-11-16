import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../widgets/app_sidebar.dart';
import '../common/profile_settings_screen.dart';
import 'student_ai_practices_screen.dart';
import 'student_dashboard.dart';
import 'student_joined_courses_screen.dart';
import 'student_meetings_screen.dart';

/// Owns student root navigation: Home, Meetings, Practice, Joined Courses, Profile.
class StudentShellController extends ChangeNotifier {
  StudentShellController([int initialIndex = 0])
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

class StudentShellScope extends InheritedNotifier<StudentShellController> {
  const StudentShellScope({
    super.key,
    required StudentShellController controller,
    required super.child,
  }) : super(notifier: controller);

  static StudentShellController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<StudentShellScope>()
        ?.notifier;
  }

  static StudentShellController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'StudentShellScope not found');
    return controller!;
  }
}

class StudentShell extends StatefulWidget {
  const StudentShell({super.key, this.initialIndex = 0});

  final int initialIndex;

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  late final StudentShellController _controller;

  @override
  void initState() {
    super.initState();
    _controller = StudentShellController(widget.initialIndex);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Bottom bar order: Meetings · Practice · Home · Joined Courses · Profile
  /// Home stays in the middle.
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
    final pageColor = isDark ? AppColors.darkBackground : AppColors.lightSurface;
    // Contrast vs page: light = pure white + border; dark = elevated surface.
    final barColor = isDark ? AppColors.darkSurface : AppColors.lightBackground;
    final barBorder = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    final pages = const <Widget>[
      StudentDashboard(),
      StudentMeetingsScreen(embeddedInShell: true),
      StudentAiPracticesScreen(embeddedInShell: true),
      StudentJoinedCoursesScreen(embeddedInShell: true),
      ProfileSettingsScreen(embeddedInShell: true),
    ];

    return StudentShellScope(
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
                icon: const Icon(Icons.smart_toy_outlined),
                selectedIcon: const Icon(Icons.smart_toy_rounded),
                label: l10n.aiPractice,
              ),
              NavigationDestination(
                icon: const Icon(Icons.home_outlined),
                selectedIcon: const Icon(Icons.home_rounded),
                label: l10n.navDashboard,
              ),
              NavigationDestination(
                icon: const Icon(Icons.menu_book_outlined),
                selectedIcon: const Icon(Icons.menu_book_rounded),
                label: l10n.navJoinedCourses,
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