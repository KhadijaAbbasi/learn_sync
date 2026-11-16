import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../core/constants/app_routes.dart';
import '../core/di/app_scope.dart';
import '../core/theme/app_colors.dart';
import '../models/user_role.dart';
import '../screens/student/student_ai_practices_screen.dart';
import '../screens/student/student_joined_courses_screen.dart';
import '../screens/student/student_shell.dart';
import '../screens/student/student_meetings_screen.dart';
import '../screens/teacher/teacher_analytics_screen.dart';
import '../screens/teacher/teacher_shell.dart';
import '../screens/teacher/teacher_meetings_screen.dart';
import 'app_wordmark.dart';
import 'circular_logo.dart';
import 'pending_join_requests_badge.dart';
import 'user_avatar.dart';

class AppSidebar extends StatelessWidget {
  const AppSidebar({super.key, this.onClose});

  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final radius = BorderRadiusDirectional.horizontal(
      end: const Radius.circular(28),
    ).resolve(Directionality.of(context));

    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.themeController,
        scope.localeController,
        scope.sessionController,
      ]),
      builder: (context, _) {
        final user = scope.sessionController.user;
        final name = user?.fullName ?? l10n.appName;
        final role = user == null
            ? ''
            : (scope.sessionController.isTeacher ? l10n.teacher : l10n.student);
        final routeName = ModalRoute.of(context)?.settings.name;

        return ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF102A4A),
                      AppColors.navy,
                      AppColors.navyDark,
                    ],
                  ),
                ),
                child: SizedBox.expand(),
              ),
              const Positioned.fill(
                child: CustomPaint(painter: _GlowPainter()),
              ),
              SafeArea(
                child: _SidebarScrollArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _BrandBlock(),
                        const SizedBox(height: 8),
                        Text(
                          l10n.appTagline,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.72),
                            fontSize: 12,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 28),
                        if (!scope.sessionController.isTeacher) ...[
                          _NavTile(
                            icon: Icons.menu_book_outlined,
                            label: l10n.navJoinedCourses,
                            selected:
                                StudentShellScope.maybeOf(context)?.index == 3,
                            onTap: () {
                              final shell = StudentShellScope.maybeOf(context);
                              onClose?.call();
                              if (shell != null) {
                                shell.goTo(3);
                                return;
                              }
                              final nav = Navigator.of(
                                context,
                                rootNavigator: true,
                              );
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!nav.mounted ||
                                    scope.sessionController.user == null) {
                                  return;
                                }
                                nav.push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const StudentJoinedCoursesScreen(),
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                        _NavTile(
                          icon: Icons.person_outline_rounded,
                          label: l10n.navProfile,
                          selected:
                              routeName == AppRoutes.profile ||
                              (StudentShellScope.maybeOf(context)?.index ==
                                  4) ||
                              (TeacherShellScope.maybeOf(context)?.index == 4),
                          onTap: () {
                            final studentShell = StudentShellScope.maybeOf(
                              context,
                            );
                            final teacherShell = TeacherShellScope.maybeOf(
                              context,
                            );
                            onClose?.call();
                            if (studentShell != null &&
                                !scope.sessionController.isTeacher) {
                              studentShell.goTo(4);
                              return;
                            }
                            if (teacherShell != null &&
                                scope.sessionController.isTeacher) {
                              teacherShell.goTo(4);
                              return;
                            }
                            final nav = Navigator.of(
                              context,
                              rootNavigator: true,
                            );
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!nav.mounted) {
                                return;
                              }
                              if (ModalRoute.of(nav.context)?.settings.name ==
                                  AppRoutes.profile) {
                                return;
                              }
                              nav.pushNamed(AppRoutes.profile);
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        _NavTile(
                          icon: Icons.home_outlined,
                          label: l10n.navDashboard,
                          selected: () {
                            final studentShell = StudentShellScope.maybeOf(
                              context,
                            );
                            final teacherShell = TeacherShellScope.maybeOf(
                              context,
                            );
                            if (studentShell != null &&
                                !scope.sessionController.isTeacher) {
                              return studentShell.index == 0;
                            }
                            if (teacherShell != null &&
                                scope.sessionController.isTeacher) {
                              return teacherShell.index == 0;
                            }
                            return routeName == AppRoutes.teacherDashboard ||
                                routeName == AppRoutes.studentDashboard;
                          }(),
                          onTap: () {
                            final studentShell = StudentShellScope.maybeOf(
                              context,
                            );
                            final teacherShell = TeacherShellScope.maybeOf(
                              context,
                            );
                            onClose?.call();
                            if (studentShell != null &&
                                !scope.sessionController.isTeacher) {
                              studentShell.goTo(0);
                              return;
                            }
                            if (teacherShell != null &&
                                scope.sessionController.isTeacher) {
                              teacherShell.goTo(0);
                              return;
                            }
                            final nav = Navigator.of(
                              context,
                              rootNavigator: true,
                            );
                            final user = scope.sessionController.user;
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!nav.mounted) {
                                return;
                              }
                              if (routeName == AppRoutes.teacherDashboard ||
                                  routeName == AppRoutes.studentDashboard) {
                                return;
                              }
                              if (user == null) {
                                return;
                              }
                              nav.pushNamedAndRemoveUntil(
                                user.role == UserRole.teacher
                                    ? AppRoutes.teacherDashboard
                                    : AppRoutes.studentDashboard,
                                (_) => false,
                              );
                            });
                          },
                        ),
                        if (scope.sessionController.isTeacher) ...[
                          const SizedBox(height: 6),
                          _NavTile(
                            icon: Icons.person_add_alt_1_outlined,
                            label: l10n.joiningRequests,
                            showPendingDot: true,
                            selected:
                                TeacherShellScope.maybeOf(context)?.index == 2,
                            onTap: () {
                              final shell = TeacherShellScope.maybeOf(context);
                              onClose?.call();
                              if (shell != null) {
                                shell.goTo(2);
                                return;
                              }
                            },
                          ),
                        ],
                        if (scope.sessionController.isTeacher) ...[
                          const SizedBox(height: 6),
                          _NavTile(
                            icon: Icons.insights_rounded,
                            label: l10n.teacherAnalytics,
                            selected:
                                TeacherShellScope.maybeOf(context)?.index == 3,
                            onTap: () {
                              final shell = TeacherShellScope.maybeOf(context);
                              onClose?.call();
                              if (shell != null) {
                                shell.goTo(3);
                                return;
                              }
                              final nav = Navigator.of(
                                context,
                                rootNavigator: true,
                              );
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!nav.mounted ||
                                    scope.sessionController.user == null) {
                                  return;
                                }
                                nav.push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const TeacherAnalyticsScreen(),
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                        if (!scope.sessionController.isTeacher) ...[
                          const SizedBox(height: 6),
                          _NavTile(
                            icon: Icons.smart_toy_outlined,
                            label: l10n.aiPractice,
                            selected:
                                StudentShellScope.maybeOf(context)?.index == 2,
                            onTap: () {
                              final shell = StudentShellScope.maybeOf(context);
                              onClose?.call();
                              if (shell != null) {
                                shell.goTo(2);
                                return;
                              }
                              final nav = Navigator.of(
                                context,
                                rootNavigator: true,
                              );
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!nav.mounted ||
                                    scope.sessionController.user == null) {
                                  return;
                                }
                                nav.push(
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        const StudentAiPracticesScreen(),
                                  ),
                                );
                              });
                            },
                          ),
                        ],
                        const SizedBox(height: 6),
                        _NavTile(
                          icon: Icons.event_available_outlined,
                          label: l10n.navMeetings,
                          selected:
                              StudentShellScope.maybeOf(context)?.index == 1 ||
                              TeacherShellScope.maybeOf(context)?.index == 1,
                          onTap: () {
                            final studentShell = StudentShellScope.maybeOf(
                              context,
                            );
                            final teacherShell = TeacherShellScope.maybeOf(
                              context,
                            );
                            final session = scope.sessionController;
                            onClose?.call();
                            if (studentShell != null && !session.isTeacher) {
                              studentShell.goTo(1);
                              return;
                            }
                            if (teacherShell != null && session.isTeacher) {
                              teacherShell.goTo(1);
                              return;
                            }
                            final nav = Navigator.of(
                              context,
                              rootNavigator: true,
                            );
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!nav.mounted || session.user == null) {
                                return;
                              }
                              nav.push(
                                MaterialPageRoute<void>(
                                  builder: (_) => session.isTeacher
                                      ? const TeacherMeetingsScreen()
                                      : const StudentMeetingsScreen(),
                                ),
                              );
                            });
                          },
                        ),
                        const SizedBox(height: 6),
                        _NavTile(
                          icon: Icons.settings_outlined,
                          label: l10n.navSettings,
                          selected: routeName == AppRoutes.settings,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: Colors.white,
                          ),
                          onTap: () {
                            final nav = Navigator.of(
                              context,
                              rootNavigator: true,
                            );
                            onClose?.call();
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              if (!nav.mounted ||
                                  routeName == AppRoutes.settings) {
                                return;
                              }
                              nav.pushNamed(AppRoutes.settings);
                            });
                          },
                        ),
                        const Spacer(),
                        Divider(
                          color: Colors.white.withValues(alpha: 0.12),
                          height: 32,
                        ),
                        _ProfileRow(
                          name: name,
                          role: role,
                          photoUrl: user?.photoUrl ?? '',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SidebarScrollArea extends StatelessWidget {
  const _SidebarScrollArea({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: IntrinsicHeight(child: child),
        ),
      ),
    );
  }
}

