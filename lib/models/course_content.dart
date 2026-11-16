import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseFirestoreDate(dynamic raw) {
  if (raw is Timestamp) {
    return raw.toDate();
  }
  if (raw is DateTime) {
    return raw;
  }
  if (raw is String) {
    return DateTime.tryParse(raw);
  }
  return null;
}

Object? firestoreDate(DateTime? date) {
  if (date == null) {
    return null;
  }
  return Timestamp.fromDate(date);
}

class CourseAnnouncement {
  const CourseAnnouncement({
    required this.id,
    required this.text,
    this.createdAt,
  });

  final String id;
  final String text;
  final DateTime? createdAt;

  factory CourseAnnouncement.fromMap(Map<String, dynamic> data) {
    return CourseAnnouncement(
      id: data['id'] as String? ?? '',
      text: data['text'] as String? ?? '',
      createdAt: parseFirestoreDate(data['createdAt']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': firestoreDate(createdAt),
    };
  }
}

class SyllabusWeek {
  const SyllabusWeek({
    required this.id,
    required this.weekNumber,
    required this.title,
    this.readings = '',
    this.notes = '',
  });

  final String id;
  final int weekNumber;
  final String title;
  final String readings;
  final String notes;

  factory SyllabusWeek.fromMap(Map<String, dynamic> data) {
    return SyllabusWeek(
      id: data['id'] as String? ?? '',
      weekNumber: (data['weekNumber'] as num?)?.toInt() ?? 1,
      title: data['title'] as String? ?? '',
      readings: data['readings'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'weekNumber': weekNumber,
      'title': title,
      'readings': readings,
      'notes': notes,
    };
  }
}

class CourseAttachment {
  const CourseAttachment({required this.name, required this.url});

  final String name;
  final String url;

  factory CourseAttachment.fromMap(Map<String, dynamic> data) {
    return CourseAttachment(
      name: data['name'] as String? ?? '',
      url: data['url'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {'name': name, 'url': url};
  }
}

List<CourseAttachment> attachmentsFrom(Map<String, dynamic> data) {
  final raw = data['attachments'];
  if (raw is List) {
    final items = raw
        .whereType<Map>()
        .map((item) => CourseAttachment.fromMap(Map<String, dynamic>.from(item)))
        .where((item) => item.url.trim().isNotEmpty)
        .toList();
    if (items.isNotEmpty) {
      return items;
    }
  }
  final url = data['attachmentUrl'] as String? ?? '';
  if (url.trim().isEmpty) {
    return const [];
  }
  final name = data['attachmentName'] as String? ?? '';
  return [
    CourseAttachment(name: name.isEmpty ? url : name, url: url),
  ];
}

Map<String, dynamic> attachmentsToFields(List<CourseAttachment> attachments) {
  return {
    'attachments': attachments.map((item) => item.toMap()).toList(),
    'attachmentName': attachments.isEmpty ? '' : attachments.first.name,
    'attachmentUrl': attachments.isEmpty ? '' : attachments.first.url,
  };
}

class CourseLecture {
  const CourseLecture({
    required this.id,
    required this.title,
    this.date,
    this.description = '',
    this.attachments = const [],
  });

  final String id;
  final String title;
  final DateTime? date;
  final String description;
  final List<CourseAttachment> attachments;

  String get attachmentName =>
      attachments.isEmpty ? '' : attachments.first.name;
  String get attachmentUrl =>
      attachments.isEmpty ? '' : attachments.first.url;

  factory CourseLecture.fromMap(Map<String, dynamic> data) {
    return CourseLecture(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      date: parseFirestoreDate(data['date']),
      description: data['description'] as String? ?? '',
      attachments: attachmentsFrom(data),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'date': firestoreDate(date),
      'description': description,
      ...attachmentsToFields(attachments),
    };
  }
}

class CourseAssignment {
  const CourseAssignment({
    required this.id,
    required this.title,
    this.dueDate,
    this.points = 0,
    this.description = '',
    this.published = true,
    this.attachments = const [],
  });

  final String id;
  final String title;
  final DateTime? dueDate;
  final int points;
  final String description;
  final bool published;
  final List<CourseAttachment> attachments;

  String get attachmentName =>
      attachments.isEmpty ? '' : attachments.first.name;
  String get attachmentUrl =>
      attachments.isEmpty ? '' : attachments.first.url;

  factory CourseAssignment.fromMap(Map<String, dynamic> data) {
    return CourseAssignment(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      dueDate: parseFirestoreDate(data['dueDate']),
      points: (data['points'] as num?)?.toInt() ?? 0,
      description: data['description'] as String? ?? '',
      published: data['published'] as bool? ?? true,
      attachments: attachmentsFrom(data),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'dueDate': firestoreDate(dueDate),
      'points': points,
      'description': description,
      'published': published,
      ...attachmentsToFields(attachments),
    };
  }
}

class CourseResource {
  const CourseResource({
    required this.id,
    required this.title,
    this.type = '',
    this.detail = '',
    this.attachments = const [],
    this.links = const [],
  });

  final String id;
  final String title;
  final String type;
  final String detail;
  final List<CourseAttachment> attachments;
  final List<String> links;

  String get attachmentName =>
      attachments.isEmpty ? '' : attachments.first.name;
  String get attachmentUrl =>
      attachments.isEmpty ? '' : attachments.first.url;

  factory CourseResource.fromMap(Map<String, dynamic> data) {
    return CourseResource(
      id: data['id'] as String? ?? '',
      title: data['title'] as String? ?? '',
      type: data['type'] as String? ?? '',
      detail: data['detail'] as String? ?? '',
      attachments: attachmentsFrom(data),
      links:
          (data['links'] as List<dynamic>?)
              ?.map((value) => value.toString().trim())
              .where((value) => value.isNotEmpty)
              .toList() ??
          const [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'type': type,
      'detail': detail,
      ...attachmentsToFields(attachments),
      'links': links,
    };
  }
}

List<Map<String, dynamic>> _maps(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<CourseAnnouncement> announcementsFrom(dynamic raw) {
  return _maps(raw).map(CourseAnnouncement.fromMap).toList();
}

List<SyllabusWeek> syllabusFrom(dynamic raw) {
  final weeks = _maps(raw).map(SyllabusWeek.fromMap).toList();
  weeks.sort((a, b) => a.weekNumber.compareTo(b.weekNumber));
  return weeks;
}

List<CourseLecture> lecturesFrom(dynamic raw) {
  return _maps(raw).map(CourseLecture.fromMap).toList();
}

List<CourseAssignment> assignmentsFrom(dynamic raw) {
  return _maps(raw).map(CourseAssignment.fromMap).toList();
}

List<CourseResource> resourcesFrom(dynamic raw) {
  return _maps(raw).map(CourseResource.fromMap).toList();
}
