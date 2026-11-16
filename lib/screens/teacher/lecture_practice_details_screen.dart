import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/ai_practice.dart';
import '../../models/course_model.dart';
import '../../models/lecture_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/category_share_bar_chart.dart';
import '../../widgets/lecture_analytics_details_chrome.dart';
import '../common/profile_settings_screen.dart';

const kPracticeBarPracticed = 'practiced';
const kPracticeBarNotPracticed = 'notPracticed';

class LecturePracticeStudent {
  const LecturePracticeStudent({
    required this.studentId,
    required this.name,
    required this.memberId,
    required this.email,
    required this.practiced,
  });

  final String studentId;
  final String name;
  final String memberId;
  final String email;
  final bool practiced;

  String get displayId => lectureStudentDisplayId(
    memberId: memberId,
    studentId: studentId,
  );
}

class LecturePracticeDetailsScreen extends StatefulWidget {
  const LecturePracticeDetailsScreen({
    super.key,
    required this.lecture,
    required this.course,
    this.attempts = const [],
    this.practiced = 0,
    this.notPracticed = 0,
    this.attendeeCount = 0,
  });

  final LectureModel lecture;
  final CourseModel course;
  final List<AiPracticeAttempt> attempts;
  final int practiced;
  final int notPracticed;
  final int attendeeCount;

  @override
  State<LecturePracticeDetailsScreen> createState() =>
      _LecturePracticeDetailsScreenState();
}

class _LecturePracticeDetailsScreenState
    extends State<LecturePracticeDetailsScreen> {
  late String _selected;
  late final TextEditingController _search;
  Stream<List<AiPracticeAttempt>>? _practiceStream;
  Stream<List<LectureAttendee>>? _attendeesStream;
  Stream<LectureModel?>? _lectureStream;

  @override
  void initState() {
    super.initState();
    _selected = widget.practiced > 0
        ? kPracticeBarPracticed
        : widget.notPracticed > 0
        ? kPracticeBarNotPracticed
        : kPracticeBarPracticed;
    _search = TextEditingController();
    _search.addListener(() => setState(() {}));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = AppScope.of(context);
    _lectureStream ??= scope.courseStore.watchLecture(widget.lecture.id);
    _practiceStream ??= scope.courseStore.watchLecturePracticeAttempts(
      widget.lecture.id,
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

  List<LecturePracticeStudent> _students({
    required List<AiPracticeAttempt> attempts,
    required List<LectureAttendee> attendees,
  }) {
    final byId = <String, LecturePracticeStudent>{};

    for (final attendee in attendees) {
      final id = attendee.studentId.trim();
      if (id.isEmpty) {
        continue;
      }
      byId[id] = LecturePracticeStudent(
        studentId: id,
        name: attendee.studentName,
        memberId: attendee.memberId,
        email: attendee.studentEmail,
        practiced: false,
      );
    }

    for (final attempt in attempts) {
      final id = attempt.studentId.trim();
      if (id.isEmpty) {
        continue;
      }
      final existing = byId[id];
      byId[id] = LecturePracticeStudent(
        studentId: id,
        name: attempt.studentName.trim().isNotEmpty
            ? attempt.studentName
            : (existing?.name ?? ''),
        memberId: existing?.memberId ?? '',
        email: existing?.email ?? '',
        practiced: true,
      );
    }

    return byId.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  List<LecturePracticeStudent> _visible(List<LecturePracticeStudent> students) {
    final practiced = _selected == kPracticeBarPracticed;
    final selected = [
      for (final student in students)
        if (student.practiced == practiced) student,
    ];
    final needle = _search.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return selected;
    }
    return [
      for (final student in selected)
        if (student.name.toLowerCase().contains(needle) ||
            student.displayId.toLowerCase().contains(needle))
          student,
    ];
  }

  void _openStudent(LecturePracticeStudent student) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSettingsScreen(
          viewUserId: student.studentId,
          readOnly: true,
          fallbackUser: UserModel(
            id: student.studentId,
            fullName: student.name,
            email: student.email,
            role: UserRole.student,
            memberId: student.memberId,
          ),
        ),
      ),
    );
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
          l10n.aiPracticeDetailTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<LectureModel?>(
        stream: _lectureStream,
        builder: (context, lectureSnap) {
          final lecture = _latest(lectureSnap.data);
          return StreamBuilder<List<AiPracticeAttempt>>(
            stream: _practiceStream,
            builder: (context, practiceSnap) {
              final streamed = practiceSnap.data;
              final attempts =
                  streamed == null ||
                      (streamed.isEmpty && widget.attempts.isNotEmpty)
                  ? widget.attempts
                  : streamed;
              return StreamBuilder<List<LectureAttendee>>(
                stream: _attendeesStream,
                builder: (context, attendeesSnap) {
                  final attendees = attendeesSnap.data ?? const [];
                  final students = _students(
                    attempts: attempts,
                    attendees: attendees,
                  );
                  final practicedCount = students
                      .where((student) => student.practiced)
                      .length;
                  final audience = resolveLectureAudienceCount(
                    attendeeRecords: attendees.length,
                    lectureStudentCount: lecture.studentCount > 0
                        ? lecture.studentCount
                        : widget.attendeeCount,
                    responseCount: practicedCount,
                  );
                  final notPracticedCount = audience > practicedCount
                      ? audience - practicedCount
                      : students.where((student) => !student.practiced).length;
                  final visible = _visible(students);
                  final started = lecture.startedAt;
                  final ended =
                      lecture.endedAt ??
                      started?.add(Duration(minutes: lecture.durationMinutes));
                  final selectedColor = _selected == kPracticeBarPracticed
                      ? AppColors.teal
                      : const Color(0xFF9AA8BA);
                  final selectedLabel = _selected == kPracticeBarPracticed
                      ? l10n.practicedBadge
                      : l10n.notPracticedBadge;

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
                        title: l10n.practiceOverview,
                        selectedId: _selected,
                        onSelect: (id) => setState(() => _selected = id),
                        countLabel: l10n.studentsCountLabel,
                        totalLabel: l10n.totalPracticeLabel,
                        totalValue: '$practicedCount / $audience',
                        barKeyPrefix: 'practice-bar',
                        bars: [
                          CategoryBarData(
                            id: kPracticeBarPracticed,
                            label: l10n.practicedBadge,
                            count: practicedCount,
                            color: AppColors.teal,
                          ),
                          CategoryBarData(
                            id: kPracticeBarNotPracticed,
                            label: l10n.notPracticedBadge,
                            count: notPracticedCount,
                            color: const Color(0xFF9AA8BA),
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
                        title: l10n.studentsHeadingCount(visible.length),
                        categoryLabel: selectedLabel,
                        categoryColor: selectedColor,
                      ),
                      const SizedBox(height: 10),
                      if (visible.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 18),
                          child: Text(
                            _search.text.trim().isNotEmpty
                                ? l10n.noMatchingStudents
                                : students.isEmpty
                                ? l10n.noPracticeAttemptsYet
                                : l10n.noStudentsInPracticeGroup,
                            style: TextStyle(
                              color: AppColors.textSecondary(brightness),
                            ),
                          ),
                        )
                      else
                        for (final student in visible)
                          LectureStudentListTile(
                            key: ValueKey<String>(
                              'practice-student-${student.studentId}',
                            ),
                            name: student.name.trim().isEmpty
                                ? l10n.student
                                : student.name,
                            studentId: student.displayId,
                            onTap: () => _openStudent(student),
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
