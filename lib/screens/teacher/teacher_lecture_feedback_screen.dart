import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/constants/app_routes.dart';
import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/ai_practice.dart';
import '../../models/lecture_feedback.dart';
import '../../models/lecture_model.dart';
import '../../models/live_session_model.dart';
import '../../models/meeting_request.dart';
import '../../widgets/custom_button.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../common/profile_settings_screen.dart';
import '../teacher/teacher_meetings_screen.dart';

class TeacherLectureFeedbackScreen extends StatefulWidget {
  const TeacherLectureFeedbackScreen({
    super.key,
    required this.session,
    required this.courseName,
    this.courseCode = '',
    this.department = '',
    this.semester = '',
    this.teacherId = '',
  });

  final LiveSessionModel session;
  final String courseName;
  final String courseCode;
  final String department;
  final String semester;
  final String teacherId;

  @override
  State<TeacherLectureFeedbackScreen> createState() =>
      _TeacherLectureFeedbackScreenState();
}

class _TeacherLectureFeedbackScreenState
    extends State<TeacherLectureFeedbackScreen> {
  Stream<List<LectureFeedback>>? _feedbackStream;
  Stream<List<LectureAttendee>>? _attendeesStream;
  Stream<List<MeetingRequest>>? _meetingsStream;
  Stream<List<AiPracticeAttempt>>? _practiceStream;
  var _showAllStudents = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final teacherId = widget.teacherId.isNotEmpty
        ? widget.teacherId
        : (scope.sessionController.user?.id ?? widget.session.teacherId);
    _feedbackStream ??= scope.courseStore.watchLectureFeedback(
      widget.session.id,
      teacherId: teacherId,
    );
    _attendeesStream ??= scope.courseStore.watchLectureAttendees(
      widget.session.id,
    );
    _practiceStream ??= scope.courseStore.watchLecturePracticeAttempts(
      widget.session.id,
    );
    if (teacherId.isNotEmpty) {
      _meetingsStream ??= scope.meetingStore.watchTeacherRequests(teacherId);
    }
  }


  String _emailFor(LectureFeedback item, List<LectureAttendee> attendees) {
    final fromFeedback = item.studentEmail.trim();
    if (fromFeedback.isNotEmpty) {
      return fromFeedback;
    }
    for (final attendee in attendees) {
      if (attendee.studentId == item.studentId &&
          attendee.studentEmail.trim().isNotEmpty) {
        return attendee.studentEmail.trim();
      }
    }
    return '';
  }

  void _openStudentProfile(
    LectureFeedback item,
    List<LectureAttendee> attendees,
  ) {
    final email = _emailFor(item, attendees);
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSettingsScreen(
          viewUserId: item.studentId,
          readOnly: true,
          fallbackUser: UserModel(
            id: item.studentId,
            fullName: item.studentName,
            email: email,
            role: UserRole.student,
            memberId: item.memberId,
          ),
        ),
      ),
    );
  }

  void _goHome() {
    Navigator.of(
      context,
    ).pushNamedAndRemoveUntil(AppRoutes.teacherDashboard, (_) => false);
  }

  String _chapterLine(AppLocalizations l10n) {
    final chapter = widget.session.chapterTitle.trim();
    final topic = widget.session.topicTitle.trim();
    if (chapter.isNotEmpty && topic.isNotEmpty) {
      return '$chapter: $topic';
    }
    if (chapter.isNotEmpty) {
      return chapter;
    }
    return topic.isNotEmpty ? topic : l10n.lectureFeedbackTitle;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final locale = Localizations.localeOf(context).toString();
    final started = widget.session.startedAt;
    final ended =
        widget.session.endedAt ??
        started?.add(Duration(minutes: widget.session.durationMinutes));

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : const Color(0xFFF4F7FB),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.headerNavy,
            padding: EdgeInsets.only(
              top: MediaQuery.paddingOf(context).top + 4,
              bottom: 18,
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(
                      tooltip: l10n.goBack,
                      color: Colors.white,
                      onPressed: _goHome,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                    Expanded(
                      child: Text(
                        l10n.lectureFeedbackTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    StreamBuilder<List<MeetingRequest>>(
                      stream: _meetingsStream,
                      builder: (context, snapshot) {
                        final pendingCount = (snapshot.data ?? const [])
                            .where((item) => item.needsTeacherAction)
                            .length;
                        final highlight = pendingCount > 0;
                        return IconButton(
                          tooltip: highlight
                              ? l10n.pendingMeetingRequests(pendingCount)
                              : l10n.meetingRequests,
                          color: highlight
                              ? const Color(0xFFFFD54F)
                              : Colors.white,
                          onPressed: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const TeacherMeetingsScreen(),
                              ),
                            );
                          },
                          icon: Badge(
                            isLabelVisible: highlight,
                            backgroundColor: const Color(0xFFFFC107),
                            label: Text(
                              '$pendingCount',
                              style: const TextStyle(
                                color: Color(0xFF1A1A1A),
                                fontWeight: FontWeight.w800,
                                fontSize: 10,
                              ),
                            ),
                            child: Icon(
                              highlight
                                  ? Icons.event_available_rounded
                                  : Icons.event_available_outlined,
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 4),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 48),
                  child: Text(
                    l10n.teacherFeedbackSubtitle,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<List<LectureFeedback>>(
              stream: _feedbackStream,
              builder: (context, feedbackSnap) {
                final feedback = feedbackSnap.data ?? const [];
                return StreamBuilder<List<LectureAttendee>>(
                  stream: _attendeesStream,
                  builder: (context, attendeesSnap) {
                    final attendees = attendeesSnap.data ?? const [];
                    return StreamBuilder<List<MeetingRequest>>(
                      stream: _meetingsStream,
                      builder: (context, meetingsSnap) {
                        return StreamBuilder<List<AiPracticeAttempt>>(
                          stream: _practiceStream,
                          builder: (context, practiceSnap) {
                            final practicedIds = {
                              for (final attempt
                                  in practiceSnap.data ??
                                      const <AiPracticeAttempt>[])
                                if (attempt.completed) attempt.studentId,
                            };
                            final allMeetings = meetingsSnap.data ?? const [];
                            final courseMeetings = allMeetings
                                .where(
                                  (m) => m.courseId == widget.session.courseId,
                                )
                                .toList();
                            final lectureMeetings = courseMeetings.where((m) {
                              if (widget.session.topicId.isNotEmpty &&
                                  m.topicId == widget.session.topicId) {
                                return true;
                              }
                              final topic = widget.session.topicTitle.trim();
                              return topic.isNotEmpty &&
                                  m.topicTitle.trim().toLowerCase() ==
                                      topic.toLowerCase();
                            }).toList();
                            final meetingStudentIds = {
                              for (final m in lectureMeetings)
                                if (m.studentId.isNotEmpty) m.studentId,
                            };
                            final counts = LectureFeedbackCounts.fromList(
                              feedback,
                            );
                            final attendeeCount = attendees.isEmpty
                                ? counts.total
                                : attendees.length;
                            final practiceCount = practicedIds.length;
                            final practiceRate = attendeeCount == 0
                                ? 0
                                : ((practiceCount / attendeeCount) * 100)
                                      .round();
                            final visible = _showAllStudents
                                ? feedback
                                : feedback.take(8).toList();
                            final needHelp = counts.below50;
                            final needHelpPct = counts.total == 0
                                ? 0
                                : ((needHelp / counts.total) * 100).round();

                            return ListView(
                              padding: EdgeInsets.fromLTRB(
                                padding,
                                14,
                                padding,
                                28,
                              ),
                              children: [
                                _CourseInfoCard(
                                  courseName: widget.courseName,
                                  courseCode: widget.courseCode,
                                  semester: widget.semester,
                                  chapterLine: _chapterLine(l10n),
                                  dateLabel: started == null
                                      ? '—'
                                      : DateFormat.yMMMd(
                                          locale,
                                        ).format(started),
                                  timeLabel: started == null || ended == null
                                      ? '—'
                                      : '${DateFormat.jm(locale).format(started)} - ${DateFormat.jm(locale).format(ended)}',
                                  completedLabel: l10n.completedStatus,
                                ),
                                const SizedBox(height: 14),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _MetricCard(
                                        child: _DonutMetric(
                                          segments: [
                                            (
                                              counts.percent100.toDouble(),
                                              const Color(0xFF2E9B5A),
                                            ),
                                            (
                                              counts.percent80.toDouble(),
                                              AppColors.teal,
                                            ),
                                            (
                                              counts.percent60.toDouble(),
                                              const Color(0xFFE0B03A),
                                            ),
                                            (
                                              counts.below50.toDouble(),
                                              const Color(0xFFE05A5A),
                                            ),
                                          ],
                                          centerTop: '$attendeeCount',
                                          centerBottom: l10n.studentsLabel,
                                          footer: l10n.responsesOfTotal(
                                            counts.total,
                                            attendeeCount,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MetricCard(
                                        child: _DonutMetric(
                                          segments: [
                                            (
                                              practiceCount.toDouble(),
                                              AppColors.teal,
                                            ),
                                            (
                                              math
                                                  .max(
                                                    attendeeCount -
                                                        practiceCount,
                                                    0,
                                                  )
                                                  .toDouble(),
                                              const Color(0xFFDDE5EE),
                                            ),
                                          ],
                                          centerTop: '$practiceCount',
                                          centerBottom: l10n.studentsLabel,
                                          footer: l10n.practiceRateLabel(
                                            practiceRate,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: _MetricCard(
                                        child: _MeetingMetric(
                                          lectureTotal: lectureMeetings.length,
                                          courseTotal: courseMeetings.length,
                                          totalLabel: l10n.totalRequestsLabel(
                                            lectureMeetings.length,
                                          ),
                                          courseLabel: l10n.thisCourseRequests(
                                            courseMeetings.length,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Text(
                                      l10n.understandingBreakdown,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 15,
                                        color: AppColors.textPrimary(
                                          brightness,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    Icon(
                                      Icons.info_outline_rounded,
                                      size: 16,
                                      color: AppColors.textSecondary(
                                        brightness,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _BreakdownRow(counts: counts, l10n: l10n),
                                const SizedBox(height: 18),
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        l10n.studentResponsesCount(
                                          feedback.length,
                                        ),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15,
                                          color: AppColors.textPrimary(
                                            brightness,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (feedback.length > 8)
                                      TextButton(
                                        onPressed: () => setState(
                                          () => _showAllStudents =
                                              !_showAllStudents,
                                        ),
                                        child: Text(
                                          _showAllStudents
                                              ? l10n.showLess
                                              : l10n.viewAll,
                                          style: const TextStyle(
                                            color: AppColors.teal,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                if (feedback.isEmpty)
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 18,
                                    ),
                                    child: Text(
                                      l10n.noFeedbackYet,
                                      style: TextStyle(
                                        color: AppColors.textSecondary(
                                          brightness,
                                        ),
                                      ),
                                    ),
                                  )
                                else
                                  for (final item in visible)
                                    _StudentResponseTile(
                                      feedback: item,
                                      hasMeeting: meetingStudentIds.contains(
                                        item.studentId,
                                      ),
                                      practiced: practicedIds.contains(
                                        item.studentId,
                                      ),
                                      onTap: () => _openStudentProfile(
                                        item,
                                        attendees,
                                      ),
                                    ),
                                if (needHelp > 0) ...[
                                  const SizedBox(height: 12),
                                  _InsightBanner(
                                    text: l10n.needHelpInsight(
                                      needHelp,
                                      needHelpPct,
                                    ),
                                  ),
                                ],
                              ],
                            );
                          },
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          Material(
            color: AppColors.fieldFill(brightness),
            elevation: 8,
            shadowColor: AppColors.navy.withValues(alpha: 0.12),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                child: CustomButton(
                  label: l10n.backToDashboard,
                  onPressed: _goHome,
                  variant: AppButtonVariant.signup,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseInfoCard extends StatelessWidget {
  const _CourseInfoCard({
    required this.courseName,
    required this.courseCode,
    required this.semester,
    required this.chapterLine,
    required this.dateLabel,
    required this.timeLabel,
    required this.completedLabel,
  });

  final String courseName;
  final String courseCode;
  final String semester;
  final String chapterLine;
  final String dateLabel;
  final String timeLabel;
  final String completedLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 6,
      shadowColor: Colors.black.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.teal.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.menu_book_rounded, color: AppColors.teal),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    courseName,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 16.5,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (courseCode.trim().isNotEmpty)
                        _Chip(text: courseCode, color: AppColors.teal),
                      if (semester.trim().isNotEmpty)
                        _Chip(text: semester, color: const Color(0xFF4A90C8)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    chapterLine,
                    style: TextStyle(
                      color: AppColors.textSecondary(brightness),
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
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
                    color: AppColors.teal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.check_circle_rounded,
                        size: 14,
                        color: AppColors.teal,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        completedLabel,
                        style: const TextStyle(
                          color: AppColors.teal,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  dateLabel,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  timeLabel,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary(brightness),
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

class _Chip extends StatelessWidget {
  const _Chip({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 3,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 8, 10),
        child: child,
      ),
    );
  }
}

class _DonutMetric extends StatelessWidget {
  const _DonutMetric({
    required this.segments,
    required this.centerTop,
    required this.centerBottom,
    required this.footer,
  });

  final List<(double, Color)> segments;
  final String centerTop;
  final String centerBottom;
  final String footer;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        SizedBox(
          height: 78,
          width: 78,
          child: CustomPaint(
            painter: _DonutPainter(segments: segments),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    centerTop,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: AppColors.textPrimary(brightness),
                    ),
                  ),
                  Text(
                    centerBottom,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary(brightness),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          footer,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments});

  final List<(double, Color)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, s) => sum + s.$1);
    final rect = Offset.zero & size;
    final stroke = size.shortestSide * 0.16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final center = rect.center;
    final radius = (size.shortestSide - stroke) / 2;
    if (total <= 0) {
      paint.color = const Color(0xFFDDE5EE);
      canvas.drawCircle(center, radius, paint);
      return;
    }
    var start = -math.pi / 2;
    for (final segment in segments) {
      if (segment.$1 <= 0) {
        continue;
      }
      final sweep = (segment.$1 / total) * math.pi * 2;
      paint.color = segment.$2;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        start,
        sweep,
        false,
        paint,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.segments != segments;
  }
}

class _MeetingMetric extends StatelessWidget {
  const _MeetingMetric({
    required this.lectureTotal,
    required this.courseTotal,
    required this.totalLabel,
    required this.courseLabel,
  });

  final int lectureTotal;
  final int courseTotal;
  final String totalLabel;
  final String courseLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      children: [
        Text(
          totalLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontWeight: FontWeight.w900,
            fontSize: 13,
            color: AppColors.textPrimary(brightness),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 42,
          width: double.infinity,
          child: CustomPaint(
            painter: _SparklinePainter(
              color: const Color(0xFF7B6CF6),
              values: _sparkValues(lectureTotal, courseTotal),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          courseLabel,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary(brightness),
          ),
        ),
      ],
    );
  }

  List<double> _sparkValues(int lecture, int course) {
    final base = course == 0 ? 1.0 : course.toDouble();
    return [
      base * 0.25,
      base * 0.4,
      base * 0.35,
      base * 0.55,
      math.max(lecture.toDouble(), 1),
    ];
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.color, required this.values});

  final Color color;
  final List<double> values;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }
    final maxV = values.reduce(math.max).clamp(1, double.infinity);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * (i / (values.length - 1));
      final y = size.height - (values[i] / maxV) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({required this.counts, required this.l10n});

  final LectureFeedbackCounts counts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final total = counts.total;
    int pct(int count) => total == 0 ? 0 : ((count / total) * 100).round();
    final items = [
      (
        counts.percent100,
        '100%',
        pct(counts.percent100),
        l10n.understoodPerfectly,
        const Color(0xFF2E9B5A),
        Icons.sentiment_very_satisfied_rounded,
      ),
      (
        counts.percent80,
        '80%',
        pct(counts.percent80),
        l10n.understoodMost,
        AppColors.teal,
        Icons.sentiment_satisfied_alt_rounded,
      ),
      (
        counts.percent60,
        '60%',
        pct(counts.percent60),
        l10n.understoodSome,
        const Color(0xFFE0B03A),
        Icons.sentiment_neutral_rounded,
      ),
      (
        counts.below50,
        l10n.understandBelow50,
        pct(counts.below50),
        l10n.needMoreHelp,
        const Color(0xFFE05A5A),
        Icons.sentiment_dissatisfied_rounded,
      ),
    ];

    return Row(
      children: [
        for (var i = 0; i < items.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: _BreakdownCell(
              count: items[i].$1,
              level: items[i].$2,
              percent: items[i].$3,
              label: items[i].$4,
              color: items[i].$5,
              icon: items[i].$6,
            ),
          ),
        ],
      ],
    );
  }
}

class _BreakdownCell extends StatelessWidget {
  const _BreakdownCell({
    required this.count,
    required this.level,
    required this.percent,
    required this.label,
    required this.color,
    required this.icon,
  });

  final int count;
  final String level;
  final int percent;
  final String label;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      decoration: BoxDecoration(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 4),
          Text(
            '$count',
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.textPrimary(brightness),
            ),
          ),
          Text(
            level,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 11,
              color: color,
            ),
          ),
          Text(
            '$percent%',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary(brightness),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 9.5,
              height: 1.2,
              color: AppColors.textSecondary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _StudentResponseTile extends StatelessWidget {
  const _StudentResponseTile({
    required this.feedback,
    required this.hasMeeting,
    required this.practiced,
    this.onTap,
  });

  final LectureFeedback feedback;
  final bool hasMeeting;
  final bool practiced;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final locale = Localizations.localeOf(context).toString();
    final (levelLabel, levelHint, color, icon) = switch (feedback.level) {
      UnderstandingLevel.percent100 => (
        l10n.understand100,
        l10n.understoodPerfectly,
        const Color(0xFF2E9B5A),
        Icons.sentiment_very_satisfied_rounded,
      ),
      UnderstandingLevel.percent80 => (
        l10n.understand80,
        l10n.understoodMost,
        AppColors.teal,
        Icons.sentiment_satisfied_alt_rounded,
      ),
      UnderstandingLevel.percent60 => (
        l10n.understand60,
        l10n.understoodSome,
        const Color(0xFFE0B03A),
        Icons.sentiment_neutral_rounded,
      ),
      UnderstandingLevel.below50 => (
        l10n.understandBelow50,
        l10n.needMoreHelp,
        const Color(0xFFE05A5A),
        Icons.sentiment_dissatisfied_rounded,
      ),
    };
    final time = feedback.updatedAt ?? feedback.createdAt;
    final name = feedback.studentName.trim().isEmpty
        ? l10n.student
        : feedback.studentName;
    final initial = name.isEmpty ? '?' : name[0].toUpperCase();

    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.teal.withValues(alpha: 0.14),
            child: Text(
              initial,
              style: const TextStyle(
                color: AppColors.tealDark,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary(brightness),
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(icon, size: 16, color: color),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '$levelLabel $levelHint',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _StatusPill(
                      text: practiced
                          ? l10n.practicedBadge
                          : l10n.notPracticedBadge,
                      color: practiced
                          ? const Color(0xFF2E9B5A)
                          : const Color(0xFFE05A5A),
                    ),
                    _StatusPill(
                      text: hasMeeting
                          ? '${l10n.meetingShort}: ${l10n.yesLabel}'
                          : '${l10n.meetingShort}: ${l10n.noLabel}',
                      color: hasMeeting
                          ? const Color(0xFF7B6CF6)
                          : AppColors.textSecondary(brightness),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time == null ? '—' : DateFormat.jm(locale).format(time),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
              const SizedBox(height: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textSecondary(brightness),
              ),
            ],
          ),
        ],
      ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.w800,
          fontSize: 10.5,
        ),
      ),
    );
  }
}

class _InsightBanner extends StatelessWidget {
  const _InsightBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      decoration: BoxDecoration(
        color: AppColors.teal.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.teal.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: AppColors.teal),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                height: 1.35,
                fontSize: 13,
              ),
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: AppColors.teal),
        ],
      ),
    );
  }
}
