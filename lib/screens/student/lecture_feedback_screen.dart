import 'dart:async';
import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/lecture_ordinal.dart';
import '../../models/live_session_model.dart';
import 'create_meeting_screen.dart';
import 'ai_practice_screen.dart';

class LectureFeedbackScreen extends StatefulWidget {
  const LectureFeedbackScreen({
    super.key,
    required this.session,
    required this.courseName,
    this.courseCode = '',
    this.department = '',
    this.teacherName = '',
  });

  final LiveSessionModel session;
  final String courseName;
  final String courseCode;
  final String department;
  final String teacherName;

  @override
  State<LectureFeedbackScreen> createState() => _LectureFeedbackScreenState();
}

class _LectureFeedbackScreenState extends State<LectureFeedbackScreen> {
  var _openedEnd = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _openedEnd) {
        return;
      }
      _openedEnd = true;
      unawaited(_showLectureEnd());
    });
  }

  String _lectureTitle(AppLocalizations l10n) {
    final chapter = widget.session.chapterTitle.trim();
    final topic = widget.session.topicTitle.trim();
    if (chapter.isNotEmpty && topic.isNotEmpty) {
      return '$chapter: $topic';
    }
    return topic.isNotEmpty ? topic : l10n.lectureEndTitle;
  }

  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.studentDashboard, (_) => false);
  }

  Future<void> _showLectureEnd() async {
    final choice = await showDialog<_FeedbackNextStep>(
      context: context,
      barrierDismissible: false,
      builder: (context) => _FeedbackSubmittedDialog(
        session: widget.session,
        topicTitle: widget.session.topicTitle,
        teacherName: widget.teacherName,
      ),
    );
    if (!mounted) {
      return;
    }
    switch (choice) {
      case _FeedbackNextStep.practice:
        final user = AppScope.of(context).sessionController.user;
        final store = AppScope.of(context).courseStore;
        final ended = await store
            .watchEndedSessionsForTopic(
              courseId: widget.session.courseId,
              chapterId: widget.session.chapterId,
              topicId: widget.session.topicId,
            )
            .first;
        if (!mounted) {
          return;
        }
        final ordinal = lectureOrdinalForTopic(
          session: widget.session,
          endedForTopic: ended,
        );
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => AiPracticeScreen(
              session: widget.session,
              courseName: widget.courseName,
              studentId: user?.id ?? '',
              studentName: user?.fullName ?? '',
              lectureOrdinal: ordinal,
            ),
          ),
        );
      case _FeedbackNextStep.meeting:
        await Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => CreateMeetingScreen(
              initialCourseId: widget.session.courseId,
              initialTopicTitle: widget.session.topicTitle,
            ),
          ),
        );
      case _FeedbackNextStep.later:
      case null:
        _goHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        title: StreamBuilder<List<LiveSessionModel>>(
          stream: AppScope.of(context).courseStore.watchEndedSessionsForTopic(
            courseId: widget.session.courseId,
            chapterId: widget.session.chapterId,
            topicId: widget.session.topicId,
          ),
          builder: (context, endedSnap) {
            final ended = endedSnap.data;
            final title = ended == null
                ? l10n.lectureEndTitle
                : l10n.lectureEndTitleNumbered(
                    lectureOrdinalForTopic(
                      session: widget.session,
                      endedForTopic: ended,
                    ),
                  );
            return Text(title);
          },
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l10n.endedBadge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: Text(
          _lectureTitle(l10n),
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary(brightness)),
        ),
      ),
    );
  }
}

enum _FeedbackNextStep { practice, meeting, later }

class _FeedbackSubmittedDialog extends StatelessWidget {
  const _FeedbackSubmittedDialog({
    required this.session,
    required this.topicTitle,
    required this.teacherName,
  });

  final LiveSessionModel session;
  final String topicTitle;
  final String teacherName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final store = AppScope.of(context).courseStore;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 22),
      child: StreamBuilder<List<LiveSessionModel>>(
        stream: store.watchEndedSessionsForTopic(
          courseId: session.courseId,
          chapterId: session.chapterId,
          topicId: session.topicId,
        ),
        builder: (context, endedSnap) {
          final ended = endedSnap.data;
          final ordinal = ended == null
              ? null
              : lectureOrdinalForTopic(
                  session: session,
                  endedForTopic: ended,
                );
          final endTitle = ordinal == null
              ? l10n.lectureEndTitle
              : l10n.lectureEndTitleNumbered(ordinal);
          final practiceTitle = ordinal == null
              ? l10n.practiceWithAiTitle
              : l10n.practiceWithAiTitleNumbered(ordinal);

          return Padding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  endTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.lectureEndSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AppColors.textSecondary(brightness),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 16),
                _NextStepCard(
                  icon: Icons.smart_toy_outlined,
                  title: practiceTitle,
                  subtitle: l10n.practiceWithAiHint(
                    topicTitle.trim().isEmpty
                        ? l10n.meetingTopicLabel
                        : topicTitle,
                  ),
                  highlighted: false,
                  onTap: () =>
                      Navigator.of(context).pop(_FeedbackNextStep.practice),
                ),
                const SizedBox(height: 10),
                _NextStepCard(
                  icon: Icons.event_available_rounded,
                  title: l10n.scheduleMeetingTitle,
                  subtitle: l10n.scheduleMeetingHint(
                    teacherName.trim().isEmpty ? l10n.teacher : teacherName,
                  ),
                  highlighted: true,
                  onTap: () =>
                      Navigator.of(context).pop(_FeedbackNextStep.meeting),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () =>
                      Navigator.of(context).pop(_FeedbackNextStep.later),
                  child: Text(
                    l10n.maybeLater,
                    style: TextStyle(
                      decoration: TextDecoration.underline,
                      color: AppColors.textSecondary(brightness),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.highlighted,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: highlighted
          ? AppColors.teal.withValues(alpha: 0.10)
          : (brightness == Brightness.dark
                ? AppColors.darkBackground
                : const Color(0xFFF4F6FA)),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: highlighted
                  ? AppColors.teal.withValues(alpha: 0.55)
                  : AppColors.border(brightness),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AppColors.teal,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary(brightness),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary(brightness),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

