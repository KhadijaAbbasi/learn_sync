import 'ai_practice.dart';
import 'lecture_feedback.dart';
import 'lecture_model.dart';
import 'meeting_request.dart';

const kTeacherAnalyticsReadLimit = 400;
const kTeacherAnalyticsAttendeeLectureCap = 20;
const kTeacherAnalyticsPracticeLectureCap = 20;
const kTeacherAnalyticsDrillDownLimit = 20;

enum TeacherAnalyticsDateRange { all, last7, last30, custom }

class TeacherAnalyticsFilter {
  const TeacherAnalyticsFilter({
    this.courseId = '',
    this.chapterId = '',
    this.topicId = '',
    this.dateRange = TeacherAnalyticsDateRange.all,
    this.customStart,
    this.customEnd,
  });

  final String courseId;
  final String chapterId;
  final String topicId;
  final TeacherAnalyticsDateRange dateRange;
  final DateTime? customStart;
  final DateTime? customEnd;

  TeacherAnalyticsFilter copyWith({
    String? courseId,
    String? chapterId,
    String? topicId,
    TeacherAnalyticsDateRange? dateRange,
    DateTime? customStart,
    DateTime? customEnd,
    bool clearChapter = false,
    bool clearTopic = false,
    bool clearCustomDates = false,
  }) {
    return TeacherAnalyticsFilter(
      courseId: courseId ?? this.courseId,
      chapterId: clearChapter ? '' : (chapterId ?? this.chapterId),
      topicId: clearTopic ? '' : (topicId ?? this.topicId),
      dateRange: dateRange ?? this.dateRange,
      customStart: clearCustomDates ? null : (customStart ?? this.customStart),
      customEnd: clearCustomDates ? null : (customEnd ?? this.customEnd),
    );
  }
}

class AnalyticsNamedBar {
  const AnalyticsNamedBar({
    required this.id,
    required this.label,
    required this.average,
    required this.count,
    this.subtitle = '',
  });

  final String id;
  final String label;
  final double average;
  final int count;
  final String subtitle;
}

class PracticeOverview {
  const PracticeOverview({
    this.participants = 0,
    this.completions = 0,
    this.attendeeCount = 0,
    this.averageScore = 0,
    this.attemptCount = 0,
  });

  final int participants;
  final int completions;
  final int attendeeCount;
  final double averageScore;
  final int attemptCount;

  int get participationPercent =>
      attendeeCount == 0 ? 0 : ((participants / attendeeCount) * 100).round();

  int get completionPercent =>
      attendeeCount == 0 ? 0 : ((completions / attendeeCount) * 100).round();
}

class MeetingStatusCounts {
  const MeetingStatusCounts({
    this.pending = 0,
    this.accepted = 0,
    this.declined = 0,
    this.completed = 0,
    this.rescheduleRequested = 0,
  });

  final int pending;
  final int accepted;
  final int declined;
  final int completed;
  final int rescheduleRequested;

  int get total =>
      pending + accepted + declined + completed + rescheduleRequested;

  factory MeetingStatusCounts.fromList(List<MeetingRequest> items) {
    var pending = 0;
    var accepted = 0;
    var declined = 0;
    var completed = 0;
    var reschedule = 0;
    for (final item in items) {
      switch (item.status) {
        case MeetingRequestStatus.pending:
          pending++;
        case MeetingRequestStatus.accepted:
          accepted++;
        case MeetingRequestStatus.declined:
          declined++;
        case MeetingRequestStatus.completed:
          completed++;
        case MeetingRequestStatus.rescheduleRequested:
          reschedule++;
      }
    }
    return MeetingStatusCounts(
      pending: pending,
      accepted: accepted,
      declined: declined,
      completed: completed,
      rescheduleRequested: reschedule,
    );
  }
}

class StudentSupportRow {
  const StudentSupportRow({
    required this.studentId,
    required this.studentName,
    required this.detail,
    this.topicTitle = '',
    this.courseName = '',
  });

