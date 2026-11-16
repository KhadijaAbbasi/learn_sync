import 'package:cloud_firestore/cloud_firestore.dart';

import 'lecture_join_request.dart';

class CourseJoinRequest {
  const CourseJoinRequest({
    required this.studentId,
    required this.studentName,
    required this.courseId,
    this.courseName = '',
    this.courseCode = '',
    this.studentEmail = '',
    this.memberId = '',
    this.status = JoinRequestStatus.pending,
    this.requestedAt,
    this.respondedAt,
  });

  final String studentId;
  final String studentName;
  final String courseId;
  final String courseName;
  final String courseCode;
  final String studentEmail;
  final String memberId;
  final JoinRequestStatus status;
  final DateTime? requestedAt;
  final DateTime? respondedAt;

  bool get isPending => status == JoinRequestStatus.pending;
  bool get isAccepted => status == JoinRequestStatus.accepted;
  bool get isDeclined => status == JoinRequestStatus.declined;

  factory CourseJoinRequest.fromMap(String id, Map<String, dynamic> data) {
    return CourseJoinRequest(
      studentId: data['studentId'] as String? ?? id,
      studentName: data['studentName'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      courseCode: data['courseCode'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      status: _statusFrom(data['status']),
      requestedAt: _dateFrom(data['requestedAt']),
      respondedAt: _dateFrom(data['respondedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'studentId': studentId,
      'studentName': studentName.trim(),
      'courseId': courseId,
      'courseName': courseName.trim(),
      'courseCode': courseCode.trim(),
      'studentEmail': studentEmail.trim().toLowerCase(),
      'memberId': memberId.trim(),
      'status': JoinRequestStatus.pending.name,
    };
  }

  CourseJoinRequest copyWith({
    JoinRequestStatus? status,
    DateTime? requestedAt,
    DateTime? respondedAt,
  }) {
    return CourseJoinRequest(
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
      studentEmail: studentEmail,
      memberId: memberId,
      status: status ?? this.status,
      requestedAt: requestedAt ?? this.requestedAt,
      respondedAt: respondedAt ?? this.respondedAt,
    );
  }
}

JoinRequestStatus _statusFrom(dynamic value) {
  switch (value) {
    case 'accepted':
      return JoinRequestStatus.accepted;
    case 'declined':
      return JoinRequestStatus.declined;
    default:
      return JoinRequestStatus.pending;
  }
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