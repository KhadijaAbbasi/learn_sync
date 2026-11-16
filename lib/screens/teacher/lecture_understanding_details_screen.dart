import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/course_model.dart';
import '../../models/lecture_feedback.dart';
import '../../models/lecture_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/category_share_bar_chart.dart';
import '../../widgets/lecture_analytics_details_chrome.dart';
import '../common/profile_settings_screen.dart';
import 'understanding_level_style.dart';

class LectureUnderstandingDetailsScreen extends StatefulWidget {
  const LectureUnderstandingDetailsScreen({
    super.key,
    required this.lecture,
    required this.course,
    required this.feedback,
    required this.counts,
    this.attendeeCount = 0,
  });

  final LectureModel lecture;
  final CourseModel course;
  final List<LectureFeedback> feedback;
  final LectureFeedbackCounts counts;
  final int attendeeCount;

  @override
  State<LectureUnderstandingDetailsScreen> createState() =>
      _LectureUnderstandingDetailsScreenState();
}

class _LectureUnderstandingDetailsScreenState
    extends State<LectureUnderstandingDetailsScreen> {
  late UnderstandingLevel _selected;
  late final TextEditingController _search;
  Stream<List<LectureFeedback>>? _feedbackStream;
  Stream<List<LectureAttendee>>? _attendeesStream;
  Stream<LectureModel?>? _lectureStream;

  @override
  void initState() {
    super.initState();
    _selected = widget.counts.defaultSelectedLevel;
    _search = TextEditingController();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    final teacherId =
        scope.sessionController.user?.id ?? widget.lecture.teacherId;
    _lectureStream ??= scope.courseStore.watchLecture(widget.lecture.id);
    _feedbackStream ??= scope.courseStore.watchLectureFeedback(
      widget.lecture.id,
      teacherId: teacherId,
    );
    _attendeesStream ??= scope.courseStore.watchLectureAttendees(
      widget.lecture.id,
    );
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  LectureModel _latest(LectureModel? streamed) => streamed ?? widget.lecture;

  List<LectureFeedback> _visibleStudents(List<LectureFeedback> feedback) {
    final needle = _search.text.trim().toLowerCase();
    final selected = [
      for (final item in feedback)
        if (item.level == _selected) item,
    ];
    if (needle.isEmpty) {
      return selected;
    }
    return [
      for (final item in selected)
        if (item.studentName.toLowerCase().contains(needle)) item,
    ];
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

  String _levelLabel(AppLocalizations l10n, UnderstandingLevel level) {
    return switch (level) {
      UnderstandingLevel.percent100 => l10n.understand100,
      UnderstandingLevel.percent80 => l10n.understand80,
      UnderstandingLevel.percent60 => l10n.understand60,
      UnderstandingLevel.below50 => l10n.understandBelow50,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
          l10n.understandingDetailTitle,
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
              final streamed = feedbackSnap.data;
              final feedback =
                  streamed == null ||
                      (streamed.isEmpty && widget.feedback.isNotEmpty)
                  ? widget.feedback
                  : streamed;
              return StreamBuilder<List<LectureAttendee>>(
                stream: _attendeesStream,
                builder: (context, attendeesSnap) {
                  final attendees = attendeesSnap.data ?? const [];
                  final counts = LectureFeedbackCounts.fromList(feedback);
                  final audience = resolveLectureAudienceCount(
                    attendeeRecords: attendees.length,
                    lectureStudentCount: lecture.studentCount > 0
                        ? lecture.studentCount
                        : widget.attendeeCount,
                    responseCount: counts.total,
                  );
                  final visible = _visibleStudents(feedback);
                  final started = lecture.startedAt;
                  final ended =
                      lecture.endedAt ??
                      started?.add(Duration(minutes: lecture.durationMinutes));
                  final levelVisual = understandingLevelVisual(l10n, _selected);

                  return ListView(
                    padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
                    children: [
                      LectureAnalyticsHeaderCard(
                        courseName: lecture.courseName.isNotEmpty
                            ? lecture.courseName
                            : widget.course.name,
                        courseCode: widget.course.code,
                        semester: widget.course.semester,
                        chapterLine: lectureChapterLine(l10n, lecture),
                        completed: lecture.status == LectureStatus.ended,
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
                      LectureDetailsOverviewCard(
                        title: l10n.understandingOverview,
                        selectedId: _selected.name,
                        onSelect: (id) {
                          for (final level in UnderstandingLevel.values) {
                            if (level.name == id) {
                              setState(() => _selected = level);
                              return;
                            }
                          }
                        },
                        countLabel: l10n.studentsCountLabel,
                        totalLabel: l10n.totalResponsesLabel,
                        totalValue: '${counts.total} / $audience',
                        barKeyPrefix: 'understanding-bar',
                        bars: [
                          for (final level in UnderstandingLevel.values)
                            CategoryBarData(
                              id: level.name,
                              label: _levelLabel(l10n, level),
                              count: counts.countFor(level),
                              color: understandingLevelColor(level),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      LectureDetailsSearchField(
                        controller: _search,
                        hintText: l10n.searchStudentHint,
                      ),
                      const SizedBox(height: 16),
                      LectureCategoryHeading(
                        title: l10n.studentResponsesCount(visible.length),
                        categoryLabel: levelVisual.percent,
                        categoryColor: levelVisual.color,
                      ),
                      const SizedBox(height: 10),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            feedback.isEmpty
                                ? l10n.noFeedbackYet
                                : counts.countFor(_selected) == 0
                                ? l10n.noStudentsInLevel
                                : l10n.noMatchingStudents,
                            style: TextStyle(
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                        )
                      else
                        for (final item in visible)
                          LectureStudentListTile(
                            key: ValueKey<String>(
                              'understanding-student-${item.studentId}',
                            ),
                            name: item.studentName.trim().isEmpty
                                ? l10n.student
                                : item.studentName,
                            studentId: lectureStudentDisplayId(
                              memberId: item.memberId,
                              studentId: item.studentId,
                            ),
                            onTap: () =>
                                _openStudentProfile(item, attendees),
                          ),
                    ],
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

/// Thin adapter kept for call sites that still name the Understanding chart.
class UnderstandingLevelBarChart extends StatelessWidget {
  const UnderstandingLevelBarChart({
    super.key,
    required this.counts,
    required this.selected,
    required this.l10n,
    required this.onSelect,
  });

  final LectureFeedbackCounts counts;
  final UnderstandingLevel selected;
  final AppLocalizations l10n;
  final ValueChanged<UnderstandingLevel> onSelect;

  static String _levelLabel(AppLocalizations l10n, UnderstandingLevel level) {
    return switch (level) {
      UnderstandingLevel.percent100 => l10n.understand100,
      UnderstandingLevel.percent80 => l10n.understand80,
      UnderstandingLevel.percent60 => l10n.understand60,
      UnderstandingLevel.below50 => l10n.understandBelow50,
    };
  }

  @override
  Widget build(BuildContext context) {
    return CategoryShareBarChart(
      bars: [
        for (final level in UnderstandingLevel.values)
          CategoryBarData(
            id: level.name,
            label: _levelLabel(l10n, level),
            count: counts.countFor(level),
            color: understandingLevelColor(level),
          ),
      ],
      selectedId: selected.name,
      onSelect: (id) {
        for (final level in UnderstandingLevel.values) {
          if (level.name == id) {
            onSelect(level);
            return;
          }
        }
      },
      countLabel: l10n.studentsCountLabel,
      keyPrefix: 'understanding-bar',
    );
  }
}
