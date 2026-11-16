import 'package:cloud_firestore/cloud_firestore.dart';

enum UnderstandingLevel {
  percent100,
  percent80,
  percent60,
  below50,
}

extension UnderstandingLevelX on UnderstandingLevel {
  String get storageValue {
    switch (this) {
      case UnderstandingLevel.percent100:
        return '100';
      case UnderstandingLevel.percent80:
        return '80';
      case UnderstandingLevel.percent60:
        return '60';
      case UnderstandingLevel.below50:
        return 'below50';
    }
  }

  static UnderstandingLevel fromStorage(String? value) {
    switch (value) {
      case '100':
        return UnderstandingLevel.percent100;
      case '80':
        return UnderstandingLevel.percent80;
      case '60':
        return UnderstandingLevel.percent60;
      default:
        return UnderstandingLevel.below50;
    }
  }
}

class LectureFeedback {
  const LectureFeedback({
    required this.id,
    required this.lectureId,
    required this.sessionId,
    required this.courseId,
    required this.courseName,
    required this.teacherId,
    required this.teacherName,
    required this.studentId,
    required this.studentName,
    required this.level,
    this.studentEmail = '',
    this.memberId = '',
    this.chapterId = '',
    this.chapterTitle = '',
    this.topicId = '',
    this.topicTitle = '',
    this.comment = '',
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String lectureId;
  final String sessionId;
  final String courseId;
  final String courseName;
  final String teacherId;
  final String teacherName;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String memberId;
  final String chapterId;
  final String chapterTitle;
  final String topicId;
  final String topicTitle;
  final UnderstandingLevel level;
  final String comment;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  static String docId(String lectureId, String studentId) =>
      '${lectureId}_$studentId';

  factory LectureFeedback.fromMap(String id, Map<String, dynamic> data) {
    return LectureFeedback(
      id: id,
      lectureId: data['lectureId'] as String? ?? '',
      sessionId: data['sessionId'] as String? ?? data['lectureId'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      studentEmail: data['studentEmail'] as String? ?? '',
      memberId: data['memberId'] as String? ?? '',
      chapterId: data['chapterId'] as String? ?? '',
      chapterTitle: data['chapterTitle'] as String? ?? '',
      topicId: data['topicId'] as String? ?? '',
      topicTitle: data['topicTitle'] as String? ?? '',
      level: UnderstandingLevelX.fromStorage(data['level'] as String?),
      comment: data['comment'] as String? ?? '',
      createdAt: _dateFrom(data['createdAt']),
      updatedAt: _dateFrom(data['updatedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'lectureId': lectureId,
      'sessionId': sessionId,
      'courseId': courseId,
      'courseName': courseName.trim(),
      'teacherId': teacherId,
      'teacherName': teacherName.trim(),
      'studentId': studentId,
      'studentName': studentName.trim(),
      'studentEmail': studentEmail.trim().toLowerCase(),
      'memberId': memberId.trim(),
      'chapterId': chapterId,
      'chapterTitle': chapterTitle.trim(),
      'topicId': topicId,
      'topicTitle': topicTitle.trim(),
      'level': level.storageValue,
      'comment': comment.trim(),
    };
  }

  LectureFeedback copyWith({
    UnderstandingLevel? level,
    String? comment,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return LectureFeedback(
      id: id,
      lectureId: lectureId,
      sessionId: sessionId,
      courseId: courseId,
      courseName: courseName,
      teacherId: teacherId,
      teacherName: teacherName,
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      memberId: memberId,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      topicId: topicId,
      topicTitle: topicTitle,
      level: level ?? this.level,
      comment: comment ?? this.comment,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class LectureFeedbackCounts {
  const LectureFeedbackCounts({
    this.percent100 = 0,
    this.percent80 = 0,
    this.percent60 = 0,
    this.below50 = 0,
  });

  final int percent100;
  final int percent80;
  final int percent60;
  final int below50;

  int get total => percent100 + percent80 + percent60 + below50;

  int countFor(UnderstandingLevel level) {
    return switch (level) {
      UnderstandingLevel.percent100 => percent100,
      UnderstandingLevel.percent80 => percent80,
      UnderstandingLevel.percent60 => percent60,
      UnderstandingLevel.below50 => below50,
    };
  }

  /// First bucket that has responses, otherwise 100%.
  UnderstandingLevel get defaultSelectedLevel {
    for (final level in UnderstandingLevel.values) {
      if (countFor(level) > 0) {
        return level;
      }
    }
    return UnderstandingLevel.percent100;
  }

  double shareOf(UnderstandingLevel level) {
    if (total <= 0) {
      return 0;
    }
    return countFor(level) / total;
  }

  String shareLabel(UnderstandingLevel level) {
    final pct = shareOf(level) * 100;
    final rounded = (pct * 10).round() / 10;
    if (rounded == rounded.roundToDouble()) {
      return '${rounded.round()}%';
    }
    return '${rounded.toStringAsFixed(1)}%';
  }

  factory LectureFeedbackCounts.fromList(List<LectureFeedback> items) {
    var p100 = 0;
    var p80 = 0;
    var p60 = 0;
    var below = 0;
    for (final item in items) {
      switch (item.level) {
        case UnderstandingLevel.percent100:
          p100++;
        case UnderstandingLevel.percent80:
          p80++;
        case UnderstandingLevel.percent60:
          p60++;
        case UnderstandingLevel.below50:
          below++;
      }
    }
    return LectureFeedbackCounts(
      percent100: p100,
      percent80: p80,
      percent60: p60,
      below50: below,
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
