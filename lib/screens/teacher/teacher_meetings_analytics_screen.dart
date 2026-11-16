import 'package:flutter/material.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/meeting_request.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/category_share_bar_chart.dart';
import '../../widgets/lecture_analytics_details_chrome.dart';
import 'lecture_meetings_details_screen.dart';
import 'meeting_detail_screen.dart';

class TeacherMeetingsAnalyticsScreen extends StatefulWidget {
  const TeacherMeetingsAnalyticsScreen({
    super.key,
    this.meetings = const [],
    this.courseLabel = '',
    this.dateLabel = '',
  });

  final List<MeetingRequest> meetings;
  final String courseLabel;
  final String dateLabel;

  @override
  State<TeacherMeetingsAnalyticsScreen> createState() =>
      _TeacherMeetingsAnalyticsScreenState();
}

class _TeacherMeetingsAnalyticsScreenState
    extends State<TeacherMeetingsAnalyticsScreen> {
  late LectureMeetingBucket _selected;
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    _selected = defaultMeetingBucket(widget.meetings);
    _search = TextEditingController();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<MeetingRequest> _visible(List<MeetingRequest> meetings) {
    final selected = [
      for (final meeting in meetings)
        if (meetingInBucket(meeting, _selected)) meeting,
    ];
    final needle = _search.text.trim().toLowerCase();
    if (needle.isEmpty) {
      return selected;
    }
    return [
      for (final meeting in selected)
        if (meeting.studentName.toLowerCase().contains(needle) ||
            lectureStudentDisplayId(
              memberId: meeting.memberId,
              studentId: meeting.studentId,
            ).toLowerCase().contains(needle) ||
            meeting.reason.toLowerCase().contains(needle))
          meeting,
    ];
  }

  Color _bucketColor(LectureMeetingBucket bucket) {
    return switch (bucket) {
      LectureMeetingBucket.pending => AppColors.gold,
      LectureMeetingBucket.scheduled => AppColors.teal,
      LectureMeetingBucket.attended => AppColors.navy,
    };
  }

  String _bucketLabel(AppLocalizations l10n, LectureMeetingBucket bucket) {
    return switch (bucket) {
      LectureMeetingBucket.pending => l10n.meetingBucketPending,
      LectureMeetingBucket.scheduled => l10n.meetingBucketScheduled,
      LectureMeetingBucket.attended => l10n.meetingBucketAttended,
    };
  }

  int _count(List<MeetingRequest> meetings, LectureMeetingBucket bucket) {
    return meetings.where((meeting) => meetingInBucket(meeting, bucket)).length;
  }

  void _openMeeting(MeetingRequest meeting) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MeetingDetailScreen(requestId: meeting.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final brightness = Theme.of(context).brightness;
    final padding = AppResponsive.pagePadding(context);
    final meetings = widget.meetings;
    final visible = _visible(meetings);
    final pending = _count(meetings, LectureMeetingBucket.pending);
    final scheduled = _count(meetings, LectureMeetingBucket.scheduled);
    final attended = _count(meetings, LectureMeetingBucket.attended);
    final bucketed = pending + scheduled + attended;
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
        title: Text(l10n.teacherMeetingsAnalyticsTitle),
      ),
      body: ListView(
        padding: EdgeInsets.fromLTRB(padding, 16, padding, 32),
        children: [
          TeacherAnalyticsScopeHeaderCard(
            courseLabel: courseLabel,
            dateLabel: dateLabel,
            icon: Icons.event_available_rounded,
            iconColor: AppColors.coral,
          ),
          const SizedBox(height: 14),
          LectureDetailsOverviewCard(
            title: l10n.meetingsOverview,
            selectedId: _selected.name,
            onSelect: (id) {
              for (final bucket in LectureMeetingBucket.values) {
                if (bucket.name == id) {
                  setState(() => _selected = bucket);
                  return;
                }
              }
            },
            countLabel: l10n.meetingsCountLabel,
            totalLabel: l10n.totalMeetingsLabel,
            totalValue: '$bucketed / ${meetings.length}',
            barKeyPrefix: 'teacher-meetings-bar',
            bars: [
              for (final bucket in LectureMeetingBucket.values)
                CategoryBarData(
                  id: bucket.name,
                  label: _bucketLabel(l10n, bucket),
                  count: _count(meetings, bucket),
                  color: _bucketColor(bucket),
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
            title: l10n.meetingsHeadingCount(visible.length),
            categoryLabel: _bucketLabel(l10n, _selected),
            categoryColor: _bucketColor(_selected),
          ),
          const SizedBox(height: 10),
          if (visible.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 18),
              child: Text(
                _search.text.trim().isNotEmpty
                    ? l10n.noMatchingMeetings
                    : meetings.isEmpty
                    ? l10n.noTeacherMeetingsYet
                    : l10n.noMeetingsInBucket,
                style: TextStyle(
                  color: AppColors.textSecondary(brightness),
                ),
              ),
            )
          else
            for (final meeting in visible)
              LectureStudentListTile(
                key: ValueKey<String>('teacher-meetings-row-${meeting.id}'),
                name: meeting.studentName.trim().isEmpty
                    ? l10n.student
                    : meeting.studentName,
                studentId: lectureStudentDisplayId(
                  memberId: meeting.memberId,
                  studentId: meeting.studentId,
                ),
                onTap: () => _openMeeting(meeting),
              ),
        ],
      ),
    );
  }
}