class _BrandBlock extends StatelessWidget {
  const _BrandBlock();

  @override
  Widget build(BuildContext context) {
    return const Column(
      children: [
        CircularLogo(size: 64),
        SizedBox(height: 14),
        AppWordmark(fontSize: 22),
      ],
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.selected = false,
    this.showPendingDot = false,
    this.trailing,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final bool showPendingDot;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal : Colors.transparent,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              showPendingDot
                  ? PendingJoinRequestsBadge(
                      child: Icon(icon, size: 22, color: Colors.white),
                    )
                  : Icon(icon, size: 22, color: Colors.white),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 14.5,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.name,
    required this.role,
    required this.photoUrl,
  });

  final String name;
  final String role;
  final String photoUrl;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        UserAvatar(
          name: name,
          photoUrl: photoUrl,
          radius: 20,
          backgroundColor: const Color(0xFF163352),
          foregroundColor: Colors.white,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              if (role.isNotEmpty)
                Text(
                  role,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 12,
                  ),
                ),
            ],
          ),
        ),
        const Icon(Icons.verified_rounded, color: AppColors.teal, size: 18),
      ],
    );
  }
}

class _GlowPainter extends CustomPainter {
  const _GlowPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = AppColors.teal.withValues(alpha: 0.18);
    final center = Offset(size.width * 0.82, size.height * 0.9);
    for (final radius in [48.0, 86.0, 124.0, 162.0]) {
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
