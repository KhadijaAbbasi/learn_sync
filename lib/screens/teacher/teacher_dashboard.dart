import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course_model.dart';
import '../../widgets/course_card.dart';
import '../../widgets/dashboard_home_header.dart';
import '../../widgets/dashboard_scaffold.dart';
import '../../widgets/responsive_card_list.dart';
import '../common/course_detail_screen.dart';

class TeacherDashboard extends StatefulWidget {
  const TeacherDashboard({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<TeacherDashboard> createState() => _TeacherDashboardState();
}

class _TeacherDashboardState extends State<TeacherDashboard> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final next = _searchController.text.trim().toLowerCase();
    if (next == _query) {
      return;
    }
    setState(() => _query = next);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  List<CourseModel> _filtered(List<CourseModel> courses) {
    final query = _query;
    if (query.isEmpty) {
      return courses;
    }
    return courses.where((course) {
      return course.name.toLowerCase().contains(query) ||
          course.code.toLowerCase().contains(query) ||
          course.department.toLowerCase().contains(query);
    }).toList();
  }

  String _courseSubtitle(
    String code,
    String department,
    AppLocalizations l10n,
  ) {
    final parts = <String>[
      if (code.isNotEmpty) code,
      if (department.isNotEmpty) department,
    ];
    return parts.isEmpty ? l10n.topicsCount(0) : parts.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final brightness = Theme.of(context).brightness;

    return ListenableBuilder(
      listenable: Listenable.merge([
        scope.courseStore,
        scope.sessionController,
      ]),
      builder: (context, _) {
        final user = scope.sessionController.user;
        final name = user?.fullName ?? l10n.teacher;
        final courses = _filtered(scope.courseStore.courses);

        return DashboardScaffold(
          embeddedInShell: widget.embeddedInShell,
          roleLabel: l10n.teacher,
          showAppBar: false,
          header: DashboardHomeHeader(
            showMenuButton: !widget.embeddedInShell,
            userName: name,
            roleLabel: l10n.teacher,
            photoUrl: user?.photoUrl ?? '',
            subtitle: l10n.keepTeachingAhead,
            overlay: DashboardOverlayCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.yourCourses,
                    style: TextStyle(
                      color: AppColors.textPrimary(brightness),
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 18),
                  DashboardSearchField(
                    controller: _searchController,
                    hintText: l10n.searchCoursesHint,
                    onChanged: (_) => _onSearchChanged(),
                  ),
                ],
              ),
            ),
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l10n.addCourse,
            backgroundColor: AppColors.teal,
            foregroundColor: Colors.white,
            elevation: 3,
            onPressed: () =>
                Navigator.of(context).pushNamed(AppRoutes.addCourse),
            child: const Icon(Icons.add_rounded, size: 28),
          ),
          body: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 36),
              if (scope.courseStore.courses.isEmpty)
                _EmptyNote(text: l10n.noCoursesTeacher)
              else if (courses.isEmpty)
                _EmptyNote(text: l10n.noCoursesTeacher)
              else
                ResponsiveCardList(
                  children: courses
                      .map(
                        (course) => CourseCard(
                          course: course,
                          subtitle: _courseSubtitle(
                            course.code,
                            course.department,
                            l10n,
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    CourseDetailScreen(course: course),
                              ),
                            );
                          },
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Text(
        text,
        style: TextStyle(color: AppColors.textSecondary(brightness)),
      ),
    );
  }
}
