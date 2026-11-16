import 'package:cloud_firestore/cloud_firestore.dart';

import 'course_content.dart';


class CourseLectureSlot {
  const CourseLectureSlot({
    required this.day,
    required this.from,
    required this.to,
  });

  final int day;
  final String from;
  final String to;

  factory CourseLectureSlot.fromMap(Map<String, dynamic> data) {
    return CourseLectureSlot(
      day: (data['day'] as num?)?.toInt() ?? DateTime.monday,
      from: data['from'] as String? ?? '',
      to: data['to'] as String? ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'day': day,
      'from': from.trim(),
      'to': to.trim(),
    };
  }

  CourseLectureSlot copyWith({int? day, String? from, String? to}) {
    return CourseLectureSlot(
      day: day ?? this.day,
      from: from ?? this.from,
      to: to ?? this.to,
    );
  }
}


List<CourseLectureSlot> _slotsFrom(Map<String, dynamic> data) {
  final raw = data['lectureSlots'];
  if (raw is List) {
    final slots = <CourseLectureSlot>[];
    for (final item in raw) {
      if (item is Map<String, dynamic>) {
        slots.add(CourseLectureSlot.fromMap(item));
      } else if (item is Map) {
        slots.add(
          CourseLectureSlot.fromMap(Map<String, dynamic>.from(item)),
        );
      }
    }
    if (slots.isNotEmpty) {
      slots.sort((a, b) => a.day.compareTo(b.day));
      return slots;
    }
  }

  final days = (data['lectureDays'] as List<dynamic>?)
          ?.map((value) => (value as num).toInt())
          .toList() ??
      const <int>[];
  final time = (data['lectureTime'] as String? ?? '').trim();
  if (days.isEmpty) {
    return const [];
  }
  return [
    for (final day in days) CourseLectureSlot(day: day, from: time, to: ''),
  ];
}

class CourseModel {
  const CourseModel({
    required this.id,
    required this.name,
    this.teacherId = '',
    this.teacherEmail = '',
    this.teacherName = '',
    this.code = '',
    this.department = '',
    this.creditHours = 3,
    this.lectureHall = '',
    this.lectureDays = const [],
    this.lectureTime = '',
    this.lectureSlots = const [],
    this.registrationDate,
    this.outlines = '',
    this.semester = '',
    this.section = '',
    this.topicCount = 0,
    this.isLive = false,
    this.announcements = const [],
    this.syllabus = const [],
    this.lectures = const [],
    this.assignments = const [],
    this.resources = const [],
    this.syllabusFiles = const [],
  });

  final String id;
  final String teacherId;
  final String teacherEmail;
  final String teacherName;
  final String name;
  final String code;
  final String department;
  final int creditHours;
  final String lectureHall;
  final List<int> lectureDays;
  final String lectureTime;
  final List<CourseLectureSlot> lectureSlots;
  final DateTime? registrationDate;
  final String outlines;
  final String semester;
  final String section;
  final int topicCount;
  final bool isLive;
  final List<CourseAnnouncement> announcements;
  final List<SyllabusWeek> syllabus;
  final List<CourseLecture> lectures;
  final List<CourseAssignment> assignments;
  final List<CourseResource> resources;
  final List<CourseAttachment> syllabusFiles;


  /// Safe slots for UI: never null, falls back to legacy days/time.
  List<CourseLectureSlot> get resolvedLectureSlots {
    List<CourseLectureSlot> slots;
    try {
      slots = lectureSlots;
    } catch (_) {
      slots = const [];
    }
    if (slots.isNotEmpty) {
      return slots;
    }
    List<int> days;
    try {
      days = lectureDays;
    } catch (_) {
      days = const [];
    }
    if (days.isEmpty) {
      return const [];
    }
    String time;
    try {
      time = lectureTime;
    } catch (_) {
      time = '';
    }
    return [
      for (final day in days) CourseLectureSlot(day: day, from: time, to: ''),
    ];
  }

