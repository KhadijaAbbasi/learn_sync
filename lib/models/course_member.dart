import 'package:cloud_firestore/cloud_firestore.dart';

/// A student enrolled in a course (`courses/{id}/members/{uid}`).
class CourseMember {
  const CourseMember({
    required this.studentId,
    required this.studentName,
    this.studentEmail = '',
    this.memberId = '',
    this.courseId = '',
    this.joinedAt,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final String memberId;
  final String courseId;
  final DateTime? joinedAt;

  factory CourseMember.fromMap(String id, Map<String, dynamic> data) {
    return CourseMember(
      studentId: data['studentId'] as String? ?? id,
      studentName: data['studentName'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      joinedAt: _dateFrom(data['joinedAt']),
    );
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
