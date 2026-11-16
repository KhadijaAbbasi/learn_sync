import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/ai_practice.dart';
import '../../models/course_model.dart';
import '../../models/lecture_feedback.dart';
import '../../models/lecture_model.dart';
import '../../models/meeting_request.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import 'lecture_meetings_details_screen.dart';
import 'lecture_practice_details_screen.dart';
import 'lecture_understanding_details_screen.dart';

class LectureAnalyticsScreen extends StatefulWidget {
  const LectureAnalyticsScreen({
    super.key,
    required this.lecture,
    required this.course,
  });

  final LectureModel lecture;
  final CourseModel course;

  @override
  State<LectureAnalyticsScreen> createState() => _LectureAnalyticsScreenState();
}

class _LectureAnalyticsScreenState extends State<LectureAnalyticsScreen> {
  Stream<LectureModel?>? _lectureStream;
  Stream<List<LectureFeedback>>? _feedbackStream;
  Stream<List<LectureAttendee>>? _attendeesStream;
  Stream<List<AiPracticeAttempt>>? _practiceStream;
  Stream<List<MeetingRequest>>? _meetingsStream;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final teacherId = scope.sessionController.user?.id ?? widget.lecture.teacherId;
    _lectureStream ??= scope.courseStore.watchLecture(widget.lecture.id);
    _feedbackStream ??= scope.courseStore.watchLectureFeedback(
      widget.lecture.id,
      teacherId: teacherId,
    );
    _attendeesStream ??= scope.courseStore.watchLectureAttendees(
      widget.lecture.id,
    );
    _practiceStream ??= scope.courseStore.watchLecturePracticeAttempts(
      widget.lecture.id,
    );
    if (teacherId.isNotEmpty) {
      _meetingsStream ??= scope.meetingStore.watchTeacherRequests(teacherId);
    }
  }

  LectureModel _latest(LectureModel? streamed) => streamed ?? widget.lecture;

  List<MeetingRequest> _lectureMeetings(List<MeetingRequest> all, LectureModel lecture) {
    return [
      for (final meeting in all)
        if (meetingMatchesLecture(
          meeting,
          courseId: lecture.courseId,
          lectureId: lecture.id,
          topicId: lecture.topicId,
          topicTitle: lecture.topicTitle,
        ))
          meeting,
    ];
  }


  void _openUnderstanding({
    required LectureModel lecture,
    required List<LectureFeedback> feedback,
    required LectureFeedbackCounts counts,
    required int attendeeCount,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LectureUnderstandingDetailsScreen(
          lecture: lecture,
          course: widget.course,
          feedback: feedback,
          counts: counts,
          attendeeCount: attendeeCount,
        ),
      ),
    );
  }

  void _openPractice({
    required LectureModel lecture,
    required List<AiPracticeAttempt> attempts,
    required int practiced,
    required int notPracticed,
    required int attendeeCount,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LecturePracticeDetailsScreen(
          lecture: lecture,
          course: widget.course,
          attempts: attempts,
          practiced: practiced,
          notPracticed: notPracticed,
          attendeeCount: attendeeCount,
        ),
      ),
    );
  }

  void _openMeetingsDetails({
    required LectureModel lecture,
    required List<MeetingRequest> meetings,
  }) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LectureMeetingsDetailsScreen(
          lecture: lecture,
          course: widget.course,
          meetings: meetings,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scope = AppScope.of(context);
    final user = scope.sessionController.user;
    if (user?.role != UserRole.teacher) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.lectureAnalytics)),
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
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(
          l10n.lectureAnalytics,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<LectureModel?>(
        stream: _lectureStream,
        builder: (context, lectureSnap) {
          final lecture = _latest(lectureSnap.data);
          return StreamBuilder<List<LectureFeedback>>(
            stream: _feedbackStream,
            builder: (context, feedbackSnap) {
              final feedback = feedbackSnap.data ?? const [];
              return StreamBuilder<List<LectureAttendee>>(
                stream: _attendeesStream,
                builder: (context, attendeesSnap) {
                  final attendees = attendeesSnap.data ?? const [];
                  return StreamBuilder<List<AiPracticeAttempt>>(
                    stream: _practiceStream,
                    builder: (context, practiceSnap) {
                      final attempts = practiceSnap.data ?? const [];
                      return StreamBuilder<List<MeetingRequest>>(
                        stream: _meetingsStream,
                        builder: (context, meetingsSnap) {
                          final meetings = _lectureMeetings(
                            meetingsSnap.data ?? const [],
                            lecture,
                          );
                          final counts = LectureFeedbackCounts.fromList(feedback);
                          final studentCount = resolveLectureAudienceCount(
                            attendeeRecords: attendees.length,
                            lectureStudentCount: lecture.studentCount,
                            responseCount: counts.total,
                          );
                          final practicedIds = {
                            for (final attempt in attempts)
                              if (attempt.studentId.isNotEmpty) attempt.studentId,
                          };
                          final practiced = practicedIds.length;
                          final notPracticed = math.max(studentCount - practiced, 0);
                          final practiceRate = studentCount == 0
                              ? 0
                              : ((practiced / studentCount) * 100).round();
                          final started = lecture.startedAt;
                          final ended =
                              lecture.endedAt ??
                              started?.add(
                                Duration(minutes: lecture.durationMinutes),
                              );
                          final chapterLine = _chapterLine(l10n, lecture);

                          return ListView(
                            padding: EdgeInsets.fromLTRB(
                              padding,
                              16,
                              padding,
                              32,
                            ),
                            children: [
                              _LectureHeaderCard(
                                courseName: lecture.courseName.isNotEmpty
                                    ? lecture.courseName
                                    : widget.course.name,
                                courseCode: widget.course.code,
                                semester: widget.course.semester,
                                chapterLine: chapterLine,
                                completed:
                                    lecture.status == LectureStatus.ended,
                                completedLabel: l10n.completedStatus,
                                liveLabel: l10n.liveNow,
                                dateLabel: started == null
                                    ? (lecture.lectureDate.isEmpty
                                          ? '—'
                                          : lecture.lectureDate)
                                    : DateFormat.yMMMd(locale).format(started),
                                timeLabel: started == null || ended == null
                                    ? '—'
                                    : '${DateFormat.jm(locale).format(started)} - ${DateFormat.jm(locale).format(ended)}',
                              ),
                              const SizedBox(height: 14),
                              _UnderstandingSection(
                                title: l10n.understandingSection,
                                counts: counts,
                                studentCount: studentCount,
                                studentsLabel: l10n.studentsLabel,
                                footer: l10n.responsesOfTotal(
                                  counts.total,
                                  studentCount,
                                ),
                                l10n: l10n,
                                onTap: () => _openUnderstanding(
                                  lecture: lecture,
                                  feedback: feedback,
                                  counts: counts,
                                  attendeeCount: studentCount,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _PracticeSection(
                                title: l10n.aiPracticeSection,
                                practiced: practiced,
                                notPracticed: notPracticed,
                                studentCount: studentCount,
                                studentsLabel: l10n.studentsLabel,
                                practicedLabel: l10n.practicedBadge,
                                notPracticedLabel: l10n.notPracticedBadge,
                                footer: l10n.practiceRateLabel(practiceRate),
                                onTap: () => _openPractice(
                                  lecture: lecture,
                                  attempts: attempts,
                                  practiced: practiced,
                                  notPracticed: notPracticed,
                                  attendeeCount: studentCount,
                                ),
                              ),
                              const SizedBox(height: 14),
                              _MeetingsSection(
                                title: l10n.meetingsSection,
                                meetings: meetings,
                                totalLabel: l10n.totalRequestsThisLecture(
                                  meetings.length,
                                ),
                                viewAllLabel: l10n.viewAllRequests,
                                onTap: () => _openMeetingsDetails(
                                  lecture: lecture,
                                  meetings: meetings,
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  String _chapterLine(AppLocalizations l10n, LectureModel lecture) {
    final chapter = lecture.chapterTitle.trim();
    final topic = lecture.topicTitle.trim();
    if (chapter.isNotEmpty && topic.isNotEmpty) {
      return '$chapter: $topic';
    }
    if (chapter.isNotEmpty) {
      return chapter;
    }
    return topic.isNotEmpty ? topic : l10n.lectureAnalytics;
  }
}

class _LectureHeaderCard extends StatelessWidget {
  const _LectureHeaderCard({
    required this.courseName,
    required this.courseCode,
    required this.semester,
    required this.chapterLine,
    required this.completed,
    required this.completedLabel,
    required this.liveLabel,
    required this.dateLabel,
    required this.timeLabel,
  });

  final String courseName;
  final String courseCode;
  final String semester;
  final String chapterLine;
  final bool completed;
  final String completedLabel;
  final String liveLabel;
  final String dateLabel;
  final String timeLabel;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _AnalyticsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.teal.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
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
                          _Chip(text: courseCode, filled: true),
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
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (completed ? const Color(0xFF2E9B5A) : AppColors.coral)
                      .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      completed
                          ? Icons.check_circle_rounded
                          : Icons.podcasts_rounded,
                      size: 14,
                      color: completed
                          ? const Color(0xFF2E9B5A)
                          : AppColors.coral,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      completed ? completedLabel : liveLabel,
                      style: TextStyle(
                        color: completed
                            ? const Color(0xFF2E9B5A)
                            : AppColors.coral,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              _Meta(icon: Icons.calendar_today_outlined, text: dateLabel),
              _Meta(icon: Icons.schedule_outlined, text: timeLabel),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnderstandingSection extends StatelessWidget {
  const _UnderstandingSection({
    required this.title,
    required this.counts,
    required this.studentCount,
    required this.studentsLabel,
    required this.footer,
    required this.l10n,
    required this.onTap,
  });

  final String title;
  final LectureFeedbackCounts counts;
  final int studentCount;
  final String studentsLabel;
  final String footer;
  final AppLocalizations l10n;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = counts.total;
    int pct(int count) => total == 0 ? 0 : ((count / total) * 100).round();
    final rows = [
      (
        const Color(0xFF2E9B5A),
        '${l10n.understand100} (${l10n.understoodPerfectly})',
        counts.percent100,
        pct(counts.percent100),
      ),
      (
        AppColors.teal,
        '${l10n.understand80} (${l10n.understoodMost})',
        counts.percent80,
        pct(counts.percent80),
      ),
      (
        const Color(0xFFE0B03A),
        '${l10n.understand60} (${l10n.understoodSome})',
        counts.percent60,
        pct(counts.percent60),
      ),
      (
        const Color(0xFFE05A5A),
        '${l10n.understandBelow50} (${l10n.needMoreHelp})',
        counts.below50,
        pct(counts.below50),
      ),
    ];

    return _TappableSection(
      title: title,
      footer: footer,
      onTap: onTap,
      child: Row(
        children: [
          _Donut(
            size: 118,
            segments: [
              (counts.percent100.toDouble(), const Color(0xFF2E9B5A)),
              (counts.percent80.toDouble(), AppColors.teal),
              (counts.percent60.toDouble(), const Color(0xFFE0B03A)),
              (counts.below50.toDouble(), const Color(0xFFE05A5A)),
            ],
            centerTop: '$studentCount',
            centerBottom: l10n.studentsLabel,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                for (final row in rows)
                  _LegendRow(
                    color: row.$1,
                    label: row.$2,
                    value: '${row.$3} (${row.$4}%)',
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PracticeSection extends StatelessWidget {
  const _PracticeSection({
    required this.title,
    required this.practiced,
    required this.notPracticed,
    required this.studentCount,
    required this.studentsLabel,
    required this.practicedLabel,
    required this.notPracticedLabel,
    required this.footer,
    required this.onTap,
  });

  final String title;
  final int practiced;
  final int notPracticed;
  final int studentCount;
  final String studentsLabel;
  final String practicedLabel;
  final String notPracticedLabel;
  final String footer;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final total = practiced + notPracticed;
    int pct(int count) => total == 0 ? 0 : ((count / total) * 100).round();
    return _TappableSection(
      title: title,
      footer: footer,
      onTap: onTap,
      child: Row(
        children: [
          _Donut(
            size: 118,
            segments: [
              (practiced.toDouble(), AppColors.teal),
              (notPracticed.toDouble(), const Color(0xFFDDE5EE)),
            ],
            centerTop: '$studentCount',
            centerBottom: studentsLabel,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              children: [
                _LegendRow(
                  color: AppColors.teal,
                  label: practicedLabel,
                  value: '$practiced (${pct(practiced)}%)',
                ),
                _LegendRow(
                  color: const Color(0xFF9AA8BA),
                  label: notPracticedLabel,
                  value: '$notPracticed (${pct(notPracticed)}%)',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MeetingsSection extends StatelessWidget {
  const _MeetingsSection({
    required this.title,
    required this.meetings,
    required this.totalLabel,
    required this.viewAllLabel,
    required this.onTap,
  });

  final String title;
  final List<MeetingRequest> meetings;
  final String totalLabel;
  final String viewAllLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _TappableSection(
      title: title,
      onTap: onTap,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 88,
                  child: CustomPaint(
                    painter: _AreaChartPainter(
                      values: _monthValues(meetings),
                      color: const Color(0xFF7B6CF6),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF7B6CF6).withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      const Icon(
                        Icons.groups_outlined,
                        color: Color(0xFF7B6CF6),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        totalLabel,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 12.5,
                          color: AppColors.textPrimary(brightness),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                viewAllLabel,
                style: const TextStyle(
                  color: AppColors.teal,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.teal,
                size: 20,
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<double> _monthValues(List<MeetingRequest> meetings) {
    final now = DateTime.now();
    final buckets = List<double>.filled(5, 0);
    for (final meeting in meetings) {
      final at = meeting.requestedAt ?? meeting.scheduledAt;
      if (at == null) {
        buckets[4] += 1;
        continue;
      }
      final monthsAgo =
          (now.year - at.year) * 12 + (now.month - at.month);
      if (monthsAgo >= 0 && monthsAgo < 5) {
        buckets[4 - monthsAgo] += 1;
      }
    }
    if (buckets.every((value) => value == 0) && meetings.isNotEmpty) {
      buckets[4] = meetings.length.toDouble();
    }
    return buckets;
  }
}

class _TappableSection extends StatelessWidget {
  const _TappableSection({
    required this.title,
    required this.child,
    required this.onTap,
    this.footer,
  });

  final String title;
  final Widget child;
  final VoidCallback onTap;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary(brightness),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.textSecondary(brightness),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  child,
                ],
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 9,
                ),
                decoration: BoxDecoration(
                  color: brightness == Brightness.dark
                      ? AppColors.darkBackground
                      : const Color(0xFFF4F6F8),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(18),
                  ),
                ),
                child: Text(
                  footer!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary(brightness),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AnalyticsCard extends StatelessWidget {
  const _AnalyticsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: brightness == Brightness.dark
          ? AppColors.darkSurface
          : Colors.white,
      elevation: 4,
      shadowColor: Colors.black.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(18),
      child: Padding(padding: const EdgeInsets.all(14), child: child),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.text, this.filled = false, this.color});

  final String text;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? AppColors.teal;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: filled ? AppColors.teal : tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: filled ? Colors.white : tone,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: AppColors.teal),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary(Theme.of(context).brightness),
          ),
        ),
      ],
    );
  }
}

class _LegendRow extends StatelessWidget {
  const _LegendRow({
    required this.color,
    required this.label,
    required this.value,
  });

  final Color color;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary(brightness),
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _Donut extends StatelessWidget {
  const _Donut({
    required this.segments,
    required this.centerTop,
    required this.centerBottom,
    this.size = 118,
  });

  final List<(double, Color)> segments;
  final String centerTop;
  final String centerBottom;
  final double size;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SizedBox(
      height: size,
      width: size,
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
                  fontSize: 18,
                  color: AppColors.textPrimary(brightness),
                ),
              ),
              Text(
                centerBottom,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({required this.segments});

  final List<(double, Color)> segments;

  @override
  void paint(Canvas canvas, Size size) {
    final total = segments.fold<double>(0, (sum, s) => sum + s.$1);
    final stroke = size.shortestSide * 0.16;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.butt;
    final center = Offset(size.width / 2, size.height / 2);
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

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) {
      return;
    }
    final maxV = values.reduce(math.max).clamp(1, double.infinity);
    final path = Path();
    final fill = Path();
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * (i / (values.length - 1));
      final y = size.height - (values[i] / maxV) * (size.height * 0.78);
      if (i == 0) {
        path.moveTo(x, y);
        fill.moveTo(x, size.height);
        fill.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fill.lineTo(x, y);
      }
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()..color = color.withValues(alpha: 0.16),
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < values.length; i++) {
      final x = values.length == 1
          ? size.width / 2
          : size.width * (i / (values.length - 1));
      final y = size.height - (values[i] / maxV) * (size.height * 0.78);
      canvas.drawCircle(Offset(x, y), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