  final String studentId;
  final String studentName;
  final String detail;
  final String topicTitle;
  final String courseName;
}


class StudentAnalyticsRow {
  const StudentAnalyticsRow({
    required this.studentId,
    required this.studentName,
    this.understandingPercent,
    this.practicePercent,
    this.hasMeetingRequest = false,
    this.needsAttention = false,
  });

  final String studentId;
  final String studentName;
  final double? understandingPercent;
  final double? practicePercent;
  final bool hasMeetingRequest;
  final bool needsAttention;
}

class AnalyticsFilterOption {
  const AnalyticsFilterOption({required this.id, required this.label});

  final String id;
  final String label;
}

class TeacherAnalyticsReport {
  const TeacherAnalyticsReport({
    required this.understanding,
    required this.understandingAverage,
    required this.practice,
    required this.meetings,
    required this.byTopic,
    required this.bySession,
    required this.lowUnderstanding,
    required this.incompletePractice,
    required this.pendingMeetings,
    required this.courseOptions,
    required this.chapterOptions,
    required this.topicOptions,
    required this.lectureCount,
    this.uniqueStudentCount = 0,
    this.studentRows = const [],
  });

  final LectureFeedbackCounts understanding;
  final double understandingAverage;
  final PracticeOverview practice;
  final MeetingStatusCounts meetings;
  final List<AnalyticsNamedBar> byTopic;
  final List<AnalyticsNamedBar> bySession;
  final List<StudentSupportRow> lowUnderstanding;
  final List<StudentSupportRow> incompletePractice;
  final List<StudentSupportRow> pendingMeetings;
  final List<AnalyticsFilterOption> courseOptions;
  final List<AnalyticsFilterOption> chapterOptions;
  final List<AnalyticsFilterOption> topicOptions;
  final int lectureCount;
  /// Distinct students across filtered lectures (attendees + feedback).
  final int uniqueStudentCount;
  final List<StudentAnalyticsRow> studentRows;


  /// Keeps filter dropdown options but zeroes all metrics until a course
  /// is selected (chapter/topic then narrow the same combined report).
  TeacherAnalyticsReport zeroedMetrics() {
    return TeacherAnalyticsReport(
      understanding: const LectureFeedbackCounts(),
      understandingAverage: 0,
      practice: const PracticeOverview(),
      meetings: const MeetingStatusCounts(),
      byTopic: const [],
      bySession: const [],
      lowUnderstanding: const [],
      incompletePractice: const [],
      pendingMeetings: const [],
      courseOptions: courseOptions,
      chapterOptions: chapterOptions,
      topicOptions: topicOptions,
      lectureCount: 0,
      uniqueStudentCount: 0,
      studentRows: const [],
    );
  }

  bool get isEmpty =>
      understanding.total == 0 &&
      practice.attemptCount == 0 &&
      meetings.total == 0 &&
      lectureCount == 0;
}

class TeacherAnalyticsInputs {
  const TeacherAnalyticsInputs({
    required this.lectures,
    required this.feedback,
    required this.attempts,
    required this.meetings,
    this.attendeesByLecture = const {},
    this.courses = const [],
  });

  final List<LectureModel> lectures;
  final List<LectureFeedback> feedback;
  final List<AiPracticeAttempt> attempts;
  final List<MeetingRequest> meetings;
  final Map<String, List<LectureAttendee>> attendeesByLecture;
  final List<({String id, String name})> courses;
}

int understandingPoints(UnderstandingLevel level) {
  switch (level) {
    case UnderstandingLevel.percent100:
      return 100;
    case UnderstandingLevel.percent80:
      return 80;
    case UnderstandingLevel.percent60:
      return 60;
    case UnderstandingLevel.below50:
      return 40;
  }
}

bool isLowUnderstanding(UnderstandingLevel level) {
  return level == UnderstandingLevel.percent60 ||
      level == UnderstandingLevel.below50;
}

