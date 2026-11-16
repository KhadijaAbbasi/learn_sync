import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/lecture_feedback.dart';
import '../../models/lecture_model.dart';
import '../../models/user_model.dart';
import '../../models/user_role.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/category_share_bar_chart.dart';
import '../../widgets/lecture_analytics_details_chrome.dart';
import '../common/profile_settings_screen.dart';
import 'understanding_level_style.dart';

class TeacherUnderstandingAnalyticsScreen extends StatefulWidget {
  const TeacherUnderstandingAnalyticsScreen({
    super.key,
    this.feedback = const [],
    this.attendees = const [],
    this.attendeeCount = 0,
    this.courseLabel = '',
    this.dateLabel = '',
  });

  final List<LectureFeedback> feedback;
  final List<LectureAttendee> attendees;
  final int attendeeCount;
  final String courseLabel;
  final String dateLabel;

  @override
  State<TeacherUnderstandingAnalyticsScreen> createState() =>
      _TeacherUnderstandingAnalyticsScreenState();
}

class _TeacherUnderstandingAnalyticsScreenState
    extends State<TeacherUnderstandingAnalyticsScreen> {
  late UnderstandingLevel _selected;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    final students = _uniqueFeedback(widget.feedback);
    final counts = LectureFeedbackCounts.fromList(students);
    _selected = counts.defaultSelectedLevel;
    _search = TextEditingController();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// One row per student across combined lectures (latest feedback wins).
  List<LectureFeedback> _uniqueFeedback(List<LectureFeedback> feedback) {
    final byId = <String, LectureFeedback>{};
    for (final item in feedback) {
      final id = item.studentId.trim();
      if (id.isEmpty) {
        continue;
      }
      final existing = byId[id];
      if (existing == null) {
        byId[id] = item;
        continue;
      }
      final existingAt = existing.updatedAt ?? existing.createdAt;
      final nextAt = item.updatedAt ?? item.createdAt;
      if (existingAt == null ||
          (nextAt != null && nextAt.isAfter(existingAt))) {
        byId[id] = item;
      }
    }
    return byId.values.toList()
      ..sort(
        (a, b) => a.studentName.toLowerCase().compareTo(
          b.studentName.toLowerCase(),
        ),
      );
  }

  List<LectureFeedback> _visible(List<LectureFeedback> students) {
    final selected = [
      for (final item in students)
        if (item.level == _selected) item,
    ];
    final needle = _search.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return selected;
    }
    return [
      for (final item in selected)
        if (item.studentName.toLowerCase().contains(needle) ||
            lectureStudentDisplayId(
              memberId: item.memberId,
              studentId: item.studentId,
            ).toLowerCase().contains(needle))
          item,
    ];
  }

  String _emailFor(LectureFeedback item) {
    final fromFeedback = item.studentEmail.trim();
    if (fromFeedback.isNotEmpty) {
      return fromFeedback;
    }
    for (final attendee in widget.attendees) {
      if (attendee.studentId == item.studentId &&
          attendee.studentEmail.trim().isNotEmpty) {
        return attendee.studentEmail.trim();
      }
    }
    return '';
  }

  void _openStudent(LectureFeedback item) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileSettingsScreen(
          viewUserId: item.studentId,
          readOnly: true,
          fallbackUser: UserModel(
            id: item.studentId,
            fullName: item.studentName,
            email: _emailFor(item),
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
    final students = _uniqueFeedback(widget.feedback);
    final counts = LectureFeedbackCounts.fromList(students);
    final audience = resolveLectureAudienceCount(
      attendeeRecords: widget.attendees.isNotEmpty
          ? {
              for (final a in widget.attendees)
                if (a.studentId.trim().isNotEmpty) a.studentId.trim(),
            }.length
          : students.length,
      lectureStudentCount: widget.attendeeCount,
      responseCount: counts.total,
    );
    final visible = _visible(students);
    final levelVisual = understandingLevelVisual(l10n, _selected);
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
        title: Text(l10n.teacherUnderstandingAnalyticsTitle),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
        children: [
          TeacherAnalyticsScopeHeaderCard(
            courseLabel: courseLabel,
            dateLabel: dateLabel,
            icon: Icons.insights_rounded,
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
            barKeyPrefix: 'teacher-understanding-bar',
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
                _search.text.trim().isNotEmpty
                    ? l10n.noMatchingStudents
                    : students.isEmpty
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
                  'teacher-understanding-student-${item.studentId}',
                ),
                name: item.studentName.trim().isEmpty
                    ? l10n.student
                    : item.studentName,
                studentId: lectureStudentDisplayId(
                  memberId: item.memberId,
                  studentId: item.studentId,
                ),
                onTap: () => _openStudent(item),
              ),
        ],
      ),
    );
  }
}
