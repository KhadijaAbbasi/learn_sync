import 'package:cloud_firestore/cloud_firestore.dart';

enum LectureStatus { active, ended }

/// Students who attended this lecture, with safe fallbacks for missing data.
int resolveLectureAudienceCount({
  required int attendeeRecords,
  required int lectureStudentCount,
  required int responseCount,
}) {
  if (attendeeRecords > 0) {
    return attendeeRecords;
  }
  if (lectureStudentCount > 0) {
    return lectureStudentCount;
  }
  return responseCount;
}

class LectureAttendee {
  const LectureAttendee({
    required this.studentId,
    required this.studentName,
    this.studentEmail = '',
    this.memberId = '',
    this.joinedAt,
    this.inApp = true,
    this.lastSeenAt,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final String memberId;
  final DateTime? joinedAt;
  /// Best-effort: student live screen is in foreground.
  final bool inApp;
  final DateTime? lastSeenAt;

  factory LectureAttendee.fromMap(String id, Map<String, dynamic> data) {
    return LectureAttendee(
      studentId: data['studentId'] as String? ?? id,
      studentName: data['studentName'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      joinedAt: _dateFrom(data['joinedAt']),
      inApp: data['inApp'] as bool? ?? true,
      lastSeenAt: _dateFrom(data['lastSeenAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'studentId': studentId,
      'studentName': studentName.trim(),
      'studentEmail': studentEmail.trim().toLowerCase(),
      'memberId': memberId.trim(),
      'inApp': inApp,
    };
  }

  LectureAttendee copyWith({
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? memberId,
    DateTime? joinedAt,
    bool? inApp,
    DateTime? lastSeenAt,
  }) {
    return LectureAttendee(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      memberId: memberId ?? this.memberId,
      joinedAt: joinedAt ?? this.joinedAt,
      inApp: inApp ?? this.inApp,
      lastSeenAt: lastSeenAt ?? this.lastSeenAt,
    );
  }
}

class LectureSummary {
  const LectureSummary({
    required this.lectureId,
    required this.sessionId,
    required this.courseId,
    required this.courseName,
    required this.teacherId,
    this.courseCode = '',
    this.department = '',
    this.semester = '',
    this.section = '',
    this.teacherName = '',
    this.chapterId = '',
    this.chapterTitle = '',
    this.topicId = '',
    this.topicTitle = '',
    this.durationMinutes = 0,
    this.actualDurationMinutes = 0,
    this.attendeeCount = 0,
    this.lectureDate = '',
    this.taughtNotes = '',
    this.savedAt,
  });

  final String lectureId;
  final String sessionId;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String department;
  final String semester;
  final String section;
  final String teacherId;
  final String teacherName;
  final String chapterId;
  final String chapterTitle;
  final String topicId;
  final String topicTitle;
  final int durationMinutes;
  final int actualDurationMinutes;
  final int attendeeCount;
  final String lectureDate;
  final String taughtNotes;
  final DateTime? savedAt;

  factory LectureSummary.fromMap(
    Map<String, dynamic> data, {
    String lectureId = '',
  }) {
    final id = data['lectureId'] as String? ?? lectureId;
    return LectureSummary(
      lectureId: id,
      sessionId: data['sessionId'] as String? ?? id,
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      courseCode: data['courseCode'] as String? ?? '',
      department: data['department'] as String? ?? '',
      semester: data['semester'] as String? ?? '',
      section: data['section'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      chapterId: data['chapterId'] as String? ?? '',
      chapterTitle: data['chapterTitle'] as String? ?? '',
      topicId: data['topicId'] as String? ?? '',
      topicTitle: data['topicTitle'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      actualDurationMinutes:
          (data['actualDurationMinutes'] as num?)?.toInt() ?? 0,
      attendeeCount: (data['attendeeCount'] as num?)?.toInt() ?? 0,
      lectureDate: data['lectureDate'] as String? ?? '',
      taughtNotes: data['taughtNotes'] as String? ?? '',
      savedAt: _dateFrom(data['savedAt']),
    );
  }

  factory LectureSummary.fromLecture(
    LectureModel lecture, {
    String courseCode = '',
    String department = '',
    String semester = '',
    String section = '',
    int? attendeeCount,
    int? actualDurationMinutes,
    String? taughtNotes,
  }) {
    return LectureSummary(
      lectureId: lecture.id,
      sessionId: lecture.id,
      courseId: lecture.courseId,
      courseName: lecture.courseName,
      courseCode: courseCode,
      department: department,
      semester: semester,
      section: section,
      teacherId: lecture.teacherId,
      teacherName: lecture.teacherName,
      chapterId: lecture.chapterId,
      chapterTitle: lecture.chapterTitle,
      topicId: lecture.topicId,
      topicTitle: lecture.topicTitle,
      durationMinutes: lecture.durationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? lecture.actualDurationMinutes,
      attendeeCount: attendeeCount ?? lecture.studentCount,
      lectureDate: lecture.lectureDate,
      taughtNotes: taughtNotes ?? lecture.resolvedTaughtNotes,
      savedAt: lecture.summary?.savedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'lectureId': lectureId,
      'sessionId': sessionId,
      'courseId': courseId,
      'courseName': courseName.trim(),
      'courseCode': courseCode.trim(),
      'department': department.trim(),
      'semester': semester.trim(),
      'section': section.trim(),
      'teacherId': teacherId,
      'teacherName': teacherName.trim(),
      'chapterId': chapterId,
      'chapterTitle': chapterTitle.trim(),
      'topicId': topicId,
      'topicTitle': topicTitle.trim(),
      'durationMinutes': durationMinutes,
      'actualDurationMinutes': actualDurationMinutes,
      'attendeeCount': attendeeCount,
      'lectureDate': lectureDate,
      'taughtNotes': taughtNotes.trim(),
    };
  }

  LectureSummary copyWith({
    String? lectureId,
    String? sessionId,
    String? courseId,
    String? courseName,
    String? courseCode,
    String? department,
    String? semester,
    String? section,
    String? teacherId,
    String? teacherName,
    String? chapterId,
    String? chapterTitle,
    String? topicId,
    String? topicTitle,
    int? durationMinutes,
    int? actualDurationMinutes,
    int? attendeeCount,
    String? lectureDate,
    String? taughtNotes,
    DateTime? savedAt,
  }) {
    return LectureSummary(
      lectureId: lectureId ?? this.lectureId,
      sessionId: sessionId ?? this.sessionId,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      department: department ?? this.department,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      topicId: topicId ?? this.topicId,
      topicTitle: topicTitle ?? this.topicTitle,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      attendeeCount: attendeeCount ?? this.attendeeCount,
      lectureDate: lectureDate ?? this.lectureDate,
      taughtNotes: taughtNotes ?? this.taughtNotes,
      savedAt: savedAt ?? this.savedAt,
    );
  }
}

class LectureModel {
  const LectureModel({
    required this.id,
    required this.courseId,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.chapterId,
    required this.chapterTitle,
    required this.topicId,
    required this.topicTitle,
    required this.durationMinutes,
    this.status = LectureStatus.active,
    this.startedAt,
    this.endedAt,
    this.actualDurationMinutes = 0,
    this.studentCount = 0,
    this.lectureDate = '',
    this.taughtNotes = '',
    this.summary,
  });

  final String id;
  final String courseId;
  final String courseName;
  final String teacherId;
  final String teacherName;
  final String chapterId;
  final String chapterTitle;
  final String topicId;
  final String topicTitle;
  final int durationMinutes;
  final LectureStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  final int actualDurationMinutes;
  final int studentCount;
  final String lectureDate;
  final String taughtNotes;
  final LectureSummary? summary;

  bool get isActive => status == LectureStatus.active;

  String get resolvedTaughtNotes {
    final top = taughtNotes.trim();
    if (top.isNotEmpty) {
      return top;
    }
    return summary?.taughtNotes.trim() ?? '';
  }

  factory LectureModel.fromMap(String id, Map<String, dynamic> data) {
    return LectureModel(
      id: id,
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      chapterId: data['chapterId'] as String? ?? '',
      chapterTitle: data['chapterTitle'] as String? ?? '',
      topicId: data['topicId'] as String? ?? '',
      topicTitle: data['topicTitle'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      status: data['status'] == 'ended'
          ? LectureStatus.ended
          : LectureStatus.active,
      startedAt: _dateFrom(data['startedAt']),
      endedAt: _dateFrom(data['endedAt']),
      actualDurationMinutes:
          (data['actualDurationMinutes'] as num?)?.toInt() ?? 0,
      studentCount: (data['studentCount'] as num?)?.toInt() ?? 0,
      lectureDate: data['lectureDate'] as String? ?? '',
      taughtNotes: data['taughtNotes'] as String? ?? '',
      summary: _summaryFrom(data['summary'], id),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'courseId': courseId,
      'courseName': courseName.trim(),
      'teacherId': teacherId,
      'teacherName': teacherName.trim(),
      'chapterId': chapterId,
      'chapterTitle': chapterTitle.trim(),
      'topicId': topicId,
      'topicTitle': topicTitle.trim(),
      'durationMinutes': durationMinutes,
      'status': LectureStatus.active.name,
      'studentCount': 0,
      'actualDurationMinutes': 0,
      'lectureDate': lectureDate,
      'sessionId': id,
    };
  }

  LectureModel copyWith({
    String? id,
    String? courseId,
    String? courseName,
    String? teacherId,
    String? teacherName,
    String? chapterId,
    String? chapterTitle,
    String? topicId,
    String? topicTitle,
    int? durationMinutes,
    LectureStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? actualDurationMinutes,
    int? studentCount,
    String? lectureDate,
    String? taughtNotes,
    LectureSummary? summary,
  }) {
    return LectureModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      courseName: courseName ?? this.courseName,
      teacherId: teacherId ?? this.teacherId,
      teacherName: teacherName ?? this.teacherName,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      topicId: topicId ?? this.topicId,
      topicTitle: topicTitle ?? this.topicTitle,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      actualDurationMinutes:
          actualDurationMinutes ?? this.actualDurationMinutes,
      studentCount: studentCount ?? this.studentCount,
      lectureDate: lectureDate ?? this.lectureDate,
      taughtNotes: taughtNotes ?? this.taughtNotes,
      summary: summary ?? this.summary,
    );
  }
}

LectureSummary? _summaryFrom(dynamic value, String lectureId) {
  if (value is Map) {
    return LectureSummary.fromMap(
      Map<String, dynamic>.from(value),
      lectureId: lectureId,
    );
  }
  return null;
}

DateTime? _dateFrom(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}

String lectureDateKey(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');
  return '${date.year}-$month-$day';
}
