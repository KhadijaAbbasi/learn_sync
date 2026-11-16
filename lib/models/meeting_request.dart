import 'package:cloud_firestore/cloud_firestore.dart';

enum MeetingRequestStatus {
  pending,
  accepted,
  declined,
  completed,
  rescheduleRequested,
}

extension MeetingRequestStatusX on MeetingRequestStatus {
  String get storageValue => name;

  static MeetingRequestStatus fromStorage(String? value) {
    switch (value) {
      case 'accepted':
        return MeetingRequestStatus.accepted;
      case 'declined':
        return MeetingRequestStatus.declined;
      case 'completed':
        return MeetingRequestStatus.completed;
      case 'rescheduleRequested':
        return MeetingRequestStatus.rescheduleRequested;
      default:
        return MeetingRequestStatus.pending;
    }
  }
}

class MeetingRequest {
  const MeetingRequest({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
    required this.teacherName,
    required this.courseId,
    required this.courseName,
    required this.topicTitle,
    required this.reason,
    this.studentEmail = '',
    this.memberId = '',
    this.chapterId = '',
    this.chapterTitle = '',
    this.topicId = '',
    this.lectureId = '',
    this.status = MeetingRequestStatus.pending,
    this.teacherNote = '',
    this.rescheduleNote = '',
    this.requestedAt,
    this.scheduledAt,
    this.respondedAt,
    this.completedAt,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String memberId;
  final String teacherId;
  final String teacherName;
  final String courseId;
  final String courseName;
  final String chapterId;
  final String chapterTitle;
  final String topicId;
  final String topicTitle;
  final String lectureId;
  final String reason;
  final MeetingRequestStatus status;
  final String teacherNote;
  final String rescheduleNote;
  final DateTime? requestedAt;
  final DateTime? scheduledAt;
  final DateTime? respondedAt;
  final DateTime? completedAt;

  bool get isPending => status == MeetingRequestStatus.pending;
  bool get isAccepted => status == MeetingRequestStatus.accepted;
  bool get isDeclined => status == MeetingRequestStatus.declined;
  bool get isCompleted => status == MeetingRequestStatus.completed;
  bool get isRescheduleRequested =>
      status == MeetingRequestStatus.rescheduleRequested;
  bool get needsTeacherAction => isPending || isRescheduleRequested;

  bool get canMarkCompleted {
    final scheduled = scheduledAt;
    return isAccepted &&
        scheduled != null &&
        !DateTime.now().isBefore(scheduled);
  }

  factory MeetingRequest.fromMap(String id, Map<String, dynamic> data) {
    return MeetingRequest(
      id: id,
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      chapterId: data['chapterId'] as String? ?? '',
      chapterTitle: data['chapterTitle'] as String? ?? '',
      topicId: data['topicId'] as String? ?? '',
      topicTitle: data['topicTitle'] as String? ?? '',
      lectureId: data['lectureId'] as String? ?? '',
      reason: data['reason'] as String? ?? '',
      status: MeetingRequestStatusX.fromStorage(data['status'] as String?),
      teacherNote: data['teacherNote'] as String? ?? '',
      rescheduleNote: data['rescheduleNote'] as String? ?? '',
      requestedAt: _dateFrom(data['requestedAt']),
      scheduledAt: _dateFrom(data['scheduledAt']),
      respondedAt: _dateFrom(data['respondedAt']),
      completedAt: _dateFrom(data['completedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'studentId': studentId,
      'studentName': studentName.trim(),
      'studentEmail': studentEmail.trim().toLowerCase(),
      'memberId': memberId.trim(),
      'teacherId': teacherId,
      'teacherName': teacherName.trim(),
      'courseId': courseId,
      'courseName': courseName.trim(),
      'chapterId': chapterId,
      'chapterTitle': chapterTitle.trim(),
      'topicId': topicId,
      'topicTitle': topicTitle.trim(),
      if (lectureId.trim().isNotEmpty) 'lectureId': lectureId.trim(),
      'reason': reason.trim(),
      'status': MeetingRequestStatus.pending.storageValue,
      'teacherNote': '',
    };
  }

  MeetingRequest copyWith({
    MeetingRequestStatus? status,
    String? teacherNote,
    String? rescheduleNote,
    DateTime? scheduledAt,
    DateTime? respondedAt,
    DateTime? completedAt,
  }) {
    return MeetingRequest(
      id: id,
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      memberId: memberId,
      teacherId: teacherId,
      teacherName: teacherName,
      courseId: courseId,
      courseName: courseName,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      topicId: topicId,
      topicTitle: topicTitle,
      lectureId: lectureId,
      reason: reason,
      status: status ?? this.status,
      teacherNote: teacherNote ?? this.teacherNote,
      rescheduleNote: rescheduleNote ?? this.rescheduleNote,
      requestedAt: requestedAt,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      respondedAt: respondedAt ?? this.respondedAt,
      completedAt: completedAt ?? this.completedAt,
    );
  }
}

/// Matches a meeting to one lecture. Prefers [lectureId] when stored; otherwise
/// uses course + topic id/title — the best keys available today.
bool meetingMatchesLecture(
  MeetingRequest meeting, {
  required String courseId,
  String lectureId = '',
  String topicId = '',
  String topicTitle = '',
}) {
  final storedLectureId = meeting.lectureId.trim();
  final targetLectureId = lectureId.trim();
  if (storedLectureId.isNotEmpty && targetLectureId.isNotEmpty) {
    return storedLectureId == targetLectureId;
  }
  if (meeting.courseId != courseId) {
    return false;
  }
  if (topicId.isNotEmpty && meeting.topicId == topicId) {
    return true;
  }
  final topic = topicTitle.trim();
  return topic.isNotEmpty &&
      meeting.topicTitle.trim().toLowerCase() == topic.toLowerCase();
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
