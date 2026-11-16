import 'package:cloud_firestore/cloud_firestore.dart';

import 'course_content.dart';

DateTime? _dateFromFirestore(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  return null;
}

class ChapterModel {
  const ChapterModel({
    required this.id,
    required this.title,
    this.description = '',
    this.position = 0,
    this.createdAt,
    this.attachments = const [],
  });

  final String id;
  final String title;
  final String description;
  final int position;
  final DateTime? createdAt;
  final List<CourseAttachment> attachments;

  factory ChapterModel.fromMap(String id, Map<String, dynamic> data) {
    return ChapterModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      position: (data['position'] as num?)?.toInt() ?? 0,
      createdAt: _dateFromFirestore(data['createdAt']),
      attachments: attachmentsFrom(data),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'position': position,
      ...attachmentsToFields(attachments),
    };
  }

  ChapterModel copyWith({
    String? id,
    String? title,
    String? description,
    int? position,
    DateTime? createdAt,
    List<CourseAttachment>? attachments,
  }) {
    return ChapterModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
    );
  }
}

class TopicModel {
  const TopicModel({
    required this.id,
    required this.title,
    this.description = '',
    this.position = 0,
    this.createdAt,
    this.attachments = const [],
  });

  final String id;
  final String title;
  final String description;
  final int position;
  final DateTime? createdAt;
  final List<CourseAttachment> attachments;

  factory TopicModel.fromMap(String id, Map<String, dynamic> data) {
    return TopicModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      position: (data['position'] as num?)?.toInt() ?? 0,
      createdAt: _dateFromFirestore(data['createdAt']),
      attachments: attachmentsFrom(data),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title.trim(),
      'description': description.trim(),
      'position': position,
      ...attachmentsToFields(attachments),
    };
  }

  TopicModel copyWith({
    String? id,
    String? title,
    String? description,
    int? position,
    DateTime? createdAt,
    List<CourseAttachment>? attachments,
  }) {
    return TopicModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      position: position ?? this.position,
      createdAt: createdAt ?? this.createdAt,
      attachments: attachments ?? this.attachments,
    );
  }
}
