import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../models/chapter_model.dart';
import '../../models/course_content.dart';
import '../../models/course_model.dart';
import '../../models/ai_practice.dart';
import '../../models/lecture_feedback.dart';
import '../../models/live_slide_signal.dart';
import '../../models/lecture_join_request.dart';
import '../../models/lecture_model.dart';
import '../../models/live_session_model.dart';
import '../../models/teacher_analytics.dart';

class DuplicateCourseCodeException implements Exception {
  const DuplicateCourseCodeException();
}

class TeacherAlreadyLiveException implements Exception {
  const TeacherAlreadyLiveException();
}

class CourseStore extends ChangeNotifier {
  CourseStore({FirebaseFirestore? firestore}) : _db = firestore;

  final FirebaseFirestore? _db;
  final List<CourseModel> _all = [];
  final Map<String, List<ChapterModel>> _localChapters = {};
  final Map<String, List<TopicModel>> _localTopics = {};
  final Map<String, List<LiveSessionModel>> _localLiveSessions = {};
  final Map<String, LectureModel> _localLectures = {};
  final Map<String, List<LectureAttendee>> _localAttendees = {};
  final Map<String, List<LectureJoinRequest>> _localJoinRequests = {};
  final Map<String, LectureFeedback> _localFeedback = {};
  /// key = courseId/sessionId/signalId
  final Map<String, LiveSlideSignal> _localSlideSignals = {};
  final Map<String, List<AiPracticeAttempt>> _localPracticeAttempts = {};
  final Map<String, String> _localTeacherNotes = {};
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _subscription;
  String? _teacherId;
  var _bound = false;

  CollectionReference<Map<String, dynamic>>? get _collection =>
      _db?.collection('courses');

  List<CourseModel> get courses {
    if (_db != null) {
      return List.unmodifiable(_all);
    }
    if (!_bound) {
      return List.unmodifiable(_all);
    }
    final teacherId = _teacherId;
    if (teacherId == null || teacherId.isEmpty) {
      return const [];
    }
    return List.unmodifiable(
      _all.where((course) => course.teacherId == teacherId),
    );
  }

  void watchTeacher(String? teacherId) {
    _bound = true;
    _teacherId = teacherId;
    _subscription?.cancel();
    _subscription = null;

    final collection = _collection;
    if (collection == null) {
      notifyListeners();
      return;
    }

    if (teacherId == null || teacherId.isEmpty) {
      _all.clear();
      notifyListeners();
      return;
    }

    _subscription = collection
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .listen(
          (snapshot) {
            try {
              _all
                ..clear()
                ..addAll(
                  snapshot.docs.map(
                    (doc) => CourseModel.fromMap(doc.id, doc.data()),
                  ),
                );
              _all.sort(
                (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
              );
              notifyListeners();
            } catch (_) {
              notifyListeners();
            }
          },
          onError: (_) {
            notifyListeners();
          },
        );
  }

  static String normalizeCourseCode(String raw) {
    return raw.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');
  }

  Future<bool> isCourseCodeTaken(String rawCode, {String? exceptCourseId}) {
    return _isCourseCodeTaken(
      normalizeCourseCode(rawCode),
      exceptCourseId: exceptCourseId,
    );
  }

  Future<bool> _isCourseCodeTaken(String code, {String? exceptCourseId}) async {
    if (code.isEmpty) {
      return false;
    }
    final collection = _collection;
    if (collection == null) {
      return _all.any(
        (course) =>
            course.id != exceptCourseId &&
            normalizeCourseCode(course.code) == code,
      );
    }

    final byId = await collection.doc(code).get();
    if (byId.exists && byId.id != exceptCourseId) {
      return true;
    }

    final matches = await collection
        .where('code', isEqualTo: code)
        .limit(5)
        .get();
    return matches.docs.any((doc) => doc.id != exceptCourseId);
  }

  Future<void> addCourse(CourseModel course) async {
    final teacherId = course.teacherId.isNotEmpty
        ? course.teacherId
        : _teacherId ?? '';
    final code = normalizeCourseCode(course.code);
    if (code.isEmpty) {
      throw StateError('Cannot save a course without an ID.');
    }
    if (await _isCourseCodeTaken(code)) {
      throw const DuplicateCourseCodeException();
    }

    final collection = _collection;
    if (collection == null) {
      _all.add(course.copyWith(id: code, teacherId: teacherId, code: code));
      notifyListeners();
      return;
    }

    if (teacherId.isEmpty) {
      throw StateError('Cannot save a course without a teacher.');
    }
    final doc = collection.doc(code);
    final payload = {
      ...course.toMap(),
      'code': code,
      'teacherId': teacherId,
      'createdBy': teacherId,
      'teacherEmail': course.teacherEmail,
      'teacherName': course.teacherName,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };
    try {
      await _db!.runTransaction((transaction) async {
        final existing = await transaction.get(doc);
        if (existing.exists) {
          throw const DuplicateCourseCodeException();
        }
        transaction.set(doc, payload);
      });
    } on DuplicateCourseCodeException {
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'already-exists' || error.code == 'aborted') {
        if (await _isCourseCodeTaken(code)) {
          throw const DuplicateCourseCodeException();
        }
      }
      rethrow;
    }
  }

  Future<void> removeCourse(String id) async {
    final collection = _collection;
    if (collection == null) {
      _all.removeWhere((course) => course.id == id);
      _localChapters.remove(id);
      _localTopics.removeWhere((key, _) => key.startsWith('$id/'));
      _localLiveSessions.remove(id);
      notifyListeners();
      return;
    }
    await _deleteCourseChapters(id);
    await _deleteCourseLiveSessions(id);
    await collection.doc(id).delete();
  }

