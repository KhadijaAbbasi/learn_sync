import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/course_model.dart';
import '../../models/lecture_model.dart';
import '../../models/meeting_request.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import 'teacher_meetings_screen.dart';

class LectureMeetingsHubScreen extends StatelessWidget {
  const LectureMeetingsHubScreen({
    super.key,
    required this.lecture,
    required this.course,
  });

  final LectureModel lecture;
  final CourseModel course;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user?.role != UserRole.teacher) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.lectureMeetingsHubTitle)),
        body: Center(child: Text(l10n.authUnknown)),
      );
    }

    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final topic = lecture.topicTitle.trim().isEmpty
        ? lecture.chapterTitle
        : lecture.topicTitle;

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(l10n.lectureMeetingsHubTitle),
      ),
      body: StreamBuilder<List<MeetingRequest>>(
        stream: scope.meetingStore.watchTeacherRequests(user!.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final meetings = [
            for (final item in snapshot.data ?? const <MeetingRequest>[])
              if (meetingMatchesLecture(
                item,
                courseId: lecture.courseId,
                lectureId: lecture.id,
                topicId: lecture.topicId,
                topicTitle: lecture.topicTitle,
              ))
                item,
          ];
          final pending = meetings.where((item) => item.needsTeacherAction).length;
          final scheduled = meetings.where((item) => item.isAccepted).length;
          final attended = meetings.where((item) => item.isCompleted).length;

          return ListView(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            children: [
              Text(
                topic,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              if (course.name.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  course.name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.teal,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                l10n.lectureMeetingsHubSubtitle,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _HubCard(
                icon: Icons.hourglass_empty_rounded,
                title: l10n.pendingRequests,
                count: pending,
                color: AppColors.gold,
                onTap: () => _openList(
                  context,
                  TeacherMeetingListFilter.pending,
                ),
              ),
              const SizedBox(height: 10),
              _HubCard(
                icon: Icons.event_available_rounded,
                title: l10n.scheduledMeetings,
                count: scheduled,
                color: AppColors.teal,
                onTap: () => _openList(
                  context,
                  TeacherMeetingListFilter.scheduled,
                ),
              ),
              const SizedBox(height: 10),
              _HubCard(
                icon: Icons.check_circle_outline_rounded,
                title: l10n.attendedMeetings,
                count: attended,
                color: AppColors.navy,
                onTap: () => _openList(
                  context,
                  TeacherMeetingListFilter.attended,
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _openList(BuildContext context, TeacherMeetingListFilter filter) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TeacherMeetingsScreen(
          lectureId: lecture.id,
          courseId: lecture.courseId,
          topicId: lecture.topicId,
          topicTitle: lecture.topicTitle,
          filter: filter,
        ),
      ),
    );
  }
}

class _HubCard extends StatelessWidget {
  const _HubCard({
    required this.icon,
    required this.title,
    required this.count,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final int count;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(icon, color: color),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$count',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
            ],
          ),
        ),
      ),
    );
  }
}
