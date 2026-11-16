import 'package:cloud_firestore/cloud_firestore.dart';

enum LiveSessionStatus { active, ended }

class LiveSessionModel {
  const LiveSessionModel({
    required this.id,
    required this.courseId,
    required this.chapterId,
    required this.chapterTitle,
    required this.topicId,
    required this.topicTitle,
    required this.teacherId,
    required this.durationMinutes,
    this.status = LiveSessionStatus.active,
    this.startedAt,
    this.endedAt,
    this.slideFileIndex = 0,
    this.slidePage = 1,
    this.slideView,
  });

  final String id;
  final String courseId;
  final String chapterId;
  final String chapterTitle;
  final String topicId;
  final String topicTitle;
  final String teacherId;
  final int durationMinutes;
  final LiveSessionStatus status;
  final DateTime? startedAt;
  final DateTime? endedAt;
  /// Teacher-controlled deck position (0-based file, 1-based PDF page).
  final int slideFileIndex;
  final int slidePage;

  /// Teacher zoom/pan for live sync (null until the teacher zooms/pans).
  final LiveSlideView? slideView;

  bool get isActive => status == LiveSessionStatus.active;

  DateTime? get scheduledEnd =>
      startedAt?.add(Duration(minutes: durationMinutes));

  Duration remainingAt(DateTime now) {
    final end = scheduledEnd;
    if (!isActive || end == null || !end.isAfter(now)) {
      return Duration.zero;
    }
    return end.difference(now);
  }

  factory LiveSessionModel.fromMap(
    String id,
    String courseId,
    Map<String, dynamic> data,
  ) {
    return LiveSessionModel(
      id: id,
      courseId: courseId,
      chapterId: data['chapterId'] as String? ?? '',
      chapterTitle: data['chapterTitle'] as String? ?? '',
      topicId: data['topicId'] as String? ?? '',
      topicTitle: data['topicTitle'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      durationMinutes: (data['durationMinutes'] as num?)?.toInt() ?? 0,
      status: data['status'] == 'ended'
          ? LiveSessionStatus.ended
          : LiveSessionStatus.active,
      startedAt: _dateFrom(data['startedAt']),
      endedAt: _dateFrom(data['endedAt']),
      slideFileIndex: (data['slideFileIndex'] as num?)?.toInt() ?? 0,
      slidePage: (data['slidePage'] as num?)?.toInt() ?? 1,
      slideView: LiveSlideView.fromMap(data['slideView']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'chapterId': chapterId,
      'chapterTitle': chapterTitle,
      'topicId': topicId,
      'topicTitle': topicTitle,
      'teacherId': teacherId,
      'durationMinutes': durationMinutes,
      'status': status.name,
    };
  }

  LiveSessionModel copyWith({
    String? id,
    String? courseId,
    String? chapterId,
    String? chapterTitle,
    String? topicId,
    String? topicTitle,
    String? teacherId,
    int? durationMinutes,
    LiveSessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? slideFileIndex,
    int? slidePage,
    LiveSlideView? slideView,
  }) {
    return LiveSessionModel(
      id: id ?? this.id,
      courseId: courseId ?? this.courseId,
      chapterId: chapterId ?? this.chapterId,
      chapterTitle: chapterTitle ?? this.chapterTitle,
      topicId: topicId ?? this.topicId,
      topicTitle: topicTitle ?? this.topicTitle,
      teacherId: teacherId ?? this.teacherId,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      slideFileIndex: slideFileIndex ?? this.slideFileIndex,
      slidePage: slidePage ?? this.slidePage,
      slideView: slideView ?? this.slideView,
    );
  }
}

/// Live slide viewport written by the teacher at
/// `courses/{courseId}/liveSessions/{sessionId}.slideView`.
///
/// [zoom] 1.0 = page width fills the viewer; [cx]/[cy] = centre of the
/// teacher's view as a fraction of the page (0..1). [ts] = client ms epoch,
/// used to drop out-of-order writes.
class LiveSlideView {
  const LiveSlideView({
    required this.fileIndex,
    required this.page,
    required this.zoom,
    required this.cx,
    required this.cy,
    this.ts = 0,
  });

  final int fileIndex;
  final int page;
  final double zoom;
  final double cx;
  final double cy;
  final int ts;

  static LiveSlideView? fromMap(dynamic raw) {
    if (raw is! Map) {
      return null;
    }
    final zoom = (raw['zoom'] as num?)?.toDouble();
    if (zoom == null || zoom <= 0) {
      return null;
    }
    return LiveSlideView(
      fileIndex: (raw['fileIndex'] as num?)?.toInt() ?? 0,
      page: (raw['page'] as num?)?.toInt() ?? 1,
      zoom: zoom,
      cx: (raw['cx'] as num?)?.toDouble() ?? 0.5,
      cy: (raw['cy'] as num?)?.toDouble() ?? 0.5,
      ts: (raw['ts'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'fileIndex': fileIndex,
        'page': page,
        'zoom': zoom,
        'cx': cx,
        'cy': cy,
        'ts': ts,
      };
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
