import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:learnsync/l10n/app_localizations.dart';

import '../../core/di/app_scope.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/responsive.dart';
import '../../models/course_model.dart';
import '../../models/lecture_model.dart';
import '../../models/meeting_request.dart';
import '../../widgets/app_back_button.dart';
import '../../widgets/category_share_bar_chart.dart';
import '../../widgets/lecture_analytics_details_chrome.dart';
import 'meeting_detail_screen.dart';

enum LectureMeetingBucket { pending, scheduled, attended }

bool meetingInBucket(MeetingRequest meeting, LectureMeetingBucket bucket) {
  return switch (bucket) {
    LectureMeetingBucket.pending => meeting.needsTeacherAction,
    LectureMeetingBucket.scheduled => meeting.isAccepted,
    LectureMeetingBucket.attended => meeting.isCompleted,
  };
}

LectureMeetingBucket defaultMeetingBucket(List<MeetingRequest> meetings) {
  for (final bucket in LectureMeetingBucket.values) {
    if (meetings.any((meeting) => meetingInBucket(meeting, bucket))) {
      return bucket;
    }
  }
  return LectureMeetingBucket.pending;
}

class LectureMeetingsDetailsScreen extends StatefulWidget {
  const LectureMeetingsDetailsScreen({
    super.key,
    required this.lecture,
    required this.course,
    this.meetings = const [],
  });

  final LectureModel lecture;
  final CourseModel course;
  final List<MeetingRequest> meetings;

  @override
  State<LectureMeetingsDetailsScreen> createState() =>
      _LectureMeetingsDetailsScreenState();
}

class _LectureMeetingsDetailsScreenState
    extends State<LectureMeetingsDetailsScreen> {
  late LectureMeetingBucket _selected;
  late final TextEditingController _search;
  Stream<List<MeetingRequest>>? _meetingsStream;
  Stream<LectureModel?>? _lectureStream;

  @override
  void initState() {
    super.initState();
    _selected = defaultMeetingBucket(widget.meetings);
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
    if (teacherId.isNotEmpty) {
      _meetingsStream ??= scope.meetingStore.watchTeacherRequests(teacherId);
    }
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  LectureModel _latest(LectureModel? streamed) => streamed ?? widget.lecture;

  List<MeetingRequest> _lectureMeetings(
    List<MeetingRequest> all,
    LectureModel lecture,
  ) {
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
          l10n.meetingsDetailTitle,
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
        ),
      ),
      body: StreamBuilder<LectureModel?>(
        stream: _lectureStream,
        builder: (context, lectureSnap) {
          final lecture = _latest(lectureSnap.data);
          return StreamBuilder<List<MeetingRequest>>(
            stream: _meetingsStream,
            builder: (context, meetingsSnap) {
              final streamed = meetingsSnap.data;
              final all =
                  streamed == null ||
                      (streamed.isEmpty && widget.meetings.isNotEmpty)
                  ? widget.meetings
                  : streamed;
              final meetings = _lectureMeetings(all, lecture);
              final visible = _visible(meetings);
              final started = lecture.startedAt;
              final ended =
                  lecture.endedAt ??
                  started?.add(Duration(minutes: lecture.durationMinutes));
              final pending = _count(meetings, LectureMeetingBucket.pending);
              final scheduled = _count(meetings, LectureMeetingBucket.scheduled);
              final attended = _count(meetings, LectureMeetingBucket.attended);
              final bucketed = pending + scheduled + attended;

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
                    barKeyPrefix: 'meetings-bar',
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
                            ? l10n.noMeetingsForLecture
                            : l10n.noMeetingsInBucket,
                        style: TextStyle(
                          color: AppColors.textSecondary(brightness),
                        ),
                      ),
                    )
                  else
                    for (final meeting in visible)
                      LectureStudentListTile(
                        key: ValueKey<String>('meetings-row-${meeting.id}'),
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
              );
            },
          );
        },
      ),
    );
  }
}