DateTime? analyticsRangeStart(TeacherAnalyticsFilter filter, DateTime now) {
  switch (filter.dateRange) {
    case TeacherAnalyticsDateRange.all:
      return null;
    case TeacherAnalyticsDateRange.last7:
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 6));
    case TeacherAnalyticsDateRange.last30:
      return DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(const Duration(days: 29));
    case TeacherAnalyticsDateRange.custom:
      final start = filter.customStart;
      if (start == null) {
        return null;
      }
      return DateTime(start.year, start.month, start.day);
  }
}

DateTime? analyticsRangeEnd(TeacherAnalyticsFilter filter, DateTime now) {
  switch (filter.dateRange) {
    case TeacherAnalyticsDateRange.all:
    case TeacherAnalyticsDateRange.last7:
    case TeacherAnalyticsDateRange.last30:
      return DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
    case TeacherAnalyticsDateRange.custom:
      final end = filter.customEnd ?? filter.customStart ?? now;
      return DateTime(end.year, end.month, end.day, 23, 59, 59, 999);
  }
}

bool dateInAnalyticsRange(
  DateTime? value,
  TeacherAnalyticsFilter filter,
  DateTime now,
) {
  if (filter.dateRange == TeacherAnalyticsDateRange.all) {
    return true;
  }
  if (value == null) {
    return false;
  }
  final start = analyticsRangeStart(filter, now);
  final end = analyticsRangeEnd(filter, now);
  if (start != null && value.isBefore(start)) {
    return false;
  }
  if (end != null && value.isAfter(end)) {
    return false;
  }
  return true;
}

bool lectureMatchesFilter(
  LectureModel lecture,
  TeacherAnalyticsFilter filter,
  DateTime now,
) {
  if (filter.courseId.isNotEmpty && lecture.courseId != filter.courseId) {
    return false;
  }
  if (filter.chapterId.isNotEmpty && lecture.chapterId != filter.chapterId) {
    return false;
  }
  if (filter.topicId.isNotEmpty && lecture.topicId != filter.topicId) {
    return false;
  }
  return dateInAnalyticsRange(
    lecture.endedAt ?? lecture.startedAt,
    filter,
    now,
  );
}

bool meetingMatchesFilter(
  MeetingRequest meeting,
  TeacherAnalyticsFilter filter,
  DateTime now,
) {
  if (filter.courseId.isNotEmpty && meeting.courseId != filter.courseId) {
    return false;
  }
  if (filter.chapterId.isNotEmpty &&
      meeting.chapterId.isNotEmpty &&
      meeting.chapterId != filter.chapterId) {
    return false;
  }
  if (filter.topicId.isNotEmpty &&
      meeting.topicId.isNotEmpty &&
      meeting.topicId != filter.topicId) {
    return false;
  }
  return dateInAnalyticsRange(meeting.requestedAt, filter, now);
}

