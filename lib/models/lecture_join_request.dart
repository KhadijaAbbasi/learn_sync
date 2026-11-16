import 'package:cloud_firestore/cloud_firestore.dart';

enum JoinRequestStatus { pending, accepted, declined }

class LectureJoinRequest {
  const LectureJoinRequest({
    required this.studentId,
    required this.studentName,
    this.studentEmail = '',
    this.memberId = '',
    this.status = JoinRequestStatus.pending,
    this.requestedAt,
    this.respondedAt,
  });

  final String studentId;
  final String studentName;
  final String studentEmail;
  final String memberId;
  final JoinRequestStatus status;
  final DateTime? requestedAt;
  final DateTime? respondedAt;

  bool get isPending => status == JoinRequestStatus.pending;
  bool get isAccepted => status == JoinRequestStatus.accepted;

  factory LectureJoinRequest.fromMap(String id, Map<String, dynamic> data) {
    return LectureJoinRequest(
      studentId: data['studentId'] as String? ?? id,
      studentName: data['studentName'] as String? ?? '',
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
      'studentEmail': studentEmail.trim().toLowerCase(),
      'memberId': memberId.trim(),
      'status': JoinRequestStatus.pending.name,
    };
  }

  LectureJoinRequest copyWith({
    String? studentId,
    String? studentName,
    String? studentEmail,
    String? memberId,
    JoinRequestStatus? status,
    DateTime? requestedAt,
    DateTime? respondedAt,
  }) {
    return LectureJoinRequest(
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      studentEmail: studentEmail ?? this.studentEmail,
      memberId: memberId ?? this.memberId,
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
