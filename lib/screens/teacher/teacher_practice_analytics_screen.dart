import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/ai_practice.dart';
import '../../models/lecture_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/category_share_bar_chart.dart';
import '../../widgets/lecture_analytics_details_chrome.dart';
import '../common/profile_settings_screen.dart';
import 'lecture_practice_details_screen.dart';

class TeacherPracticeAnalyticsScreen extends StatefulWidget {
  const TeacherPracticeAnalyticsScreen({
    super.key,
    this.attempts = const [],
    this.attendees = const [],
    this.attendeeCount = 0,
    this.courseLabel = '',
    this.dateLabel = '',
  });

  final List<AiPracticeAttempt> attempts;
  final List<LectureAttendee> attendees;
  final int attendeeCount;
  final String courseLabel;
  final String dateLabel;

  @override
  State<TeacherPracticeAnalyticsScreen> createState() =>
      _TeacherPracticeAnalyticsScreenState();
}

class _TeacherPracticeAnalyticsScreenState
    extends State<TeacherPracticeAnalyticsScreen> {
  late String _selected;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    final students = _students(
      attempts: widget.attempts,
      attendees: widget.attendees,
    );
    final practicedCount = students.where((s) => s.practiced).length;
    final audience = resolveLectureAudienceCount(
      attendeeRecords: students.length,
      lectureStudentCount: widget.attendeeCount,
      responseCount: practicedCount,
    );
    final notPracticedCount = audience > practicedCount
        ? audience - practicedCount
        : students.where((s) => !s.practiced).length;
    _selected = practicedCount > 0
        ? kPracticeBarPracticed
        : notPracticedCount > 0
        ? kPracticeBarNotPracticed
        : kPracticeBarPracticed;
    _search = TextEditingController();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

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
    final students = _students(
      attempts: widget.attempts,
      attendees: widget.attendees,
    );
    final practicedCount = students.where((s) => s.practiced).length;
    final audience = resolveLectureAudienceCount(
      attendeeRecords: students.length,
      lectureStudentCount: widget.attendeeCount,
      responseCount: practicedCount,
    );
    final notPracticedCount = audience > practicedCount
        ? audience - practicedCount
        : students.where((s) => !s.practiced).length;
    final visible = _visible(students);
    final selectedColor = _selected == kPracticeBarPracticed
        ? AppColors.teal
        : const Color(0xFF9AA8BA);
    final selectedLabel = _selected == kPracticeBarPracticed
        ? l10n.practicedBadge
        : l10n.notPracticedBadge;
    final courseLabel = widget.courseLabel.trim().isEmpty
        ? l10n.analyticsAllCourses
        : widget.courseLabel.trim();
    final dateLabel = widget.dateLabel.trim().isEmpty
        ? l10n.analyticsAllTime
        : widget.dateLabel.trim();

    return Scaffold(
      backgroundColor: brightness == Brightness.dark
          ? AppColors.darkBackground
          : AppColors.pageWash,
      appBar: AppBar(
        backgroundColor: AppColors.headerNavy,
        foregroundColor: Colors.white,
        leading: const AppBackButton(),
        centerTitle: true,
        title: Text(l10n.teacherPracticeAnalyticsTitle),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
        children: [
          TeacherAnalyticsScopeHeaderCard(
            courseLabel: courseLabel,
            dateLabel: dateLabel,
            icon: Icons.smart_toy_outlined,
          ),
          const SizedBox(height: 14),
          LectureDetailsOverviewCard(
            title: l10n.practiceOverview,
            selectedId: _selected,
            onSelect: (id) => setState(() => _selected = id),
            countLabel: l10n.studentsCountLabel,
            totalLabel: l10n.totalPracticeLabel,
            totalValue: '$practicedCount / $audience',
            barKeyPrefix: 'teacher-practice-bar',
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
                    ? l10n.noTeacherPracticeAttemptsYet
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
                  'teacher-practice-student-${student.studentId}',
                ),
                name: student.name.trim().isEmpty
                    ? l10n.student
                    : student.name,
                studentId: student.displayId,
                onTap: () => _openStudent(student),
              ),
        ],
      ),
    );
  }
}