TeacherAnalyticsReport aggregateTeacherAnalytics(
  TeacherAnalyticsInputs inputs,
  TeacherAnalyticsFilter filter, {
  DateTime? now,
  String Function(UnderstandingLevel level)? lowLevelLabel,
}) {
  final clock = now ?? DateTime.now();
  final lectures = [
    for (final lecture in inputs.lectures)
      if (lectureMatchesFilter(lecture, filter, clock)) lecture,
  ];
  final lectureIds = {for (final lecture in lectures) lecture.id};
  final feedback = [
    for (final item in inputs.feedback)
      if (lectureIds.contains(item.lectureId)) item,
  ];
  final attempts = [
    for (final item in inputs.attempts)
      if (lectureIds.contains(item.lectureId)) item,
  ];
  final meetings = [
    for (final item in inputs.meetings)
      if (meetingMatchesFilter(item, filter, clock)) item,
  ];

  final counts = LectureFeedbackCounts.fromList(feedback);
  var scoreSum = 0;
  for (final item in feedback) {
    scoreSum += understandingPoints(item.level);
  }
  final understandingAverage = counts.total == 0
      ? 0.0
      : scoreSum / counts.total;

  var scoreTotal = 0;
  var scoreCount = 0;
  for (final attempt in attempts) {
    if (attempt.completed) {
      scoreTotal += attempt.percent;
      scoreCount++;
    }
  }

  // Unique students across lectures so topic/course filters do not double-count.
  final uniqueAttendeeIds = <String>{};
  final attendeeNames = <String, String>{};
  var fallbackAttendeeCount = 0;
  for (final lecture in lectures) {
    final loaded = inputs.attendeesByLecture[lecture.id];
    if (loaded != null && loaded.isNotEmpty) {
      for (final attendee in loaded) {
        final id = attendee.studentId.trim();
        if (id.isEmpty) {
          continue;
        }
        uniqueAttendeeIds.add(id);
        attendeeNames.putIfAbsent(
          id,
          () => attendee.studentName.trim().isEmpty ? id : attendee.studentName.trim(),
        );
      }
    } else {
      fallbackAttendeeCount += lecture.studentCount;
    }
  }
  final attendeeCount = uniqueAttendeeIds.length + fallbackAttendeeCount;

  final participants = {
    for (final attempt in attempts)
      if (attempt.studentId.isNotEmpty) attempt.studentId,
  }.length;

  final practice = PracticeOverview(
    participants: participants,
    completions: {
      for (final attempt in attempts)
        if (attempt.completed && attempt.studentId.isNotEmpty)
          attempt.studentId,
    }.length,
    attendeeCount: attendeeCount,
    averageScore: scoreCount == 0 ? 0 : scoreTotal / scoreCount,
    attemptCount: attempts.length,
  );

  final byTopic = _barsByKey(
    feedback,
    keyOf: (item) => item.topicId.isNotEmpty ? item.topicId : item.topicTitle,
    labelOf: (item) =>
        item.topicTitle.trim().isEmpty ? item.topicId : item.topicTitle.trim(),
    subtitleOf: (item) => item.courseName,
  );
  final bySession = _barsByKey(
    feedback,
    keyOf: (item) => item.lectureId,
    labelOf: (item) => item.topicTitle.trim().isEmpty
        ? item.lectureId
        : item.topicTitle.trim(),
    subtitleOf: (item) {
      final chapter = item.chapterTitle.trim();
      final course = item.courseName.trim();
      if (chapter.isNotEmpty && course.isNotEmpty) {
        return '$course · $chapter';
      }
      return course.isNotEmpty ? course : chapter;
    },
  );

  final levelLabel =
      lowLevelLabel ??
      (UnderstandingLevel level) => switch (level) {
        UnderstandingLevel.percent60 => '60%',
        UnderstandingLevel.below50 => 'Below 50%',
        UnderstandingLevel.percent80 => '80%',
        UnderstandingLevel.percent100 => '100%',
      };

  final lowUnderstanding = <StudentSupportRow>[
    for (final item in feedback)
      if (isLowUnderstanding(item.level))
        StudentSupportRow(
          studentId: item.studentId,
          studentName: item.studentName,
          detail: levelLabel(item.level),
          topicTitle: item.topicTitle,
          courseName: item.courseName,
        ),
  ];
  lowUnderstanding.sort((a, b) => a.studentName.compareTo(b.studentName));

  final practicedStudents = {
    for (final attempt in attempts)
      if (attempt.studentId.isNotEmpty) attempt.studentId,
  };
  final incomplete = <StudentSupportRow>[];
  final seenIncomplete = <String>{};
  final incompleteCandidates = <String, ({String id, String name, String topic, String course})>{};
  for (final lecture in lectures) {
    final attendees = inputs.attendeesByLecture[lecture.id];
    final candidates = <({String id, String name})>[
      if (attendees != null)
        for (final attendee in attendees)
          (id: attendee.studentId, name: attendee.studentName),
      if (attendees == null || attendees.isEmpty)
        for (final item in feedback)
          if (item.lectureId == lecture.id)
            (id: item.studentId, name: item.studentName),
    ];
    for (final student in candidates) {
      final id = student.id.trim();
      if (id.isEmpty || practicedStudents.contains(id)) {
        continue;
      }
      incompleteCandidates.putIfAbsent(
        id,
        () => (
          id: id,
          name: student.name,
          topic: lecture.topicTitle,
          course: lecture.courseName,
        ),
      );
    }
  }
  for (final student in incompleteCandidates.values) {
    if (!seenIncomplete.add(student.id)) {
      continue;
    }
    incomplete.add(
      StudentSupportRow(
        studentId: student.id,
        studentName: student.name,
        detail: student.topic,
        topicTitle: student.topic,
        courseName: student.course,
      ),
    );
  }
  incomplete.sort((a, b) => a.studentName.compareTo(b.studentName));

  final pending = [
    for (final item in meetings)
      if (item.needsTeacherAction)
        StudentSupportRow(
          studentId: item.studentId,
          studentName: item.studentName,
          detail: item.topicTitle,
          topicTitle: item.topicTitle,
          courseName: item.courseName,
        ),
  ];

  final courseOptions = [
    for (final course in inputs.courses)
      AnalyticsFilterOption(id: course.id, label: course.name),
  ];
  if (courseOptions.isEmpty) {
    final seen = <String>{};
    for (final lecture in inputs.lectures) {
      if (lecture.courseId.isEmpty || !seen.add(lecture.courseId)) {
        continue;
      }
      courseOptions.add(
        AnalyticsFilterOption(
          id: lecture.courseId,
          label: lecture.courseName.isEmpty
              ? lecture.courseId
              : lecture.courseName,
        ),
      );
    }
  }

  final scopedForChapter = [
    for (final lecture in inputs.lectures)
      if (filter.courseId.isEmpty || lecture.courseId == filter.courseId)
        lecture,
  ];
  final chapterOptions = _uniqueOptions(
    scopedForChapter,
    idOf: (lecture) => lecture.chapterId,
    labelOf: (lecture) => lecture.chapterTitle,
  );
  final scopedForTopic = [
    for (final lecture in scopedForChapter)
      if (filter.chapterId.isEmpty || lecture.chapterId == filter.chapterId)
        lecture,
  ];
  final topicOptions = _uniqueOptions(
    scopedForTopic,
    idOf: (lecture) => lecture.topicId,
    labelOf: (lecture) => lecture.topicTitle,
  );

  // Per-student rollups across all matching lectures (topic combined view).
  final feedbackByStudent = <String, List<LectureFeedback>>{};
  for (final item in feedback) {
    final id = item.studentId.trim();
    if (id.isEmpty) {
      continue;
    }
    feedbackByStudent.putIfAbsent(id, () => <LectureFeedback>[]).add(item);
    attendeeNames.putIfAbsent(
      id,
      () => item.studentName.trim().isEmpty ? id : item.studentName.trim(),
    );
    uniqueAttendeeIds.add(id);
  }
  final practiceBest = <String, int>{};
  for (final attempt in attempts) {
    final id = attempt.studentId.trim();
    if (id.isEmpty) {
      continue;
    }
    attendeeNames.putIfAbsent(
      id,
      () => attempt.studentName.trim().isEmpty ? id : attempt.studentName.trim(),
    );
    uniqueAttendeeIds.add(id);
    final prev = practiceBest[id];
    if (prev == null || attempt.percent > prev) {
      practiceBest[id] = attempt.percent;
    }
  }
  final meetingStudentIds = {
    for (final item in meetings)
      if (item.studentId.isNotEmpty) item.studentId,
  };
  final pendingMeetingIds = {
    for (final item in meetings)
      if (item.needsTeacherAction && item.studentId.isNotEmpty) item.studentId,
  };

  final studentRows = <StudentAnalyticsRow>[];
  for (final id in {...uniqueAttendeeIds, ...feedbackByStudent.keys, ...practiceBest.keys}) {
    final fb = feedbackByStudent[id];
    double? understandingPct;
    if (fb != null && fb.isNotEmpty) {
      final sum = fb.fold<int>(0, (s, e) => s + understandingPoints(e.level));
      understandingPct = sum / fb.length;
    }
    final practicePct = practiceBest[id]?.toDouble();
    final hasMeeting = meetingStudentIds.contains(id);
    final needsAttention =
        (understandingPct != null && understandingPct < 70) ||
        pendingMeetingIds.contains(id) ||
        (practicePct == null && uniqueAttendeeIds.contains(id));
    studentRows.add(
      StudentAnalyticsRow(
        studentId: id,
        studentName: attendeeNames[id] ?? id,
        understandingPercent: understandingPct,
        practicePercent: practicePct,
        hasMeetingRequest: hasMeeting,
        needsAttention: needsAttention,
      ),
    );
  }
  studentRows.sort((a, b) {
    if (a.needsAttention != b.needsAttention) {
      return a.needsAttention ? -1 : 1;
    }
    return a.studentName.compareTo(b.studentName);
  });

  return TeacherAnalyticsReport(
    understanding: counts,
    understandingAverage: understandingAverage,
    practice: practice,
    meetings: MeetingStatusCounts.fromList(meetings),
    byTopic: byTopic,
    bySession: bySession,
    lowUnderstanding: lowUnderstanding
        .take(kTeacherAnalyticsDrillDownLimit)
        .toList(),
    incompletePractice: incomplete
        .take(kTeacherAnalyticsDrillDownLimit)
        .toList(),
    pendingMeetings: pending.take(kTeacherAnalyticsDrillDownLimit).toList(),
    courseOptions: courseOptions,
    chapterOptions: chapterOptions,
    topicOptions: topicOptions,
    lectureCount: lectures.length,
    uniqueStudentCount: uniqueAttendeeIds.length + fallbackAttendeeCount,
    studentRows: studentRows.take(kTeacherAnalyticsDrillDownLimit * 2).toList(),
  );
}

