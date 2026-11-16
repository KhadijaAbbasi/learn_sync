import 'package:cloud_firestore/cloud_firestore.dart';

import 'lecture_feedback.dart';

/// Live, per-slide understanding note from a student during an active session.
class LiveSlideSignal {
  const LiveSlideSignal({
    required this.id,
    required this.sessionId,
    required this.courseId,
    required this.teacherId,
    required this.studentId,
    required this.studentName,
    required this.level,
    this.studentEmail = '',
    this.memberId = '',
    this.slideFileIndex = 0,
    this.slidePage = 1,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String sessionId;
  final String courseId;
  final String teacherId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String memberId;
  final int slideFileIndex;
  final int slidePage;
  final UnderstandingLevel level;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String docId({
    required String studentId,
    required int fileIndex,
    required int page,
  }) {
    final safeFile = fileIndex < 0 ? 0 : fileIndex;
    final safePage = page < 1 ? 1 : page;
    return '${studentId}_${safeFile}_$safePage';
  }

  factory LiveSlideSignal.fromMap(String id, Map<String, dynamic> data) {
    return LiveSlideSignal(
      id: id,
      sessionId: data['sessionId'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      slideFileIndex: (data['slideFileIndex'] as num?)?.toInt() ?? 0,
      slidePage: (data['slidePage'] as num?)?.toInt() ?? 1,
      level: UnderstandingLevelX.fromStorage(data['level'] as String?),
      createdAt: _dateFrom(data['createdAt']),
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }

  Map<String, dynamic> toWriteMap() {
    return {
      'sessionId': sessionId,
      'courseId': courseId,
      'teacherId': teacherId,
      'studentId': studentId,
      'studentName': studentName.trim(),
      'studentEmail': studentEmail.trim().toLowerCase(),
      'memberId': memberId.trim(),
      'slideFileIndex': slideFileIndex < 0 ? 0 : slideFileIndex,
      'slidePage': slidePage < 1 ? 1 : slidePage,
      'level': level.storageValue,
    };
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