  factory CourseModel.fromMap(String id, Map<String, dynamic> data) {
    DateTime? registrationDate;
    final rawDate = data['registrationDate'];
    if (rawDate is Timestamp) {
      registrationDate = rawDate.toDate();
    } else if (rawDate is DateTime) {
      registrationDate = rawDate;
    } else if (rawDate is String) {
      registrationDate = DateTime.tryParse(rawDate);
    }

    return CourseModel(
      id: id,
      teacherId: data['teacherId'] as String? ??
          data['createdBy'] as String? ??
          '',
      teacherEmail: data['teacherEmail'] as String? ?? '',
      teacherName: data['teacherName'] as String? ?? '',
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      department: data['department'] as String? ?? '',
      creditHours: (data['creditHours'] as num?)?.toInt() ?? 3,
      lectureHall: data['lectureHall'] as String? ?? '',
      lectureDays:
          (data['lectureDays'] as List<dynamic>?)
              ?.map((value) => (value as num).toInt())
              .toList() ??
          const [],
      lectureTime: data['lectureTime'] as String? ?? '',
      lectureSlots: _slotsFrom(data),
      registrationDate: registrationDate,
      outlines: data['outlines'] as String? ?? '',
      semester: data['semester'] as String? ?? '',
      section: data['section'] as String? ?? '',
      topicCount: (data['topicCount'] as num?)?.toInt() ?? 0,
      isLive: data['isLive'] as bool? ?? false,
      announcements: announcementsFrom(data['announcements']),
      syllabus: syllabusFrom(data['syllabus']),
      lectures: lecturesFrom(data['lectures']),
      assignments: assignmentsFrom(data['assignments']),
      resources: resourcesFrom(data['resources']),
      syllabusFiles: attachmentsFrom({
        'attachments': data['syllabusFiles'],
      }),
    );
  }

  CourseModel copyWith({
    String? id,
    String? teacherId,
    String? teacherEmail,
    String? teacherName,
    String? name,
    String? code,
    String? department,
    int? creditHours,
    String? lectureHall,
    List<int>? lectureDays,
    String? lectureTime,
    List<CourseLectureSlot>? lectureSlots,
    DateTime? registrationDate,
    String? outlines,
    String? semester,
    String? section,
    int? topicCount,
    bool? isLive,
    List<CourseAnnouncement>? announcements,
    List<SyllabusWeek>? syllabus,
    List<CourseLecture>? lectures,
    List<CourseAssignment>? assignments,
    List<CourseResource>? resources,
    List<CourseAttachment>? syllabusFiles,
  }) {
    return CourseModel(
      id: id ?? this.id,
      teacherId: teacherId ?? this.teacherId,
      teacherEmail: teacherEmail ?? this.teacherEmail,
      teacherName: teacherName ?? this.teacherName,
      name: name ?? this.name,
      code: code ?? this.code,
      department: department ?? this.department,
      creditHours: creditHours ?? this.creditHours,
      lectureHall: lectureHall ?? this.lectureHall,
      lectureDays: lectureDays ?? this.lectureDays,
      lectureTime: lectureTime ?? this.lectureTime,
      lectureSlots: lectureSlots ?? this.lectureSlots,
      registrationDate: registrationDate ?? this.registrationDate,
      outlines: outlines ?? this.outlines,
      semester: semester ?? this.semester,
      section: section ?? this.section,
      topicCount: topicCount ?? this.topicCount,
      isLive: isLive ?? this.isLive,
      announcements: announcements ?? this.announcements,
      syllabus: syllabus ?? this.syllabus,
      lectures: lectures ?? this.lectures,
      assignments: assignments ?? this.assignments,
      resources: resources ?? this.resources,
      syllabusFiles: syllabusFiles ?? this.syllabusFiles,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'teacherId': teacherId,
      'createdBy': teacherId,
      'teacherEmail': teacherEmail,
      'teacherName': teacherName,
      'name': name,
      'code': code,
      'department': department,
      'creditHours': creditHours,
      'lectureHall': lectureHall,
      'lectureDays': lectureDays,
      'lectureTime': lectureTime,
      'lectureSlots': resolvedLectureSlots.map((s) => s.toMap()).toList(),
      'registrationDate': firestoreDate(registrationDate),
      'outlines': outlines,
      'semester': semester,
      'section': section,
      'topicCount': topicCount,
      'isLive': isLive,
    };
  }
}
