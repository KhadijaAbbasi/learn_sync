import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../models/course_join_request.dart';
import '../../models/course_model.dart';
import '../../widgets/dashboard_scaffold.dart';

class TeacherJoiningRequestsScreen extends StatelessWidget {
  const TeacherJoiningRequestsScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    final teacherId = user?.id ?? '';

    return ListenableBuilder(
      listenable: scope.courseStore,
      builder: (context, _) {
        final courses = scope.courseStore.courses;
        return DashboardScaffold(
          embeddedInShell: embeddedInShell,
          roleLabel: l10n.teacher,
          appBarTitle: l10n.joiningRequests,
          showAppBar: true,
          appBarCenterTitle: true,
          body: courses.isEmpty
              ? _Empty(text: l10n.noJoiningRequests)
              : Column(
                  children: [
                    for (final course in courses)
                      _CourseRequestsBlock(
                        course: course,
                        teacherId: teacherId,
                      ),
                  ],
                ),
        );
      },
    );
  }
}

class _CourseRequestsBlock extends StatelessWidget {
  const _CourseRequestsBlock({
    required this.course,
    required this.teacherId,
  });

  final CourseModel course;
  final String teacherId;

  @override
  Widget build(BuildContext context) {
    final enrollment = AppScope.of(context).enrollment;
    final brightness = Theme.of(context).brightness;

    return StreamBuilder<List<CourseJoinRequest>>(
      stream: enrollment.watchPendingForCourse(course.id),
      builder: (context, snapshot) {
        final requests = snapshot.data ?? const <CourseJoinRequest>[];
        if (requests.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                course.name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              if (course.code.isNotEmpty) ...[
                const SizedBox(height: 2),
                Text(
                  course.code,
                  style: TextStyle(
                    color: AppColors.textSecondary(brightness),
                    fontSize: 12,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              for (final request in requests)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _RequestCard(
                    request: request,
                    course: course,
                    teacherId: teacherId,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.request,
    required this.course,
    required this.teacherId,
  });

  final CourseJoinRequest request;
  final CourseModel course;
  final String teacherId;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard> {
  var _busy = false;

  Future<void> _respond(bool accept) async {
    if (_busy) return;
    final scope = AppScope.of(context);
    final l10n = AppLocalizations.of(context);
    setState(() => _busy = true);
    try {
      if (accept) {
        await scope.enrollment.accept(
          courseId: widget.course.id,
          teacherId: widget.teacherId,
          studentId: widget.request.studentId,
        );
      } else {
        await scope.enrollment.decline(
          courseId: widget.course.id,
          teacherId: widget.teacherId,
          studentId: widget.request.studentId,
        );
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            accept ? l10n.joinRequestAccepted : l10n.joinRequestRejected,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.joinRequestActionFailed)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final req = widget.request;
    final initial = req.studentName.trim().isNotEmpty
        ? req.studentName.trim()[0].toUpperCase()
        : '?';

    return Material(
      color: AppColors.fieldFill(brightness),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppColors.teal.withValues(alpha: 0.18),
                  child: Text(
                    initial,
                    style: const TextStyle(
                      color: AppColors.teal,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        req.studentName,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (req.memberId.isNotEmpty) req.memberId,
                          if (req.studentEmail.isNotEmpty) req.studentEmail,
                        ].join(' · '),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : () => _respond(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: const BorderSide(color: AppColors.error),
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(l10n.rejectJoinRequest),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : () => _respond(true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      minimumSize: const Size(0, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Text(l10n.acceptJoinRequest),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.fieldFill(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(color: AppColors.textSecondary(brightness)),
      ),
    );
  }
}