List<AnalyticsNamedBar> _barsByKey(
  List<LectureFeedback> feedback, {
  required String Function(LectureFeedback item) keyOf,
  required String Function(LectureFeedback item) labelOf,
  required String Function(LectureFeedback item) subtitleOf,
}) {
  final sums = <String, double>{};
  final counts = <String, int>{};
  final labels = <String, String>{};
  final subtitles = <String, String>{};
  for (final item in feedback) {
    final key = keyOf(item);
    if (key.isEmpty) {
      continue;
    }
    sums[key] = (sums[key] ?? 0) + understandingPoints(item.level);
    counts[key] = (counts[key] ?? 0) + 1;
    labels[key] = labelOf(item);
    subtitles[key] = subtitleOf(item);
  }
  final bars =
      [
        for (final key in sums.keys)
          AnalyticsNamedBar(
            id: key,
            label: labels[key] ?? key,
            average: sums[key]! / counts[key]!,
            count: counts[key]!,
            subtitle: subtitles[key] ?? '',
          ),
      ]..sort((a, b) {
        final byAverage = a.average.compareTo(b.average);
        if (byAverage != 0) {
          return byAverage;
        }
        return a.label.compareTo(b.label);
      });
  return bars;
}

List<AnalyticsFilterOption> _uniqueOptions(
  List<LectureModel> lectures, {
  required String Function(LectureModel lecture) idOf,
  required String Function(LectureModel lecture) labelOf,
}) {
  final seen = <String>{};
  final options = <AnalyticsFilterOption>[];
  for (final lecture in lectures) {
    final id = idOf(lecture);
    if (id.isEmpty || !seen.add(id)) {
      continue;
    }
    final label = labelOf(lecture).trim();
    options.add(
      AnalyticsFilterOption(id: id, label: label.isEmpty ? id : label),
    );
  }
  options.sort((a, b) => a.label.compareTo(b.label));
  return options;
}
