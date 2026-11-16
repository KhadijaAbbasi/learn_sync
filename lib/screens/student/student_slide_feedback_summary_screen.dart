import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/lecture_ordinal.dart';
import '../../models/live_session_model.dart';
import '../../models/live_slide_signal.dart';
import '../teacher/understanding_level_style.dart';
import 'lecture_feedback_screen.dart';

/// After a live lecture ends: list this student's per-slide signals, then
/// [Next] opens the existing Lecture End chooser ([LectureFeedbackScreen]).
class StudentSlideFeedbackSummaryScreen extends StatelessWidget {
  const StudentSlideFeedbackSummaryScreen({
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

  void _openLectureEnd(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LectureFeedbackScreen(
          session: session,
          courseName: courseName,
          courseCode: courseCode,
          department: department,
          teacherName: teacherName,
        ),
      ),
    );
  }

  String _slideLabel(AppLocalizations l10n, LiveSlideSignal signal) {
    final page = signal.slidePage < 1 ? 1 : signal.slidePage;
    return l10n.liveSlideOnPage(page);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final user = AppScope.of(context).sessionController.user;
    final store = AppScope.of(context).courseStore;

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        automaticallyImplyLeading: false,
        title: StreamBuilder<List<LiveSessionModel>>(
          stream: store.watchEndedSessionsForTopic(
            courseId: session.courseId,
            chapterId: session.chapterId,
            topicId: session.topicId,
          ),
          builder: (context, endedSnap) {
            final ended = endedSnap.data;
            final title = ended == null
                ? l10n.studentSlideFeedbackSummaryTitle
                : l10n.studentSlideFeedbackSummaryTitleNumbered(
                    lectureOrdinalForTopic(
                      session: session,
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
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<LiveSlideSignal>>(
              stream: store.watchStudentLiveSlideSignals(
                courseId: session.courseId,
                sessionId: session.id,
                studentId: user?.id ?? '',
              ),
              builder: (context, snap) {
                final signals = snap.data ?? const <LiveSlideSignal>[];
                if (snap.connectionState == ConnectionState.waiting &&
                    !snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (signals.isEmpty) {
                  return _EmptyState(message: l10n.studentSlideFeedbackEmpty);
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                  itemCount: signals.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Text(
                        l10n.studentSlideFeedbackSummarySubtitle,
                        style: TextStyle(
                          color: AppColors.textSecondary(brightness),
                          height: 1.35,
                        ),
                      );
                    }
                    final signal = signals[index - 1];
                    final visual = understandingLevelVisual(l10n, signal.level);
                    return _SlideFeedbackTile(
                      slideLabel: _slideLabel(l10n, signal),
                      levelLabel: visual.percent,
                      levelHint: visual.hint,
                      color: visual.color,
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => _openLectureEnd(context),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  l10n.studentSlideFeedbackNext,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.slideshow_outlined,
              size: 48,
              color: AppColors.textSecondary(brightness),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary(brightness),
                height: 1.4,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlideFeedbackTile extends StatelessWidget {
  const _SlideFeedbackTile({
    required this.slideLabel,
    required this.levelLabel,
    required this.levelHint,
    required this.color,
  });

  final String slideLabel;
  final String levelLabel;
  final String levelHint;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.image_outlined, color: color, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slideLabel,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    levelHint,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                levelLabel,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
