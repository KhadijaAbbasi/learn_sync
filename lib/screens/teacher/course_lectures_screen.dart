import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/course_model.dart';
import '../../models/lecture_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import 'lecture_analytics_screen.dart';

class CourseLecturesScreen extends StatelessWidget {
  const CourseLecturesScreen({super.key, required this.course});

  final CourseModel course;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user?.role != UserRole.teacher) {
      return Scaffold(
        appBar: AppBar(centerTitle: true, title: Text(l10n.lectureAnalytics)),
        body: Center(child: Text(l10n.authUnknown)),
      );
    }

    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final locale = Localizations.localeOf(context).toString();

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        centerTitle: true,
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        title: Text(l10n.courseLecturesTitle),
      ),
      body: StreamBuilder<List<LectureModel>>(
        stream: scope.courseStore.watchCourseLectures(
          courseId: course.id,
          teacherId: user!.id,
        ),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Text(l10n.analyticsLoadFailed),
              ),
            );
          }
          if (snapshot.connectionState == ConnectionState.waiting &&
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lectures = snapshot.data ?? const [];
          if (lectures.isEmpty) {
            return Padding(
              padding: EdgeInsets.all(padding),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.analytics_outlined,
                        size: 48,
                        color: AppColors.teal.withValues(alpha: 0.85),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        l10n.courseLecturesEmpty,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.textSecondary(brightness),
                          height: 1.4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }

          return ListView.separated(
            padding: EdgeInsets.fromLTRB(padding, 20, padding, 32),
            itemCount: lectures.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final lecture = lectures[index];
              return _LectureRow(
                lecture: lecture,
                dateLabel: _dateLabel(lecture, locale),
                timeLabel: _timeLabel(lecture, locale),
                completed: lecture.status == LectureStatus.ended,
                completedLabel: l10n.completedStatus,
                liveLabel: l10n.liveNow,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LectureAnalyticsScreen(
                        lecture: lecture,
                        course: course,
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _dateLabel(LectureModel lecture, String locale) {
    final date = lecture.endedAt ?? lecture.startedAt;
    if (date != null) {
      return DateFormat.yMMMd(locale).format(date);
    }
    if (lecture.lectureDate.trim().isNotEmpty) {
      return lecture.lectureDate.trim();
    }
    return '—';
  }

  String? _timeLabel(LectureModel lecture, String locale) {
    final started = lecture.startedAt;
    final ended =
        lecture.endedAt ??
        started?.add(Duration(minutes: lecture.durationMinutes));
    if (started == null) {
      return null;
    }
    if (ended == null) {
      return DateFormat.jm(locale).format(started);
    }
    return '${DateFormat.jm(locale).format(started)} - ${DateFormat.jm(locale).format(ended)}';
  }
}

class _LectureRow extends StatelessWidget {
  const _LectureRow({
    required this.lecture,
    required this.dateLabel,
    required this.timeLabel,
    required this.completed,
    required this.completedLabel,
    required this.liveLabel,
    required this.onTap,
  });

  final LectureModel lecture;
  final String dateLabel;
  final String? timeLabel;
  final bool completed;
  final String completedLabel;
  final String liveLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final title = lecture.topicTitle.trim().isNotEmpty
        ? lecture.topicTitle.trim()
        : lecture.chapterTitle.trim();
    final subtitle = [
      if (lecture.chapterTitle.trim().isNotEmpty &&
          lecture.topicTitle.trim().isNotEmpty)
        lecture.chapterTitle.trim(),
      dateLabel,
      ?timeLabel,
    ].join(' · ');

    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border(brightness)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.isEmpty ? lecture.courseName : title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: (completed ? AppColors.teal : AppColors.coral)
                          .withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      completed ? completedLabel : liveLabel,
                      style: TextStyle(
                        color: completed ? AppColors.teal : AppColors.coral,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
