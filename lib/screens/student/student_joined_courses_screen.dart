import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/course_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/course_card.dart';
import '../common/course_detail_screen.dart';

/// Lists courses the student has already joined (live membership).
class StudentJoinedCoursesScreen extends StatefulWidget {
  const StudentJoinedCoursesScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<StudentJoinedCoursesScreen> createState() =>
      _StudentJoinedCoursesScreenState();
}

class _StudentJoinedCoursesScreenState extends State<StudentJoinedCoursesScreen> {
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    final teacherId = user?.connectedTeacherId ?? '';
    if (user?.role == UserRole.student && teacherId.isNotEmpty) {
      scope.courseStore.watchTeacher(teacherId);
    }
  }

  String _subtitle(CourseModel course, AppLocalizations l10n) {
    final parts = <String>[
      if (course.code.isNotEmpty) course.code,
      if (course.department.isNotEmpty) course.department,
    ];
    return parts.isEmpty
        ? l10n.topicsCount(course.topicCount)
        : parts.join(' · ');
  }

  void _openCourse(CourseModel course) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CourseDetailScreen(
          course: course,
          canDelete: false,
          isMember: true,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);

    if (user?.role != UserRole.student) {
      return Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(l10n.navJoinedCourses)),
        body: Center(child: Text(l10n.authUnknown)),
      );
    }

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: widget.embeddedInShell ? null : const AppBackButton(),
        automaticallyImplyLeading: !widget.embeddedInShell,
        title: Text(l10n.navJoinedCourses),
      ),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          scope.sessionController,
          scope.courseStore,
        ]),
        builder: (context, _) {
          final studentId = user!.id;
          final hasLink = scope.sessionController.hasTeacherLink &&
              (user.connectedTeacherId ?? '').isNotEmpty;
          final courses = scope.courseStore.courses;

          if (!hasLink) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: _EmptyNote(text: l10n.noCoursesStudent),
            );
          }

          return StreamBuilder<List<CourseModel>>(
            key: ValueKey(
              '${user.connectedTeacherId}|${courses.map((c) => c.id).join(',')}',
            ),
            stream: scope.enrollment.watchJoinedFromCandidates(
              studentId: studentId,
              candidates: courses,
            ),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final joined = snapshot.data ?? const <CourseModel>[];
              if (joined.isEmpty) {
                return Padding(
                  padding: EdgeInsets.all(padding),
                  child: _EmptyNote(text: l10n.noJoinedCoursesYet),
                );
              }
              return ListView.separated(
                padding: EdgeInsets.fromLTRB(padding, 20, padding, 24),
                itemCount: joined.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final course = joined[index];
                  return CourseCard(
                    course: course,
                    subtitle: _subtitle(course, l10n),
                    joinTag: CourseJoinTag.joined,
                    joinedLabel: l10n.courseJoinedTag,
                    onTap: () => _openCourse(course),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _EmptyNote extends StatelessWidget {
  const _EmptyNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary(brightness),
          fontSize: 15,
          height: 1.4,
        ),
      ),
    );
  }
}