  Future<void> updateCourse(CourseModel course) async {
    if (course.id.isEmpty) {
      throw StateError('Cannot update a course without an id.');
    }
    final collection = _collection;
    if (collection == null) {
      final index = _all.indexWhere((item) => item.id == course.id);
      if (index < 0) {
        throw StateError('Course not found.');
      }
      final code = normalizeCourseCode(course.code);
      if (_all.any(
        (item) =>
            item.id != course.id && normalizeCourseCode(item.code) == code,
      )) {
        throw const DuplicateCourseCodeException();
      }
      _all[index] = course.copyWith(code: code);
      notifyListeners();
      return;
    }
    final code = normalizeCourseCode(course.code);
    if (await _isCourseCodeTaken(code, exceptCourseId: course.id)) {
      throw const DuplicateCourseCodeException();
    }
    await collection.doc(course.id).update({
      ...course.toMap(),
      'code': code,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  String _topicKey(String courseId, String chapterId) => '$courseId/$chapterId';

  CollectionReference<Map<String, dynamic>> _chapterCollection(
    String courseId,
  ) {
    return _db!.collection('courses').doc(courseId).collection('chapters');
  }

  CollectionReference<Map<String, dynamic>> _topicCollection(
    String courseId,
    String chapterId,
  ) {
    return _chapterCollection(courseId).doc(chapterId).collection('topics');
  }

  CollectionReference<Map<String, dynamic>> _liveSessionCollection(
    String courseId,
  ) {
    return _db!.collection('courses').doc(courseId).collection('liveSessions');
  }

  CollectionReference<Map<String, dynamic>> get _lecturesCollection =>
      _db!.collection('lectures');

  CollectionReference<Map<String, dynamic>> get _feedbackCollection =>
      _db!.collection('feedback');

  Stream<List<ChapterModel>> watchChapters(String courseId) {
    if (_db == null) {
      final chapters = [...?_localChapters[courseId]]
        ..sort((a, b) => a.position.compareTo(b.position));
      return Stream.value(chapters);
    }
    return _chapterCollection(courseId)
        .orderBy('position')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChapterModel.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<TopicModel>> watchTopics(String courseId, String chapterId) {
    if (_db == null) {
      final topics = [...?_localTopics[_topicKey(courseId, chapterId)]]
        ..sort((a, b) => a.position.compareTo(b.position));
      return Stream.value(topics);
    }
    // Sort locally so a topic saved without `position` is still included.
    // `orderBy('position')` drops those documents, which hid earlier topics
    // on the live lecture screen.
    return _topicCollection(courseId, chapterId).snapshots().map((snapshot) {
      final topics = snapshot.docs
          .map((doc) => TopicModel.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) => a.position.compareTo(b.position));
      return topics;
    });
  }

  Future<void> addChapter(String courseId, ChapterModel chapter) async {
    if (courseId.isEmpty || chapter.title.trim().isEmpty) {
      throw StateError('A course and chapter title are required.');
    }
    if (_db == null) {
      final chapters = _localChapters.putIfAbsent(courseId, () => []);
      chapters.add(
        chapter.copyWith(
          id: chapter.id.isEmpty
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : chapter.id,
          position: chapters.length,
        ),
      );
      notifyListeners();
      return;
    }
    final chapters = _chapterCollection(courseId);
    final doc = chapter.id.isEmpty ? chapters.doc() : chapters.doc(chapter.id);
    final position = await _nextPosition(chapters);
    await doc.set({
      ...chapter.toMap(),
      'position': position,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateChapter(String courseId, ChapterModel chapter) async {
    if (courseId.isEmpty ||
        chapter.id.isEmpty ||
        chapter.title.trim().isEmpty) {
      throw StateError('A valid chapter is required.');
    }
    if (_db == null) {
      final chapters = _localChapters[courseId] ?? [];
      final index = chapters.indexWhere((item) => item.id == chapter.id);
      if (index < 0) {
        throw StateError('Chapter not found.');
      }
      chapters[index] = chapter;
      notifyListeners();
      return;
    }
    await _chapterCollection(courseId).doc(chapter.id).update({
      'title': chapter.title.trim(),
      'description': chapter.description.trim(),
      ...attachmentsToFields(chapter.attachments),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteChapter(String courseId, String chapterId) async {
    if (_db == null) {
      final removedTopicCount =
          _localTopics[_topicKey(courseId, chapterId)]?.length ?? 0;
      _localChapters[courseId]?.removeWhere((item) => item.id == chapterId);
      _localTopics.remove(_topicKey(courseId, chapterId));
      _adjustLocalTopicCount(courseId, -removedTopicCount);
      notifyListeners();
      return;
    }
    final topics = await _topicCollection(courseId, chapterId).get();
    final batch = _db.batch();
    for (final topic in topics.docs) {
      batch.delete(topic.reference);
    }
    batch.delete(_chapterCollection(courseId).doc(chapterId));
    if (topics.docs.isNotEmpty) {
      batch.update(_collection!.doc(courseId), {
        'topicCount': FieldValue.increment(-topics.docs.length),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> reorderChapters(
    String courseId,
    List<ChapterModel> chapters,
  ) async {
    if (_db == null) {
      _localChapters[courseId] = [
        for (var i = 0; i < chapters.length; i++)
          chapters[i].copyWith(position: i),
      ];
      notifyListeners();
      return;
    }
    final batch = _db.batch();
    for (var i = 0; i < chapters.length; i++) {
      batch.update(_chapterCollection(courseId).doc(chapters[i].id), {
        'position': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> addTopic(
    String courseId,
    String chapterId,
    TopicModel topic,
  ) async {
    if (courseId.isEmpty || chapterId.isEmpty || topic.title.trim().isEmpty) {
      throw StateError('A chapter and topic title are required.');
    }
    if (_db == null) {
      final key = _topicKey(courseId, chapterId);
      final topics = _localTopics.putIfAbsent(key, () => []);
      topics.add(
        topic.copyWith(
          id: topic.id.isEmpty
              ? DateTime.now().microsecondsSinceEpoch.toString()
              : topic.id,
          position: topics.length,
        ),
      );
      _adjustLocalTopicCount(courseId, 1);
      notifyListeners();
      return;
    }
    final topics = _topicCollection(courseId, chapterId);
    final doc = topic.id.isEmpty ? topics.doc() : topics.doc(topic.id);
    final position = await _nextPosition(topics);
    final batch = _db.batch();
    batch.set(doc, {
      ...topic.toMap(),
      'position': position,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    batch.update(_collection!.doc(courseId), {
      'topicCount': FieldValue.increment(1),
      'updatedAt': FieldValue.serverTimestamp(),
    });
    await batch.commit();
  }

  Future<void> updateTopic(
    String courseId,
    String chapterId,
    TopicModel topic,
  ) async {
    if (courseId.isEmpty ||
        chapterId.isEmpty ||
        topic.id.isEmpty ||
        topic.title.trim().isEmpty) {
      throw StateError('A valid topic is required.');
    }
    if (_db == null) {
      final topics = _localTopics[_topicKey(courseId, chapterId)] ?? [];
      final index = topics.indexWhere((item) => item.id == topic.id);
      if (index < 0) {
        throw StateError('Topic not found.');
      }
      topics[index] = topic;
      notifyListeners();
      return;
    }
    await _topicCollection(courseId, chapterId).doc(topic.id).update({
      'title': topic.title.trim(),
      'description': topic.description.trim(),
      ...attachmentsToFields(topic.attachments),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deleteTopic(
    String courseId,
    String chapterId,
    String topicId,
  ) async {
    if (_db == null) {
      final topics = _localTopics[_topicKey(courseId, chapterId)];
      final before = topics?.length ?? 0;
      topics?.removeWhere((item) => item.id == topicId);
      if ((topics?.length ?? 0) < before) {
        _adjustLocalTopicCount(courseId, -1);
      }
      notifyListeners();
      return;
    }
    final topicRef = _topicCollection(courseId, chapterId).doc(topicId);
    final courseRef = _collection!.doc(courseId);
    await _db.runTransaction((transaction) async {
      final topic = await transaction.get(topicRef);
      if (!topic.exists) {
        return;
      }
      final course = await transaction.get(courseRef);
      final currentCount = (course.data()?['topicCount'] as num?)?.toInt() ?? 0;
      transaction.delete(topicRef);
      transaction.update(courseRef, {
        'topicCount': currentCount > 0 ? currentCount - 1 : 0,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> reorderTopics(
    String courseId,
    String chapterId,
    List<TopicModel> topics,
  ) async {
    if (_db == null) {
      _localTopics[_topicKey(courseId, chapterId)] = [
        for (var i = 0; i < topics.length; i++) topics[i].copyWith(position: i),
      ];
      notifyListeners();
      return;
    }
    final batch = _db.batch();
    for (var i = 0; i < topics.length; i++) {
      batch.update(_topicCollection(courseId, chapterId).doc(topics[i].id), {
        'position': i,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  LiveSessionModel? _localActiveSession(String courseId) {
    final sessions = _localLiveSessions[courseId] ?? const <LiveSessionModel>[];
    for (final session in sessions) {
      if (session.isActive) {
        return session;
      }
    }
    return null;
  }

  /// Local sessions have no Firestore snapshots. Re-emit whenever the store
  /// changes so listeners see lectures start and end without resubscribing.
  Stream<LiveSessionModel?> _watchLocalActiveSession(String courseId) {
    late final StreamController<LiveSessionModel?> controller;
    void emit() {
      if (!controller.isClosed) {
        controller.add(_localActiveSession(courseId));
      }
    }

    controller = StreamController<LiveSessionModel?>(
      onListen: () {
        addListener(emit);
        emit();
      },
      onCancel: () {
        removeListener(emit);
      },
    );
    return controller.stream;
  }

  Stream<LiveSessionModel?> watchActiveSession(String courseId) {
    if (_db == null) {
      return _watchLocalActiveSession(courseId);
    }
    return _liveSessionCollection(courseId)
        .where('status', isEqualTo: LiveSessionStatus.active.name)
        .limit(1)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.isEmpty
              ? null
              : LiveSessionModel.fromMap(
                  snapshot.docs.first.id,
                  courseId,
                  snapshot.docs.first.data(),
                ),
        );
  }

  /// Teacher's current live lecture (at most one), or null when none is active.
  Stream<LiveSessionModel?> watchTeacherActiveLive(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream.value(null);
    }
    if (_db == null) {
      final active = _localLiveSessions.values
          .expand((sessions) => sessions)
          .where(
            (session) => session.isActive && session.teacherId == teacherId,
          )
          .firstOrNull;
      return Stream.value(active);
    }
    return _db.collection('users').doc(teacherId).snapshots().asyncExpand((
      snapshot,
    ) {
      final data = snapshot.data();
      final courseId = data?['activeLiveCourseId'] as String? ?? '';
      final sessionId = data?['activeLiveSessionId'] as String? ?? '';
      if (courseId.isEmpty || sessionId.isEmpty) {
        return Stream<LiveSessionModel?>.value(null);
      }
      return _liveSessionCollection(courseId).doc(sessionId).snapshots().map((
        sessionSnap,
      ) {
        if (!sessionSnap.exists || sessionSnap.data() == null) {
          return null;
        }
        final session = LiveSessionModel.fromMap(
          sessionSnap.id,
          courseId,
          sessionSnap.data()!,
        );
        return session.isActive ? session : null;
      });
    });
  }

  /// All active live sessions across the given courses (0..n).
  Stream<List<LiveSessionModel>> watchActiveSessionsForCourses(
    List<String> courseIds,
  ) {
    final ids = courseIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) {
      return Stream.value(const []);
    }
    if (_db == null) {
      final active = <LiveSessionModel>[
        for (final courseId in ids)
          ...?_localLiveSessions[courseId]?.where(
            (session) => session.isActive,
          ),
      ];
      return Stream.value(active);
    }

    late final StreamController<List<LiveSessionModel>> controller;
    final latest = <String, LiveSessionModel?>{for (final id in ids) id: null};
    final subscriptions = <StreamSubscription<LiveSessionModel?>>[];

    void emit() {
      if (!controller.isClosed) {
        controller.add(
          latest.values.whereType<LiveSessionModel>().toList(growable: false),
        );
      }
    }

    controller = StreamController<List<LiveSessionModel>>(
      onListen: () {
        for (final courseId in ids) {
          subscriptions.add(
            watchActiveSession(courseId).listen((session) {
              latest[courseId] = session;
              emit();
            }),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }


  Stream<List<LiveSessionModel>> watchRecentEndedSessionsForCourses(
    List<String> courseIds, {
    int perCourseLimit = 100,
  }) {
    final ids = courseIds.where((id) => id.isNotEmpty).toSet().toList();
    if (ids.isEmpty) {
      return Stream<List<LiveSessionModel>>.value(const []);
    }
    if (_db == null) {
      final ended = <LiveSessionModel>[
        for (final courseId in ids)
          ...?_localLiveSessions[courseId]?.where((session) => !session.isActive),
      ]..sort((a, b) {
          final left = a.endedAt ?? a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.endedAt ?? b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
      return Stream<List<LiveSessionModel>>.value(ended).asBroadcastStream();
    }

    late final StreamController<List<LiveSessionModel>> controller;
    final latest = <String, List<LiveSessionModel>>{
      for (final id in ids) id: const <LiveSessionModel>[],
    };
    final subscriptions = <StreamSubscription<QuerySnapshot<Map<String, dynamic>>>>[];

    void emit() {
      if (controller.isClosed) {
        return;
      }
      final merged = <LiveSessionModel>[
        for (final sessions in latest.values) ...sessions,
      ]..sort((a, b) {
          final left = a.endedAt ?? a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.endedAt ?? b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
      controller.add(merged);
    }

    controller = StreamController<List<LiveSessionModel>>(
      onListen: () {
        for (final courseId in ids) {
          subscriptions.add(
            _liveSessionCollection(courseId)
                .where('status', isEqualTo: LiveSessionStatus.ended.name)
                .orderBy('endedAt', descending: true)
                .limit(perCourseLimit)
                .snapshots()
                .listen((snapshot) {
              latest[courseId] = [
                for (final doc in snapshot.docs)
                  LiveSessionModel.fromMap(doc.id, courseId, doc.data()),
              ];
              emit();
            }),
          );
        }
      },
      onCancel: () async {
        for (final sub in subscriptions) {
          await sub.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  /// Ended live lectures for one course + chapter + topic, newest first.
  Stream<List<LiveSessionModel>> watchEndedSessionsForTopic({
    required String courseId,
    required String chapterId,
    required String topicId,
  }) {
    if (courseId.isEmpty || chapterId.isEmpty || topicId.isEmpty) {
      return Stream<List<LiveSessionModel>>.value(const []);
    }
    if (_db == null) {
      final ended = [
        ...?_localLiveSessions[courseId]?.where(
          (session) =>
              !session.isActive &&
              session.chapterId == chapterId &&
              session.topicId == topicId,
        ),
      ]..sort((a, b) {
          final left =
              a.endedAt ?? a.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right =
              b.endedAt ?? b.startedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return right.compareTo(left);
        });
      return Stream<List<LiveSessionModel>>.value(ended).asBroadcastStream();
    }

    // No limit — every ended lecture for this course/chapter/topic.
    return _liveSessionCollection(courseId)
        .where('status', isEqualTo: LiveSessionStatus.ended.name)
        .where('chapterId', isEqualTo: chapterId)
        .where('topicId', isEqualTo: topicId)
        .orderBy('endedAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => [
            for (final doc in snapshot.docs)
              LiveSessionModel.fromMap(doc.id, courseId, doc.data()),
          ],
        );
  }

  Stream<LiveSessionModel?> watchLiveSession(
    String courseId,
    String sessionId,
  ) {
    if (_db == null) {
      return Stream.value(
        (_localLiveSessions[courseId] ?? const [])
            .where((session) => session.id == sessionId)
            .firstOrNull,
      );
    }
    return _liveSessionCollection(courseId)
        .doc(sessionId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? LiveSessionModel.fromMap(
                  snapshot.id,
                  courseId,
                  snapshot.data()!,
                )
              : null,
        );
  }

  Future<void> updateLiveSlidePosition({
    required String courseId,
    required String sessionId,
    required int fileIndex,
    required int page,
  }) async {
    if (courseId.isEmpty || sessionId.isEmpty) {
      return;
    }
    final safeFile = fileIndex < 0 ? 0 : fileIndex;
    final safePage = page < 1 ? 1 : page;
    if (_db == null) {
      final sessions = _localLiveSessions[courseId];
      if (sessions == null) {
        return;
      }
      final index = sessions.indexWhere((item) => item.id == sessionId);
      if (index < 0) {
        return;
      }
      sessions[index] = sessions[index].copyWith(
        slideFileIndex: safeFile,
        slidePage: safePage,
      );
      notifyListeners();
      return;
    }
    await _liveSessionCollection(courseId).doc(sessionId).update({
      'slideFileIndex': safeFile,
      'slidePage': safePage,
      'slideUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Teacher zoom/pan for live student sync (`slideView` on the live session).
  Future<void> updateLiveSlideView({
    required String courseId,
    required String sessionId,
    required LiveSlideView view,
  }) async {
    if (courseId.isEmpty || sessionId.isEmpty) {
      return;
    }
    final safe = LiveSlideView(
      fileIndex: view.fileIndex < 0 ? 0 : view.fileIndex,
      page: view.page < 1 ? 1 : view.page,
      zoom: view.zoom.clamp(0.05, 20.0),
      cx: view.cx.clamp(-1.0, 2.0),
      cy: view.cy.clamp(-1.0, 2.0),
      ts: view.ts <= 0 ? DateTime.now().millisecondsSinceEpoch : view.ts,
    );
    if (_db == null) {
      final sessions = _localLiveSessions[courseId];
      if (sessions == null) {
        return;
      }
      final index = sessions.indexWhere((item) => item.id == sessionId);
      if (index < 0) {
        return;
      }
      sessions[index] = sessions[index].copyWith(
        slideView: safe,
        slideFileIndex: safe.fileIndex,
        slidePage: safe.page,
      );
      notifyListeners();
      return;
    }
    // Keep this update compatible with deployed rules that only allow
    // slideView + slideViewUpdatedAt. Page sync still happens via
    // updateLiveSlidePosition; the student viewer trusts slideView.page.
    await _liveSessionCollection(courseId).doc(sessionId).update({
      'slideView': safe.toMap(),
      'slideViewUpdatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Retarget an existing live lecture to a different course topic.
  ///
  /// Updates only topicId / topicTitle / topicUpdatedAt on the existing
  /// liveSessions/{sessionId} and lectures/{sessionId} docs. Does not create
  /// a new session or lecture, does not end/restart the lecture, and does not
  /// touch timer, attendees, slide position, or lecture identity/id.
  Future<void> updateLiveSessionTopic({
    required String courseId,
    required String sessionId,
    required String topicId,
    required String topicTitle,
  }) async {
    if (courseId.isEmpty || sessionId.isEmpty || topicId.isEmpty) {
      return;
    }
    final trimmedTitle = topicTitle.trim();
    if (trimmedTitle.isEmpty) {
      return;
    }
    if (_db == null) {
      final sessions = _localLiveSessions[courseId];
      if (sessions != null) {
        final index = sessions.indexWhere((item) => item.id == sessionId);
        if (index >= 0) {
          // Same session object identity (id); retarget topic and reset deck.
          sessions[index] = sessions[index].copyWith(
            topicId: topicId,
            topicTitle: trimmedTitle,
            slideFileIndex: 0,
            slidePage: 1,
            slideView: const LiveSlideView(
              fileIndex: 0,
              page: 1,
              zoom: 1,
              cx: 0.5,
              cy: 0.5,
            ),
          );
        }
      }
      final lecture = _localLectures[sessionId];
      if (lecture != null) {
        // Same lecture id; topic fields only.
        _localLectures[sessionId] = lecture.copyWith(
          topicId: topicId,
          topicTitle: trimmedTitle,
        );
      }
      notifyListeners();
      return;
    }
    // .update (not set) — existing docs only; never creates a new lecture.
    // Fields must match firestore.rules allow-list for active session/lecture.
    final payload = <String, dynamic>{
      'topicId': topicId,
      'topicTitle': trimmedTitle,
      'topicUpdatedAt': FieldValue.serverTimestamp(),
    };
    final batch = _db.batch();
    batch.update(_liveSessionCollection(courseId).doc(sessionId), payload);
    batch.update(_lecturesCollection.doc(sessionId), payload);
    await batch.commit();
  }

  CollectionReference<Map<String, dynamic>> _slideSignalsCollection(
    String courseId,
    String sessionId,
  ) {
    return _liveSessionCollection(courseId)
        .doc(sessionId)
        .collection('slideSignals');
  }

  String _localSlideSignalKey(
    String courseId,
    String sessionId,
    String signalId,
  ) =>
      '$courseId/$sessionId/$signalId';

  Future<LiveSlideSignal> submitLiveSlideSignal({
    required LiveSessionModel session,
    required String studentId,
    required String studentName,
    String studentEmail = '',
    String memberId = '',
    required int fileIndex,
    required int page,
    required UnderstandingLevel level,
  }) async {
    if (studentId.isEmpty || !session.isActive) {
      throw StateError('live_slide_signal_unavailable');
    }
    final safeFile = fileIndex < 0 ? 0 : fileIndex;
    final safePage = page < 1 ? 1 : page;
    final id = LiveSlideSignal.docId(
      studentId: studentId,
      fileIndex: safeFile,
      page: safePage,
    );
    final draft = LiveSlideSignal(
      id: id,
      sessionId: session.id,
      courseId: session.courseId,
      teacherId: session.teacherId,
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      memberId: memberId,
      slideFileIndex: safeFile,
      slidePage: safePage,
      level: level,
    );

    if (_db == null) {
      final key = _localSlideSignalKey(session.courseId, session.id, id);
      final existing = _localSlideSignals[key];
      final saved = LiveSlideSignal(
        id: id,
        sessionId: draft.sessionId,
        courseId: draft.courseId,
        teacherId: draft.teacherId,
        studentId: draft.studentId,
        studentName: draft.studentName,
        studentEmail: draft.studentEmail,
        memberId: draft.memberId,
        slideFileIndex: draft.slideFileIndex,
        slidePage: draft.slidePage,
        level: draft.level,
        createdAt: existing?.createdAt ?? DateTime.now(),
        updatedAt: DateTime.now(),
      );
      _localSlideSignals[key] = saved;
      notifyListeners();
      return saved;
    }

    final ref = _slideSignalsCollection(session.courseId, session.id).doc(id);
    final existing = await ref.get();
    final payload = {
      ...draft.toWriteMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      if (!existing.exists) 'createdAt': FieldValue.serverTimestamp(),
    };
    await ref.set(payload, SetOptions(merge: true));
    final snap = await ref.get();
    return LiveSlideSignal.fromMap(id, snap.data() ?? payload);
  }

  Stream<List<LiveSlideSignal>> watchLiveSlideSignals({
    required String courseId,
    required String sessionId,
  }) {
    if (courseId.isEmpty || sessionId.isEmpty) {
      return Stream<List<LiveSlideSignal>>.value(const []);
    }
    if (_db == null) {
      final prefix = '$courseId/$sessionId/';
      final items = _localSlideSignals.entries
          .where((e) => e.key.startsWith(prefix))
          .map((e) => e.value)
          .toList()
        ..sort((a, b) {
          final byPage = a.slidePage.compareTo(b.slidePage);
          if (byPage != 0) {
            return byPage;
          }
          return a.studentName.compareTo(b.studentName);
        });
      return Stream<List<LiveSlideSignal>>.value(items).asBroadcastStream();
    }
    return _slideSignalsCollection(courseId, sessionId).snapshots().map((
      snapshot,
    ) {
      final items = snapshot.docs
          .map((doc) => LiveSlideSignal.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final byFile = a.slideFileIndex.compareTo(b.slideFileIndex);
          if (byFile != 0) {
            return byFile;
          }
          final byPage = a.slidePage.compareTo(b.slidePage);
          if (byPage != 0) {
            return byPage;
          }
          return a.studentName.toLowerCase().compareTo(
                b.studentName.toLowerCase(),
              );
        });
      return items;
    });
  }


  /// Student-safe: only this student's signals (rules allow list on own docs).
  Stream<List<LiveSlideSignal>> watchStudentLiveSlideSignals({
    required String courseId,
    required String sessionId,
    required String studentId,
  }) {
    if (courseId.isEmpty || sessionId.isEmpty || studentId.isEmpty) {
      return Stream<List<LiveSlideSignal>>.value(const []);
    }
    if (_db == null) {
      final prefix = '$courseId/$sessionId/';
      final items = _localSlideSignals.entries
          .where((e) => e.key.startsWith(prefix))
          .map((e) => e.value)
          .where((s) => s.studentId == studentId)
          .toList()
        ..sort((a, b) {
          final byPage = a.slidePage.compareTo(b.slidePage);
          if (byPage != 0) {
            return byPage;
          }
          return a.slideFileIndex.compareTo(b.slideFileIndex);
        });
      return Stream<List<LiveSlideSignal>>.value(items).asBroadcastStream();
    }
    return _slideSignalsCollection(courseId, sessionId)
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
      final items = snapshot.docs
          .map((doc) => LiveSlideSignal.fromMap(doc.id, doc.data()))
          .toList()
        ..sort((a, b) {
          final byFile = a.slideFileIndex.compareTo(b.slideFileIndex);
          if (byFile != 0) {
            return byFile;
          }
          return a.slidePage.compareTo(b.slidePage);
        });
      return items;
    });
  }

  Stream<LiveSlideSignal?> watchMyLiveSlideSignal({
    required String courseId,
    required String sessionId,
    required String studentId,
    required int fileIndex,
    required int page,
  }) {
    if (courseId.isEmpty || sessionId.isEmpty || studentId.isEmpty) {
      return Stream<LiveSlideSignal?>.value(null);
    }
    final id = LiveSlideSignal.docId(
      studentId: studentId,
      fileIndex: fileIndex,
      page: page,
    );
    if (_db == null) {
      final key = _localSlideSignalKey(courseId, sessionId, id);
      return Stream<LiveSlideSignal?>.value(_localSlideSignals[key]);
    }
    return _slideSignalsCollection(courseId, sessionId)
        .doc(id)
        .snapshots()
        .map((snap) {
      if (!snap.exists || snap.data() == null) {
        return null;
      }
      return LiveSlideSignal.fromMap(snap.id, snap.data()!);
    });
  }

  Future<LiveSessionModel> startLiveSession(
    LiveSessionModel session, {
    required String courseName,
    required String teacherName,
    String taughtNotes = '',
  }) async {
    if (session.courseId.isEmpty ||
        session.teacherId.isEmpty ||
        session.chapterId.isEmpty ||
        session.topicId.isEmpty ||
        session.durationMinutes <= 0) {
      throw StateError('A valid live session is required.');
    }
    final sessionId = session.id.isEmpty
        ? DateTime.now().microsecondsSinceEpoch.toString()
        : session.id;
    final now = DateTime.now();
    if (_db == null) {
      final teacherBusy = _localLiveSessions.values
          .expand((sessions) => sessions)
          .any((item) => item.isActive && item.teacherId == session.teacherId);
      if (teacherBusy) {
        throw const TeacherAlreadyLiveException();
      }
      final sessions = _localLiveSessions.putIfAbsent(
        session.courseId,
        () => [],
      );
      if (sessions.any((item) => item.isActive)) {
        throw StateError('This course already has an active session.');
      }
      final started = session.copyWith(id: sessionId, startedAt: now);
      sessions.add(started);
      final notes = taughtNotes.trim();
      final localLecture = LectureModel(
        id: sessionId,
        courseId: session.courseId,
        courseName: courseName,
        teacherId: session.teacherId,
        teacherName: teacherName,
        chapterId: session.chapterId,
        chapterTitle: session.chapterTitle,
        topicId: session.topicId,
        topicTitle: session.topicTitle,
        durationMinutes: session.durationMinutes,
        startedAt: now,
        lectureDate: lectureDateKey(now),
        taughtNotes: notes,
      );
      _localLectures[sessionId] = localLecture.copyWith(
        summary: LectureSummary.fromLecture(
          localLecture,
          taughtNotes: notes,
        ),
      );
      if (notes.isNotEmpty) {
        _localTeacherNotes[sessionId] = notes;
      }
      _localAttendees[sessionId] = [];
      _localJoinRequests[sessionId] = [];
      final courseIndex = _all.indexWhere(
        (course) => course.id == session.courseId,
      );
      if (courseIndex >= 0) {
        _all[courseIndex] = _all[courseIndex].copyWith(isLive: true);
      }
      notifyListeners();
      return started;
    }

    final courseRef = _collection!.doc(session.courseId);
    final sessionRef = _liveSessionCollection(session.courseId).doc(sessionId);
    final lectureRef = _lecturesCollection.doc(sessionId);
    final teacherRef = _db.collection('users').doc(session.teacherId);
    await _db.runTransaction((transaction) async {
      final course = await transaction.get(courseRef);
      final teacher = await transaction.get(teacherRef);
      if (!course.exists || course.data()?['teacherId'] != session.teacherId) {
        throw StateError('Only the course teacher can start a lecture.');
      }
      final activeId = course.data()?['activeSessionId'] as String? ?? '';
      if (activeId.isNotEmpty) {
        throw StateError('This course already has an active session.');
      }
      final teacherActive =
          teacher.data()?['activeLiveSessionId'] as String? ?? '';
      if (teacherActive.isNotEmpty) {
        throw const TeacherAlreadyLiveException();
      }
      transaction.set(sessionRef, {
        ...session.copyWith(id: sessionId).toMap(),
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final notes = taughtNotes.trim();
      final lectureSeed = LectureModel(
        id: sessionId,
        courseId: session.courseId,
        courseName: courseName,
        teacherId: session.teacherId,
        teacherName: teacherName,
        chapterId: session.chapterId,
        chapterTitle: session.chapterTitle,
        topicId: session.topicId,
        topicTitle: session.topicTitle,
        durationMinutes: session.durationMinutes,
        lectureDate: lectureDateKey(now),
        taughtNotes: notes,
      );
      transaction.set(lectureRef, {
        ...lectureSeed.toCreateMap(),
        // Persist notes on the lecture doc at start (AI Practice reads this).
        // Do not write summary here — summary is validated only after end.
        if (notes.isNotEmpty) 'taughtNotes': notes,
        'startedAt': FieldValue.serverTimestamp(),
        'endedAt': null,
        'createdAt': FieldValue.serverTimestamp(),
      });
      transaction.update(courseRef, {
        'activeSessionId': sessionId,
        'isLive': true,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(teacherRef, {
        'activeLiveCourseId': session.courseId,
        'activeLiveSessionId': sessionId,
        'activeLiveUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    final notes = taughtNotes.trim();
    if (notes.isNotEmpty) {
      Object? notesError;
      try {
        await lectureRef.collection('teacherNotes').doc('current').set({
          'text': notes,
          'teacherId': session.teacherId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      } catch (error, stackTrace) {
        notesError = error;
        debugPrint('teacherNotes save on start failed: $error');
        debugPrint('$stackTrace');
      }
      try {
        await lectureRef.update({'taughtNotes': notes});
      } catch (error, stackTrace) {
        notesError ??= error;
        debugPrint('lecture taughtNotes update on start failed: $error');
        debugPrint('$stackTrace');
      }
      final verified = await loadTaughtNotes(sessionId);
      if (verified.isEmpty) {
        throw StateError(
          'Lecture notes did not save to the database. ${notesError ?? ''}'.trim(),
        );
      }
    }
    return session.copyWith(id: sessionId, startedAt: now);
  }

  Future<LectureSummary?> endLiveSession(
    String courseId,
    String sessionId,
    String teacherId,
  ) async {
    if (courseId.isEmpty || sessionId.isEmpty || teacherId.isEmpty) {
      throw StateError('A valid live session is required.');
    }
    if (_db == null) {
      final sessions = _localLiveSessions[courseId] ?? [];
      final index = sessions.indexWhere((session) => session.id == sessionId);
      if (index < 0 || sessions[index].teacherId != teacherId) {
        throw StateError('Live session not found.');
      }
      final endedAt = DateTime.now();
      final started = sessions[index];
      sessions[index] = started.copyWith(
        status: LiveSessionStatus.ended,
        endedAt: endedAt,
      );
      final lecture = _localLectures[sessionId];
      LectureSummary? summary;
      if (lecture != null) {
        final actual = lecture.startedAt == null
            ? 0
            : endedAt.difference(lecture.startedAt!).inMinutes;
        final actualMinutes = actual < 0 ? 0 : actual;
        final studentCount = _localAttendees[sessionId]?.length ?? 0;
        final endedLecture = lecture.copyWith(
          status: LectureStatus.ended,
          endedAt: endedAt,
          actualDurationMinutes: actualMinutes,
          studentCount: studentCount,
        );
        summary = _summaryForLecture(
          endedLecture,
          attendeeCount: studentCount,
          actualDurationMinutes: actualMinutes,
        ).copyWith(savedAt: endedAt);
        _localLectures[sessionId] = endedLecture.copyWith(summary: summary);
      }
      final courseIndex = _all.indexWhere((course) => course.id == courseId);
      if (courseIndex >= 0) {
        _all[courseIndex] = _all[courseIndex].copyWith(isLive: false);
      }
      notifyListeners();
      return summary;
    }

    final courseRef = _collection!.doc(courseId);
    final sessionRef = _liveSessionCollection(courseId).doc(sessionId);
    final lectureRef = _lecturesCollection.doc(sessionId);
    final teacherRef = _db.collection('users').doc(teacherId);
    LectureSummary? summary;
    await _db.runTransaction((transaction) async {
      final course = await transaction.get(courseRef);
      final session = await transaction.get(sessionRef);
      final lecture = await transaction.get(lectureRef);
      if (!course.exists ||
          !session.exists ||
          course.data()?['teacherId'] != teacherId ||
          session.data()?['teacherId'] != teacherId) {
        throw StateError('Only the course teacher can end this lecture.');
      }
      transaction.update(sessionRef, {
        'status': LiveSessionStatus.ended.name,
        'endedAt': FieldValue.serverTimestamp(),
      });
      if (lecture.exists) {
        final startedAt = lecture.data()?['startedAt'];
        var actualMinutes = 0;
        if (startedAt is Timestamp) {
          actualMinutes = DateTime.now()
              .difference(startedAt.toDate())
              .inMinutes
              .clamp(0, 24 * 60);
        }
        final studentCount =
            (lecture.data()?['studentCount'] as num?)?.toInt() ?? 0;
        final endedLecture = LectureModel.fromMap(sessionId, lecture.data()!)
            .copyWith(
              status: LectureStatus.ended,
              actualDurationMinutes: actualMinutes,
              studentCount: studentCount,
            );
        summary = _summaryForLecture(
          endedLecture,
          attendeeCount: studentCount,
          actualDurationMinutes: actualMinutes,
        );
        transaction.update(lectureRef, {
          'status': LectureStatus.ended.name,
          'endedAt': FieldValue.serverTimestamp(),
          'actualDurationMinutes': actualMinutes,
          'studentCount': studentCount,
        });
      }
      transaction.update(courseRef, {
        'activeSessionId': '',
        'isLive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      transaction.set(teacherRef, {
        'activeLiveCourseId': '',
        'activeLiveSessionId': '',
        'activeLiveUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
    final pendingSummary = summary;
    if (pendingSummary != null) {
      await _trySaveLectureSummary(
        lectureId: sessionId,
        teacherId: teacherId,
        summary: pendingSummary,
      );
    }
    return pendingSummary;
  }

  LectureSummary _summaryForLecture(
    LectureModel lecture, {
    required int attendeeCount,
    required int actualDurationMinutes,
  }) {
    final course = _localCourse(lecture.courseId);
    return LectureSummary.fromLecture(
      lecture,
      courseCode: course?.code ?? '',
      department: course?.department ?? '',
      semester: course?.semester ?? '',
      section: course?.section ?? '',
      attendeeCount: attendeeCount,
      actualDurationMinutes: actualDurationMinutes,
      taughtNotes: lecture.resolvedTaughtNotes,
    );
  }

  Future<void> _trySaveLectureSummary({
    required String lectureId,
    required String teacherId,
    required LectureSummary summary,
  }) async {
    try {
      await saveLectureSummary(
        lectureId: lectureId,
        teacherId: teacherId,
        summary: summary,
      );
    } catch (error, stackTrace) {
      debugPrint('saveLectureSummary failed: $error');
      debugPrint('$stackTrace');
    }
  }

  Stream<LectureModel?> watchLecture(String lectureId) {
    if (_db == null) {
      return Stream<LectureModel?>.value(
        _localLectures[lectureId],
      ).asBroadcastStream();
    }
    return _lecturesCollection
        .doc(lectureId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? LectureModel.fromMap(snapshot.id, snapshot.data()!)
              : null,
        );
  }

  Future<void> saveLectureSummary({
    required String lectureId,
    required String teacherId,
    required LectureSummary summary,
  }) async {
    if (lectureId.isEmpty || teacherId.isEmpty) {
      throw StateError('A valid lecture summary is required.');
    }
    final payload = summary.copyWith(
      lectureId: lectureId,
      sessionId: summary.sessionId.isEmpty ? lectureId : summary.sessionId,
      teacherId: teacherId,
    );
    if (_db == null) {
      final lecture = _localLectures[lectureId];
      if (lecture == null || lecture.teacherId != teacherId) {
        throw StateError('Only the course teacher can save this summary.');
      }
      if (lecture.isActive) {
        throw StateError('Summary can only be saved after the lecture ends.');
      }
      final notes = payload.taughtNotes.trim().isNotEmpty
          ? payload.taughtNotes.trim()
          : lecture.resolvedTaughtNotes;
      final savedPayload = payload.copyWith(
        taughtNotes: notes,
        savedAt: DateTime.now(),
      );
      if (notes.isNotEmpty) {
        _localTeacherNotes[lectureId] = notes;
      }
      _localLectures[lectureId] = lecture.copyWith(
        taughtNotes: notes.isNotEmpty ? notes : lecture.taughtNotes,
        summary: savedPayload,
      );
      notifyListeners();
      return;
    }

    final lectureRef = _lecturesCollection.doc(lectureId);
    final lecture = await lectureRef.get();
    if (!lecture.exists || lecture.data()?['teacherId'] != teacherId) {
      throw StateError('Only the course teacher can save this summary.');
    }
    if (lecture.data()?['status'] != LectureStatus.ended.name) {
      throw StateError('Summary can only be saved after the lecture ends.');
    }

    final existing = LectureModel.fromMap(lectureId, lecture.data()!);
    final notes = payload.taughtNotes.trim().isNotEmpty
        ? payload.taughtNotes.trim()
        : existing.resolvedTaughtNotes;
    final savedPayload = payload.copyWith(taughtNotes: notes);

    var notesSaved = false;
    Object? lastError;

    if (notes.isNotEmpty) {
      try {
        await lectureRef.collection('teacherNotes').doc('current').set({
          'text': notes,
          'teacherId': teacherId,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        notesSaved = true;
      } catch (error, stackTrace) {
        lastError = error;
        debugPrint('teacherNotes save failed: $error');
        debugPrint('$stackTrace');
      }

      try {
        await lectureRef.update({'taughtNotes': notes});
        notesSaved = true;
      } catch (error, stackTrace) {
        lastError = error;
        debugPrint('lecture taughtNotes field save failed: $error');
        debugPrint('$stackTrace');
      }
    }

    try {
      await lectureRef.update({
        'summary': {
          ...savedPayload.toMap(),
          'savedAt': FieldValue.serverTimestamp(),
        },
      });
      notesSaved = notesSaved || notes.isNotEmpty;
    } catch (error, stackTrace) {
      debugPrint('saveLectureSummary summary field failed: $error');
      debugPrint('$stackTrace');
      lastError = error;
    }

    if (notes.isNotEmpty && !notesSaved) {
      throw StateError('Could not save lecture notes. $lastError');
    }
  }

  Future<String> loadTaughtNotes(String lectureId) async {
    if (lectureId.isEmpty) {
      return '';
    }
    if (_db == null) {
      final lecture = _localLectures[lectureId];
      final fromLecture = lecture?.resolvedTaughtNotes ?? '';
      if (fromLecture.isNotEmpty) {
        return fromLecture;
      }
      return _localTeacherNotes[lectureId]?.trim() ?? '';
    }

    final lectureSnap = await _lecturesCollection.doc(lectureId).get();
    if (lectureSnap.exists) {
      final lecture = LectureModel.fromMap(lectureId, lectureSnap.data()!);
      final fromLecture = lecture.resolvedTaughtNotes;
      if (fromLecture.isNotEmpty) {
        return fromLecture;
      }
    }
    final notesSnap = await lectureSnap.reference
        .collection('teacherNotes')
        .doc('current')
        .get();
    return (notesSnap.data()?['text'] as String?)?.trim() ?? '';
  }

  Stream<List<LectureAttendee>> watchLectureAttendees(String lectureId) {
    if (_db == null) {
      final attendees = [...?_localAttendees[lectureId]]
        ..sort((a, b) {
          final left = a.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return left.compareTo(right);
        });
      return Stream<List<LectureAttendee>>.value(attendees).asBroadcastStream();
    }
    return _lecturesCollection
        .doc(lectureId)
        .collection('attendees')
        .snapshots()
        .map((snapshot) {
          final attendees = snapshot.docs
              .map((doc) => LectureAttendee.fromMap(doc.id, doc.data()))
              .toList();
          attendees.sort((a, b) {
            final left = a.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            final right = b.joinedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
            return left.compareTo(right);
          });
          return attendees;
        });
  }

  Future<void> markLectureAttendance({
    required String lectureId,
    required String studentId,
    required String studentName,
    String studentEmail = '',
    String memberId = '',
  }) async {
    if (lectureId.isEmpty || studentId.isEmpty || studentName.trim().isEmpty) {
      return;
    }
    if (_db == null) {
      final lecture = _localLectures[lectureId];
      if (lecture == null) {
        return;
      }
      final attendees = _localAttendees.putIfAbsent(lectureId, () => []);
      if (attendees.any((item) => item.studentId == studentId)) {
        return;
      }
      attendees.add(
        LectureAttendee(
          studentId: studentId,
          studentName: studentName,
          studentEmail: studentEmail,
          memberId: memberId,
          joinedAt: DateTime.now(),
          inApp: true,
          lastSeenAt: DateTime.now(),
        ),
      );
      _localLectures[lectureId] = lecture.copyWith(
        studentCount: attendees.length,
      );
      notifyListeners();
      return;
    }

    final lectureRef = _lecturesCollection.doc(lectureId);
    final attendeeRef = lectureRef.collection('attendees').doc(studentId);
    await _db.runTransaction((transaction) async {
      final lecture = await transaction.get(lectureRef);
      final existing = await transaction.get(attendeeRef);
      final status = lecture.data()?['status'] as String? ?? '';
      if (!lecture.exists || (status != 'active' && status != 'ended')) {
        return;
      }
      if (existing.exists) {
        return;
      }
      transaction.set(attendeeRef, {
        ...LectureAttendee(
          studentId: studentId,
          studentName: studentName.trim(),
          studentEmail: studentEmail,
          memberId: memberId,
          inApp: true,
        ).toMap(),
        'joinedAt': FieldValue.serverTimestamp(),
        'lastSeenAt': FieldValue.serverTimestamp(),
      });
      transaction.update(lectureRef, {'studentCount': FieldValue.increment(1)});
    });
  }

  /// Best-effort foreground presence while the student is in a live lecture.
  Future<void> updateAttendeePresence({
    required String lectureId,
    required String studentId,
    required bool inApp,
  }) async {
    if (lectureId.isEmpty || studentId.isEmpty) {
      return;
    }
    if (_db == null) {
      final attendees = _localAttendees[lectureId];
      if (attendees == null) {
        return;
      }
      final index = attendees.indexWhere((item) => item.studentId == studentId);
      if (index < 0) {
        return;
      }
      attendees[index] = attendees[index].copyWith(
        inApp: inApp,
        lastSeenAt: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    try {
      await _lecturesCollection
          .doc(lectureId)
          .collection('attendees')
          .doc(studentId)
          .update({
            'inApp': inApp,
            'lastSeenAt': FieldValue.serverTimestamp(),
          });
    } catch (_) {
      // Presence is best-effort; ignore permission / missing-doc races.
    }
  }

  CollectionReference<Map<String, dynamic>> _joinRequestCollection(
    String courseId,
    String sessionId,
  ) {
    return _liveSessionCollection(
      courseId,
    ).doc(sessionId).collection('joinRequests');
  }

  Stream<List<LectureJoinRequest>> watchJoinRequests(
    String courseId,
    String sessionId,
  ) {
    if (_db == null) {
      final requests = [...?_localJoinRequests[sessionId]]
        ..sort((a, b) {
          final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
          return left.compareTo(right);
        });
      return Stream.value(requests);
    }
    return _joinRequestCollection(courseId, sessionId)
        .orderBy('requestedAt')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => LectureJoinRequest.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<LectureJoinRequest?> watchMyJoinRequest(
    String courseId,
    String sessionId,
    String studentId,
  ) {
    if (_db == null) {
      final request = (_localJoinRequests[sessionId] ?? const [])
          .where((item) => item.studentId == studentId)
          .firstOrNull;
      return Stream.value(request);
    }
    return _joinRequestCollection(courseId, sessionId)
        .doc(studentId)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? LectureJoinRequest.fromMap(snapshot.id, snapshot.data()!)
              : null,
        );
  }

  Future<LectureJoinRequest> requestJoinLecture({
    required String courseId,
    required String sessionId,
    required String studentId,
    required String studentName,
    String studentEmail = '',
    String memberId = '',
  }) async {
    if (courseId.isEmpty || sessionId.isEmpty || studentId.isEmpty) {
      throw StateError('A valid join request is required.');
    }
    final request = LectureJoinRequest(
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      memberId: memberId,
    );
    if (_db == null) {
      final sessions = _localLiveSessions[courseId] ?? const [];
      final session = sessions
          .where((item) => item.id == sessionId && item.isActive)
          .firstOrNull;
      if (session == null) {
        throw StateError('Live session not found.');
      }
      final requests = _localJoinRequests.putIfAbsent(sessionId, () => []);
      final existingIndex = requests.indexWhere(
        (item) => item.studentId == studentId,
      );
      if (existingIndex >= 0) {
        return requests[existingIndex];
      }
      final created = request.copyWith(requestedAt: DateTime.now());
      requests.add(created);
      notifyListeners();
      return created;
    }

    final sessionRef = _liveSessionCollection(courseId).doc(sessionId);
    final requestRef = _joinRequestCollection(
      courseId,
      sessionId,
    ).doc(studentId);
    await _db.runTransaction((transaction) async {
      final session = await transaction.get(sessionRef);
      final existing = await transaction.get(requestRef);
      if (!session.exists || session.data()?['status'] != 'active') {
        throw StateError('Live session not found.');
      }
      if (existing.exists) {
        return;
      }
      transaction.set(requestRef, {
        ...request.toCreateMap(),
        'requestedAt': FieldValue.serverTimestamp(),
      });
    });
    return request;
  }

  Future<void> acceptJoinRequest({
    required String courseId,
    required String sessionId,
    required String teacherId,
    required String studentId,
  }) async {
    if (courseId.isEmpty ||
        sessionId.isEmpty ||
        teacherId.isEmpty ||
        studentId.isEmpty) {
      throw StateError('A valid join request is required.');
    }
    if (_db == null) {
      final sessions = _localLiveSessions[courseId] ?? [];
      final session = sessions
          .where((item) => item.id == sessionId && item.teacherId == teacherId)
          .firstOrNull;
      if (session == null || !session.isActive) {
        throw StateError('Live session not found.');
      }
      final requests = _localJoinRequests[sessionId] ?? [];
      final index = requests.indexWhere((item) => item.studentId == studentId);
      if (index < 0) {
        throw StateError('Join request not found.');
      }
      final pending = requests[index];
      if (pending.isAccepted) {
        return;
      }
      requests[index] = pending.copyWith(
        status: JoinRequestStatus.accepted,
        respondedAt: DateTime.now(),
      );
      await markLectureAttendance(
        lectureId: sessionId,
        studentId: pending.studentId,
        studentName: pending.studentName,
        studentEmail: pending.studentEmail,
        memberId: pending.memberId,
      );
      notifyListeners();
      return;
    }

    final sessionRef = _liveSessionCollection(courseId).doc(sessionId);
    final requestRef = _joinRequestCollection(
      courseId,
      sessionId,
    ).doc(studentId);
    final lectureRef = _lecturesCollection.doc(sessionId);
    final attendeeRef = lectureRef.collection('attendees').doc(studentId);
    await _db.runTransaction((transaction) async {
      final session = await transaction.get(sessionRef);
      final request = await transaction.get(requestRef);
      final lecture = await transaction.get(lectureRef);
      final attendee = await transaction.get(attendeeRef);
      if (!session.exists ||
          session.data()?['teacherId'] != teacherId ||
          session.data()?['status'] != 'active') {
        throw StateError('Live session not found.');
      }
      if (!request.exists) {
        throw StateError('Join request not found.');
      }
      final data = request.data()!;
      if (data['status'] == JoinRequestStatus.accepted.name) {
        return;
      }
      if (data['status'] != JoinRequestStatus.pending.name) {
        throw StateError('Join request is not pending.');
      }
      transaction.update(requestRef, {
        'status': JoinRequestStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      if (!attendee.exists && lecture.exists) {
        transaction.set(attendeeRef, {
          ...LectureAttendee(
            studentId: studentId,
            studentName: data['studentName'] as String? ?? '',
            studentEmail: data['studentEmail'] as String? ?? '',
            memberId: data['memberId'] as String? ?? '',
          ).toMap(),
          'joinedAt': FieldValue.serverTimestamp(),
        });
        transaction.update(lectureRef, {
          'studentCount': FieldValue.increment(1),
        });
      }
    });
  }

  Future<void> acceptAllJoinRequests({
    required String courseId,
    required String sessionId,
    required String teacherId,
  }) async {
    final requests = await watchJoinRequests(courseId, sessionId).first;
    final pending = requests.where((item) => item.isPending).toList();
    for (final request in pending) {
      await acceptJoinRequest(
        courseId: courseId,
        sessionId: sessionId,
        teacherId: teacherId,
        studentId: request.studentId,
      );
    }
  }

  Stream<LectureFeedback?> watchMyLectureFeedback(
    String lectureId,
    String studentId,
  ) {
    final id = LectureFeedback.docId(lectureId, studentId);
    if (_db == null) {
      return Stream.value(_localFeedback[id]);
    }
    return _feedbackCollection
        .doc(id)
        .snapshots()
        .map(
          (snapshot) => snapshot.exists
              ? LectureFeedback.fromMap(snapshot.id, snapshot.data()!)
              : null,
        );
  }

  Stream<List<LectureModel>> watchTeacherLectures(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream<List<LectureModel>>.value(const []).asBroadcastStream();
    }
    if (_db == null) {
      final items =
          _localLectures.values
              .where((lecture) => lecture.teacherId == teacherId)
              .toList()
            ..sort((a, b) {
              final left = a.endedAt ?? a.startedAt ?? DateTime(0);
              final right = b.endedAt ?? b.startedAt ?? DateTime(0);
              return right.compareTo(left);
            });
      return Stream<List<LectureModel>>.value(items).asBroadcastStream();
    }
    return _lecturesCollection
        .where('teacherId', isEqualTo: teacherId)
        .limit(kTeacherAnalyticsReadLimit)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => LectureModel.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) {
                  final left = a.endedAt ?? a.startedAt ?? DateTime(0);
                  final right = b.endedAt ?? b.startedAt ?? DateTime(0);
                  return right.compareTo(left);
                });
          return items;
        });
  }

  /// Lectures for one course. Reuses the teacher-scoped list query required by
  /// Firestore rules, then filters to [courseId].
  Stream<List<LectureModel>> watchCourseLectures({
    required String courseId,
    required String teacherId,
  }) {
    if (courseId.isEmpty) {
      return Stream<List<LectureModel>>.value(const []).asBroadcastStream();
    }
    return watchTeacherLectures(teacherId).map((lectures) {
      return [
        for (final lecture in lectures)
          if (lecture.courseId == courseId) lecture,
      ];
    });
  }

  Stream<List<LectureFeedback>> watchTeacherFeedback(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream<List<LectureFeedback>>.value(const []).asBroadcastStream();
    }
    if (_db == null) {
      final items =
          _localFeedback.values
              .where((item) => item.teacherId == teacherId)
              .toList()
            ..sort((a, b) {
              final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
              final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
              return right.compareTo(left);
            });
      return Stream<List<LectureFeedback>>.value(items).asBroadcastStream();
    }
    return _feedbackCollection
        .where('teacherId', isEqualTo: teacherId)
        .limit(kTeacherAnalyticsReadLimit)
        .snapshots()
        .map((snapshot) {
          final items =
              snapshot.docs
                  .map((doc) => LectureFeedback.fromMap(doc.id, doc.data()))
                  .toList()
                ..sort((a, b) {
                  final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
                  final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
                  return right.compareTo(left);
                });
          return items;
        });
  }

  Stream<List<AiPracticeAttempt>> watchTeacherPracticeAttempts(
    String teacherId, {
    List<String> lectureIds = const [],
  }) {
    if (teacherId.isEmpty) {
      return Stream<List<AiPracticeAttempt>>.value(
        const [],
      ).asBroadcastStream();
    }
    if (_db == null) {
      return watchPracticeAttemptsForLectures(
        lectureIds.isEmpty ? _localPracticeAttempts.keys.toList() : lectureIds,
        teacherId: teacherId,
      );
    }
    return _watchRemoteTeacherPracticeAttempts(teacherId, lectureIds);
  }

  Stream<List<AiPracticeAttempt>> _watchRemoteTeacherPracticeAttempts(
    String teacherId,
    List<String> lectureIds,
  ) async* {
    try {
      await for (final items in _watchCollectionGroupPracticeAttempts(
        teacherId,
      )) {
        yield items;
      }
    } catch (error, stackTrace) {
      _logFirestoreQueryError(
        'watchTeacherPracticeAttempts collectionGroup',
        error,
        stackTrace,
      );
      yield* watchPracticeAttemptsForLectures(lectureIds, teacherId: teacherId);
    }
  }

  Stream<List<AiPracticeAttempt>> _watchCollectionGroupPracticeAttempts(
    String teacherId,
  ) {
    return _db!
        .collectionGroup('practiceAttempts')
        .where('teacherId', isEqualTo: teacherId)
        .limit(kTeacherAnalyticsReadLimit)
        .snapshots()
        .map(_practiceAttemptsFromSnapshot);
  }

  Stream<List<AiPracticeAttempt>> watchPracticeAttemptsForLectures(
    List<String> lectureIds, {
    String teacherId = '',
  }) {
    final ids = lectureIds
        .where((id) => id.isNotEmpty)
        .take(kTeacherAnalyticsPracticeLectureCap)
        .toList();
    if (ids.isEmpty) {
      return Stream<List<AiPracticeAttempt>>.value(
        const [],
      ).asBroadcastStream();
    }
    if (_db == null) {
      final items = [
        for (final id in ids)
          ...?_localPracticeAttempts[id]?.where(
            (item) =>
                teacherId.isEmpty ||
                item.teacherId == teacherId ||
                item.teacherId.isEmpty,
          ),
      ]..sort(_byPracticeTimeDesc);
      return Stream<List<AiPracticeAttempt>>.value(items).asBroadcastStream();
    }
    if (ids.length == 1) {
      return _watchLecturePracticeAttemptsRemote(ids.single);
    }
    return Stream<List<AiPracticeAttempt>>.multi((controller) {
      final latest = <String, List<AiPracticeAttempt>>{
        for (final id in ids) id: const [],
      };
      final subscriptions = <StreamSubscription<List<AiPracticeAttempt>>>[];
      void emit() {
        if (controller.isClosed) {
          return;
        }
        final items = [for (final list in latest.values) ...list]
          ..sort(_byPracticeTimeDesc);
        controller.add(items);
      }

      for (final id in ids) {
        subscriptions.add(
          _watchLecturePracticeAttemptsRemote(id).listen(
            (items) {
              latest[id] = items;
              emit();
            },
            onError: (Object error, StackTrace stackTrace) {
              _logFirestoreQueryError(
                'watchPracticeAttemptsForLectures($id)',
                error,
                stackTrace,
              );
              latest[id] = const [];
              emit();
            },
          ),
        );
      }
      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
      };
    });
  }

  Stream<List<AiPracticeAttempt>> _watchLecturePracticeAttemptsRemote(
    String lectureId,
  ) {
    return _lecturesCollection
        .doc(lectureId)
        .collection('practiceAttempts')
        .limit(kTeacherAnalyticsReadLimit)
        .snapshots()
        .map(_practiceAttemptsFromSnapshot);
  }

  List<AiPracticeAttempt> _practiceAttemptsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    return snapshot.docs
        .map((doc) => AiPracticeAttempt.fromMap(doc.id, doc.data()))
        .toList()
      ..sort(_byPracticeTimeDesc);
  }

  int _byPracticeTimeDesc(AiPracticeAttempt a, AiPracticeAttempt b) {
    final left = a.completedAt ?? a.createdAt ?? DateTime(0);
    final right = b.completedAt ?? b.createdAt ?? DateTime(0);
    return right.compareTo(left);
  }

  void _logFirestoreQueryError(
    String name,
    Object error, [
    StackTrace? stackTrace,
  ]) {
    if (error is FirebaseException) {
      debugPrint('$name failed: ${error.code} ${error.message}');
    } else {
      debugPrint('$name failed: $error');
    }
    if (stackTrace != null) {
      debugPrint('$stackTrace');
    }
  }

  Future<Map<String, List<LectureAttendee>>> loadAttendeesForLectures(
    List<String> lectureIds,
  ) async {
    final ids = lectureIds
        .where((id) => id.isNotEmpty)
        .take(kTeacherAnalyticsAttendeeLectureCap)
        .toList();
    if (ids.isEmpty) {
      return const {};
    }
    if (_db == null) {
      return {
        for (final id in ids) id: [...?_localAttendees[id]],
      };
    }
    final entries = await Future.wait(
      ids.map((id) async {
        final snapshot = await _lecturesCollection
            .doc(id)
            .collection('attendees')
            .get();
        return MapEntry(id, [
          for (final doc in snapshot.docs)
            LectureAttendee.fromMap(doc.id, doc.data()),
        ]);
      }),
    );
    return {for (final entry in entries) entry.key: entry.value};
  }

  Stream<List<LectureFeedback>> watchLectureFeedback(
    String lectureId, {
    String teacherId = '',
  }) {
    if (_db == null) {
      final items =
          _localFeedback.values
              .where((item) => item.lectureId == lectureId)
              .where((item) => teacherId.isEmpty || item.teacherId == teacherId)
              .toList()
            ..sort((a, b) {
              final left = a.updatedAt ?? a.createdAt ?? DateTime(0);
              final right = b.updatedAt ?? b.createdAt ?? DateTime(0);
              return left.compareTo(right);
            });
      return Stream<List<LectureFeedback>>.value(items).asBroadcastStream();
    }
    Query<Map<String, dynamic>> query = _feedbackCollection.where(
      'lectureId',
      isEqualTo: lectureId,
    );
    // Rules require teacherId == auth.uid for list; include it in the query.
    if (teacherId.isNotEmpty) {
      query = query.where('teacherId', isEqualTo: teacherId);
    }
    return query.snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => LectureFeedback.fromMap(doc.id, doc.data()))
          .toList(),
    );
  }

  Future<LectureFeedback> submitLectureFeedback({
    required LiveSessionModel session,
    required String courseName,
    required String teacherName,
    required String studentId,
    required String studentName,
    required UnderstandingLevel level,
    String studentEmail = '',
    String memberId = '',
    String comment = '',
  }) async {
    if (session.id.isEmpty ||
        session.courseId.isEmpty ||
        studentId.isEmpty ||
        studentName.trim().isEmpty) {
      throw StateError('A valid lecture feedback is required.');
    }
    final id = LectureFeedback.docId(session.id, studentId);

    if (_db == null) {
      final lecture = _localLectures[session.id];
      if (lecture == null || lecture.isActive) {
        throw StateError('Feedback is only allowed after the lecture ends.');
      }
      final attendees = _localAttendees.putIfAbsent(session.id, () => []);
      if (!attendees.any((item) => item.studentId == studentId)) {
        attendees.add(
          LectureAttendee(
            studentId: studentId,
            studentName: studentName,
            studentEmail: studentEmail,
            memberId: memberId,
            joinedAt: DateTime.now(),
          ),
        );
        _localLectures[session.id] = lecture.copyWith(
          studentCount: attendees.length,
        );
      }
      final draft = LectureFeedback(
        id: id,
        lectureId: session.id,
        sessionId: session.id,
        courseId: session.courseId,
        courseName: courseName.trim().isEmpty ? lecture.courseName : courseName,
        teacherId: session.teacherId.isEmpty
            ? lecture.teacherId
            : session.teacherId,
        teacherName: teacherName.trim().isEmpty
            ? lecture.teacherName
            : teacherName,
        studentId: studentId,
        studentName: studentName,
        studentEmail: studentEmail,
        memberId: memberId,
        chapterId: session.chapterId,
        chapterTitle: session.chapterTitle,
        topicId: session.topicId,
        topicTitle: session.topicTitle,
        level: level,
        comment: comment,
      );
      final existing = _localFeedback[id];
      final now = DateTime.now();
      final saved = draft.copyWith(
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      _localFeedback[id] = saved;
      notifyListeners();
      return saved;
    }

    final lectureRef = _lecturesCollection.doc(session.id);
    final feedbackRef = _feedbackCollection.doc(id);

    var lecture = await lectureRef.get();
    if (!lecture.exists || lecture.data()?['status'] != 'ended') {
      final liveSnap = await _liveSessionCollection(
        session.courseId,
      ).doc(session.id).get();
      final liveStatus = liveSnap.data()?['status'] as String? ?? '';
      if (liveStatus != LiveSessionStatus.ended.name) {
        throw StateError('Feedback is only allowed after the lecture ends.');
      }
      // Brief wait — lecture doc can lag the live session end write.
      await Future<void>.delayed(const Duration(milliseconds: 800));
      lecture = await lectureRef.get();
    }
    if (!lecture.exists || lecture.data()?['status'] != 'ended') {
      throw StateError(
        'Lecture is not marked ended yet. Wait a moment and try again.',
      );
    }

    final lectureData = lecture.data()!;
    final resolvedCourseId =
        (lectureData['courseId'] as String?)?.trim().isNotEmpty == true
        ? lectureData['courseId'] as String
        : session.courseId;
    final resolvedTeacherId =
        (lectureData['teacherId'] as String?)?.trim().isNotEmpty == true
        ? lectureData['teacherId'] as String
        : session.teacherId;
    final resolvedCourseName = courseName.trim().isNotEmpty
        ? courseName.trim()
        : ((lectureData['courseName'] as String?)?.trim().isNotEmpty == true
              ? lectureData['courseName'] as String
              : 'Course');
    final resolvedTeacherName = teacherName.trim().isNotEmpty
        ? teacherName.trim()
        : ((lectureData['teacherName'] as String?)?.trim().isNotEmpty == true
              ? lectureData['teacherName'] as String
              : 'Teacher');
    if (resolvedCourseId.isEmpty || resolvedTeacherId.isEmpty) {
      throw StateError('A valid lecture feedback is required.');
    }

    final draft = LectureFeedback(
      id: id,
      lectureId: session.id,
      sessionId: session.id,
      courseId: resolvedCourseId,
      courseName: resolvedCourseName,
      teacherId: resolvedTeacherId,
      teacherName: resolvedTeacherName,
      studentId: studentId,
      studentName: studentName.trim(),
      studentEmail: studentEmail.trim().toLowerCase(),
      memberId: memberId.trim(),
      chapterId: session.chapterId,
      chapterTitle: session.chapterTitle,
      topicId: session.topicId,
      topicTitle: session.topicTitle,
      level: level,
      comment: comment,
    );

    final existing = await feedbackRef.get();
    if (existing.exists) {
      await feedbackRef.update({
        'level': level.storageValue,
        'comment': comment.trim(),
        'studentName': studentName.trim(),
        'studentEmail': studentEmail.trim().toLowerCase(),
        'memberId': memberId.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } else {
      await feedbackRef.set({
        ...draft.toCreateMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }
    return draft;
  }

  Future<int> _nextPosition(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final snapshot = await collection
        .orderBy('position', descending: true)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) {
      return 0;
    }
    return ((snapshot.docs.first.data()['position'] as num?)?.toInt() ?? -1) +
        1;
  }

  Future<void> _deleteCourseChapters(String courseId) async {
    final chapters = await _chapterCollection(courseId).get();
    for (final chapter in chapters.docs) {
      final topics = await chapter.reference.collection('topics').get();
      final batch = _db!.batch();
      for (final topic in topics.docs) {
        batch.delete(topic.reference);
      }
      batch.delete(chapter.reference);
      await batch.commit();
    }
  }

  Future<void> _deleteCourseLiveSessions(String courseId) async {
    final sessions = await _liveSessionCollection(courseId).get();
    if (sessions.docs.isEmpty) {
      return;
    }
    final batch = _db!.batch();
    for (final session in sessions.docs) {
      batch.delete(session.reference);
    }
    await batch.commit();
  }

  void _adjustLocalTopicCount(String courseId, int delta) {
    final course = _localCourse(courseId);
    if (course == null || delta == 0) {
      return;
    }
    final next = (course.topicCount + delta).clamp(0, 1 << 31).toInt();
    final index = _all.indexWhere((item) => item.id == courseId);
    _all[index] = course.copyWith(topicCount: next);
  }

  CourseModel? _localCourse(String courseId) {
    for (final course in _all) {
      if (course.id == courseId) {
        return course;
      }
    }
    return null;
  }

  void _replaceLocal(CourseModel course) {
    final index = _all.indexWhere((item) => item.id == course.id);
    if (index < 0) {
      _all.add(course);
    } else {
      _all[index] = course;
    }
    notifyListeners();
  }

  Stream<List<CourseAnnouncement>> watchAnnouncements(String courseId) {
    return _watchDoc(courseId).map((data) {
      final items = announcementsFrom(data?['announcements']);
      items.sort((a, b) {
        final left = a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
      return items;
    });
  }

  Stream<List<SyllabusWeek>> watchSyllabus(String courseId) {
    return _watchDoc(courseId).map((data) => syllabusFrom(data?['syllabus']));
  }

  Stream<List<CourseLecture>> watchLectures(String courseId) {
    return _watchDoc(courseId).map((data) {
      final items = lecturesFrom(data?['lectures']);
      items.sort((a, b) {
        final left = a.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.date ?? DateTime.fromMillisecondsSinceEpoch(0);
        return left.compareTo(right);
      });
      return items;
    });
  }

  Stream<List<CourseAssignment>> watchAssignments(String courseId) {
    return _watchDoc(
      courseId,
    ).map((data) => assignmentsFrom(data?['assignments']));
  }

  Stream<List<CourseResource>> watchResources(String courseId) {
    return _watchDoc(courseId).map((data) => resourcesFrom(data?['resources']));
  }

  Future<int> nextSyllabusWeekNumber(String courseId) async {
    final collection = _collection;
    if (collection == null) {
      return (_localCourse(courseId)?.syllabus.length ?? 0) + 1;
    }
    final doc = await collection.doc(courseId).get();
    return syllabusFrom(doc.data()?['syllabus']).length + 1;
  }

  Stream<Map<String, dynamic>?> _watchDoc(String courseId) {
    final collection = _collection;
    if (collection == null) {
      final course = _localCourse(courseId);
      return Stream.value({
        'announcements': course?.announcements
            .map((item) => item.toMap())
            .toList(),
        'syllabus': course?.syllabus.map((item) => item.toMap()).toList(),
        'lectures': course?.lectures.map((item) => item.toMap()).toList(),
        'assignments': course?.assignments.map((item) => item.toMap()).toList(),
        'resources': course?.resources.map((item) => item.toMap()).toList(),
      });
    }
    return collection.doc(courseId).snapshots().map((doc) => doc.data());
  }

  Future<void> addAnnouncement(String courseId, CourseAnnouncement item) async {
    await _addContent(
      courseId: courseId,
      field: 'announcements',
      data: item.toMap(),
      applyLocal: (course) =>
          course.copyWith(announcements: [item, ...course.announcements]),
    );
  }

  Future<void> addSyllabusWeek(String courseId, SyllabusWeek item) async {
    await _addContent(
      courseId: courseId,
      field: 'syllabus',
      data: item.toMap(),
      applyLocal: (course) =>
          course.copyWith(syllabus: [...course.syllabus, item]),
    );
  }

  Future<void> addLecture(String courseId, CourseLecture item) async {
    await _addContent(
      courseId: courseId,
      field: 'lectures',
      data: item.toMap(),
      applyLocal: (course) =>
          course.copyWith(lectures: [...course.lectures, item]),
    );
  }

  Future<void> addAssignment(String courseId, CourseAssignment item) async {
    await _addContent(
      courseId: courseId,
      field: 'assignments',
      data: item.toMap(),
      applyLocal: (course) =>
          course.copyWith(assignments: [...course.assignments, item]),
    );
  }

  Future<void> addResource(String courseId, CourseResource item) async {
    await _addContent(
      courseId: courseId,
      field: 'resources',
      data: item.toMap(),
      applyLocal: (course) =>
          course.copyWith(resources: [...course.resources, item]),
    );
  }

  Future<void> addSyllabusFiles(
    String courseId,
    List<CourseAttachment> files,
  ) async {
    for (final file in files) {
      await _addContent(
        courseId: courseId,
        field: 'syllabusFiles',
        data: file.toMap(),
        applyLocal: (course) =>
            course.copyWith(syllabusFiles: [...course.syllabusFiles, file]),
      );
    }
  }

  Future<void> updateSyllabusWeek(String courseId, SyllabusWeek item) {
    return _replaceContent(
      courseId: courseId,
      field: 'syllabus',
      itemId: item.id,
      data: item.toMap(),
      applyLocal: (course) {
        final items = [...course.syllabus];
        final index = items.indexWhere((entry) => entry.id == item.id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        return course.copyWith(syllabus: items);
      },
    );
  }

  Future<void> updateLecture(String courseId, CourseLecture item) {
    return _replaceContent(
      courseId: courseId,
      field: 'lectures',
      itemId: item.id,
      data: item.toMap(),
      applyLocal: (course) {
        final items = [...course.lectures];
        final index = items.indexWhere((entry) => entry.id == item.id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        return course.copyWith(lectures: items);
      },
    );
  }

  Future<void> updateAssignment(String courseId, CourseAssignment item) {
    return _replaceContent(
      courseId: courseId,
      field: 'assignments',
      itemId: item.id,
      data: item.toMap(),
      applyLocal: (course) {
        final items = [...course.assignments];
        final index = items.indexWhere((entry) => entry.id == item.id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        return course.copyWith(assignments: items);
      },
    );
  }

  Future<void> updateResource(String courseId, CourseResource item) {
    return _replaceContent(
      courseId: courseId,
      field: 'resources',
      itemId: item.id,
      data: item.toMap(),
      applyLocal: (course) {
        final items = [...course.resources];
        final index = items.indexWhere((entry) => entry.id == item.id);
        if (index < 0) {
          items.add(item);
        } else {
          items[index] = item;
        }
        return course.copyWith(resources: items);
      },
    );
  }

  Future<void> _addContent({
    required String courseId,
    required String field,
    required Map<String, dynamic> data,
    required CourseModel Function(CourseModel course) applyLocal,
  }) async {
    if (courseId.isEmpty) {
      throw StateError('Cannot save content without a course id.');
    }
    final collection = _collection;
    if (collection == null) {
      final current = _localCourse(courseId);
      if (current == null) {
        throw StateError('Course not found.');
      }
      _replaceLocal(applyLocal(current));
      return;
    }
    final cleaned = Map<String, dynamic>.from(data)
      ..removeWhere((_, value) => value == null);
    await collection.doc(courseId).update({
      field: FieldValue.arrayUnion([cleaned]),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _replaceContent({
    required String courseId,
    required String field,
    required String itemId,
    required Map<String, dynamic> data,
    required CourseModel Function(CourseModel course) applyLocal,
  }) async {
    if (courseId.isEmpty || itemId.isEmpty) {
      throw StateError('Cannot update content without an id.');
    }
    final collection = _collection;
    if (collection == null) {
      final current = _localCourse(courseId);
      if (current == null) {
        throw StateError('Course not found.');
      }
      _replaceLocal(applyLocal(current));
      return;
    }
    final snapshot = await collection.doc(courseId).get();
    final existing = snapshot.data()?[field];
    final items = <Map<String, dynamic>>[
      for (final item in (existing is List ? existing : const []))
        if (item is Map) Map<String, dynamic>.from(item),
    ];
    final cleaned = Map<String, dynamic>.from(data)
      ..removeWhere((_, value) => value == null);
    cleaned['id'] = itemId;
    final index = items.indexWhere((item) => item['id'] == itemId);
    if (index < 0) {
      items.add(cleaned);
    } else {
      items[index] = cleaned;
    }
    await collection.doc(courseId).update({
      field: items,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<List<AiPracticeAttempt>> watchLecturePracticeAttempts(
    String lectureId,
  ) {
    if (_db == null) {
      final items = [...?_localPracticeAttempts[lectureId]]
        ..sort((a, b) {
          final left = a.completedAt ?? a.createdAt ?? DateTime(0);
          final right = b.completedAt ?? b.createdAt ?? DateTime(0);
          return left.compareTo(right);
        });
      return Stream<List<AiPracticeAttempt>>.value(items).asBroadcastStream();
    }
    return _lecturesCollection
        .doc(lectureId)
        .collection('practiceAttempts')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AiPracticeAttempt.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Stream<List<AiPracticeAttempt>> watchMyPracticeAttempts({
    required String lectureId,
    required String studentId,
  }) {
    if (_db == null) {
      final items = localMyPracticeAttempts(
        lectureId: lectureId,
        studentId: studentId,
      );
      return Stream<List<AiPracticeAttempt>>.value(items).asBroadcastStream();
    }
    return _lecturesCollection
        .doc(lectureId)
        .collection('practiceAttempts')
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AiPracticeAttempt.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  /// Sync read of in-memory practice attempts for one student/lecture.
  /// Prefer this on list tiles so scroll never waits on Firestore.
  List<AiPracticeAttempt> localMyPracticeAttempts({
    required String lectureId,
    required String studentId,
  }) {
    final items = [
      ...?_localPracticeAttempts[lectureId],
    ].where((item) => item.studentId == studentId).toList()
      ..sort(_byPracticeTimeDesc);
    return List.unmodifiable(items);
  }

  bool hasLocalPracticeAttempt({
    required String lectureId,
    required String studentId,
  }) {
    return localMyPracticeAttempts(
      lectureId: lectureId,
      studentId: studentId,
    ).isNotEmpty;
  }

  void _mirrorPracticeAttempt(AiPracticeAttempt attempt) {
    final items = _localPracticeAttempts.putIfAbsent(
      attempt.lectureId,
      () => <AiPracticeAttempt>[],
    );
    final index = items.indexWhere((item) => item.id == attempt.id);
    if (index >= 0) {
      items[index] = attempt;
    } else {
      items.add(attempt);
    }
  }

  void _mirrorPracticeAttempts(
    String lectureId,
    List<AiPracticeAttempt> attempts,
  ) {
    final items = _localPracticeAttempts.putIfAbsent(
      lectureId,
      () => <AiPracticeAttempt>[],
    );
    for (final attempt in attempts) {
      final index = items.indexWhere((item) => item.id == attempt.id);
      if (index >= 0) {
        items[index] = attempt;
      } else {
        items.add(attempt);
      }
    }
  }

  /// One-shot remote read with a short timeout. Never call from build.
  /// Merges into the local mirror and notifies so list tiles can flip.
  Future<List<AiPracticeAttempt>> fetchMyPracticeAttemptsOnce({
    required String lectureId,
    required String studentId,
    Duration timeout = const Duration(seconds: 3),
  }) async {
    if (lectureId.isEmpty || studentId.isEmpty) {
      return const [];
    }
    if (_db == null) {
      return localMyPracticeAttempts(
        lectureId: lectureId,
        studentId: studentId,
      );
    }
    try {
      final snapshot = await _lecturesCollection
          .doc(lectureId)
          .collection('practiceAttempts')
          .where('studentId', isEqualTo: studentId)
          .get()
          .timeout(timeout);
      final items = [
        for (final doc in snapshot.docs)
          AiPracticeAttempt.fromMap(doc.id, doc.data()),
      ]..sort(_byPracticeTimeDesc);
      _mirrorPracticeAttempts(lectureId, items);
      notifyListeners();
      return List.unmodifiable(items);
    } catch (_) {
      return localMyPracticeAttempts(
        lectureId: lectureId,
        studentId: studentId,
      );
    }
  }

  Future<AiPracticeAttempt> savePracticeAttempt({
    required AiPracticeAttempt attempt,
  }) async {
    if (attempt.lectureId.isEmpty ||
        attempt.studentId.isEmpty ||
        attempt.courseId.isEmpty) {
      throw StateError('A valid practice attempt is required.');
    }
    final now = DateTime.now();
    final id = attempt.id.isNotEmpty
        ? attempt.id
        : '${attempt.studentId}_${now.millisecondsSinceEpoch}';
    final localLecture = _localLectures[attempt.lectureId];
    final teacherId = attempt.teacherId.isNotEmpty
        ? attempt.teacherId
        : (localLecture?.teacherId ?? '');
    final saved = AiPracticeAttempt(
      id: id,
      lectureId: attempt.lectureId,
      courseId: attempt.courseId,
      courseName: attempt.courseName,
      teacherId: teacherId,
      studentId: attempt.studentId,
      studentName: attempt.studentName,
      topicTitle: attempt.topicTitle,
      chapterTitle: attempt.chapterTitle,
      score: attempt.score,
      total: attempt.total,
      selectedIndexes: attempt.selectedIndexes,
      diagnostic: attempt.diagnostic,
      questions: attempt.questions,
      completed: true,
      createdAt: attempt.createdAt ?? now,
      completedAt: now,
    );

    if (_db == null) {
      final lecture = localLecture;
      if (lecture == null || lecture.isActive) {
        throw StateError('Practice is only allowed after the lecture ends.');
      }
      _mirrorPracticeAttempt(saved);
      notifyListeners();
      return saved;
    }

    final lectureRef = _lecturesCollection.doc(attempt.lectureId);
    final attemptRef = lectureRef.collection('practiceAttempts').doc(id);
    late final AiPracticeAttempt persisted;
    await _db.runTransaction((transaction) async {
      final lecture = await transaction.get(lectureRef);
      if (!lecture.exists || lecture.data()?['status'] != 'ended') {
        throw StateError('Practice is only allowed after the lecture ends.');
      }
      final resolvedTeacherId = saved.teacherId.isNotEmpty
          ? saved.teacherId
          : (lecture.data()?['teacherId'] as String? ?? '');
      persisted = AiPracticeAttempt(
        id: saved.id,
        lectureId: saved.lectureId,
        courseId: saved.courseId,
        courseName: saved.courseName,
        teacherId: resolvedTeacherId,
        studentId: saved.studentId,
        studentName: saved.studentName,
        topicTitle: saved.topicTitle,
        chapterTitle: saved.chapterTitle,
        score: saved.score,
        total: saved.total,
        selectedIndexes: saved.selectedIndexes,
        diagnostic: saved.diagnostic,
        questions: saved.questions,
        completed: true,
        createdAt: saved.createdAt,
        completedAt: saved.completedAt,
      );
      transaction.set(attemptRef, {
        ...persisted.toCreateMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'completedAt': FieldValue.serverTimestamp(),
      });
    });
    // Mirror + notify so the AI Practice list flips buttons in the same session
    // without a bulk loadAll on screen init.
    _mirrorPracticeAttempt(persisted);
    notifyListeners();
    return persisted;
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
