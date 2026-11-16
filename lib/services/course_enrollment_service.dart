import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/course_join_request.dart';
import '../../models/course_member.dart';
import '../../models/course_model.dart';
import '../../models/lecture_join_request.dart';

/// Course membership + join requests (separate from live-lecture joinRequests).
class CourseEnrollmentService {
  CourseEnrollmentService({FirebaseFirestore? firestore}) : _db = firestore;

  final FirebaseFirestore? _db;
  final Map<String, List<CourseJoinRequest>> _localRequests = {};
  final Map<String, Set<String>> _localMembers = {};
  final Map<String, Map<String, CourseMember>> _localMemberDetails = {};
  final StreamController<void> _localEnrollmentEvents =
      StreamController<void>.broadcast();

  void _emitLocalEnrollmentEvent() {
    if (!_localEnrollmentEvents.isClosed) {
      _localEnrollmentEvents.add(null);
    }
  }

  List<CourseJoinRequest> _localPendingRequests() {
    final pending = _localRequests.values
        .expand((items) => items)
        .where((request) => request.isPending)
        .toList()
      ..sort((a, b) {
        final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
    return pending;
  }

  /// Re-emits whenever a local join request is created, accepted, or declined.
  Stream<List<CourseJoinRequest>> _watchLocalPending(
    List<CourseJoinRequest> Function() read,
  ) {
    late final StreamController<List<CourseJoinRequest>> controller;
    StreamSubscription<void>? subscription;
    controller = StreamController<List<CourseJoinRequest>>(
      onListen: () {
        subscription = _localEnrollmentEvents.stream.listen((_) {
          if (!controller.isClosed) {
            controller.add(read());
          }
        });
        controller.add(read());
      },
      onCancel: () {
        subscription?.cancel();
      },
    );
    return controller.stream;
  }

  CollectionReference<Map<String, dynamic>>? _requestCol(String courseId) =>
      _db?.collection('courses').doc(courseId).collection('joinRequests');

  CollectionReference<Map<String, dynamic>>? _memberCol(String courseId) =>
      _db?.collection('courses').doc(courseId).collection('members');

  Stream<CourseJoinRequest?> watchMyRequest(String courseId, String studentId) {
    if (courseId.isEmpty || studentId.isEmpty) {
      return Stream.value(null);
    }
    if (_db == null) {
      final req = (_localRequests[courseId] ?? const [])
          .where((item) => item.studentId == studentId)
          .firstOrNull;
      return Stream.value(req);
    }
    return _requestCol(courseId)!
        .doc(studentId)
        .snapshots()
        .map(
          (snap) => snap.exists
              ? CourseJoinRequest.fromMap(snap.id, snap.data()!)
              : null,
        );
  }

  Stream<bool> watchIsMember(String courseId, String studentId) {
    if (courseId.isEmpty || studentId.isEmpty) {
      return Stream.value(false);
    }
    if (_db == null) {
      return Stream.value(_localMembers[courseId]?.contains(studentId) ?? false);
    }
    return _memberCol(courseId)!
        .doc(studentId)
        .snapshots()
        .map((snap) => snap.exists);
  }

  /// Collection-group query. Security rules deny this list because
  /// `isCourseTeacher` uses `get()` and the query is not constrained to one
  /// course. Callers that need a live pending flag should use
  /// [watchHasPendingForCourses] with the teacher's courses instead.
  Stream<List<CourseJoinRequest>> watchPendingForTeacher(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream.value(const []);
    }
    if (_db == null) {
      return _watchLocalPending(_localPendingRequests);
    }
    return _db
        .collectionGroup('joinRequests')
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .snapshots()
        .asyncMap((snapshot) async {
      final items = <CourseJoinRequest>[];
      for (final doc in snapshot.docs) {
        // Only course-level joinRequests: courses/{id}/joinRequests/{uid}
        // Skip live session ones: courses/{id}/liveSessions/{sid}/joinRequests/{uid}
        final parts = doc.reference.path.split('/');
        if (parts.length != 4 || parts[0] != 'courses' || parts[2] != 'joinRequests') {
          continue;
        }
        final data = doc.data();
        final courseId = parts[1];
        // Verify teacher owns course
        final course = await _db.collection('courses').doc(courseId).get();
        if (!course.exists || course.data()?['teacherId'] != teacherId) {
          continue;
        }
        items.add(
          CourseJoinRequest.fromMap(doc.id, {
            ...data,
            'courseId': data['courseId'] ?? courseId,
            'courseName': data['courseName'] ?? course.data()?['name'] ?? '',
            'courseCode': data['courseCode'] ?? course.data()?['code'] ?? '',
          }),
        );
      }
      items.sort((a, b) {
        final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return right.compareTo(left);
      });
      return items;
    });
  }


  Stream<List<CourseJoinRequest>> watchPendingForCourse(String courseId) {
    if (courseId.isEmpty) {
      return Stream.value(const []);
    }
    if (_db == null) {
      return _watchLocalPending(() {
        return (_localRequests[courseId] ?? const <CourseJoinRequest>[])
            .where((item) => item.isPending)
            .toList();
      });
    }
    return _requestCol(courseId)!
        .where('status', isEqualTo: JoinRequestStatus.pending.name)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => CourseJoinRequest.fromMap(doc.id, {
                    ...doc.data(),
                    'courseId': doc.data()['courseId'] ?? courseId,
                  }))
              .toList(),
        );
  }

  /// True while any of [courseIds] has a pending course join request.
  ///
  /// Uses the same per-course query as the joining-requests list.
  Stream<bool> watchHasPendingForCourses(Iterable<String> courseIds) {
    final ids = courseIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList()
      ..sort();
    if (ids.isEmpty) {
      return Stream<bool>.value(false);
    }

    late final StreamController<bool> controller;
    final subscriptions = <StreamSubscription<List<CourseJoinRequest>>>[];
    final pending = List<bool>.filled(ids.length, false);

    void emit() {
      if (!controller.isClosed) {
        controller.add(pending.any((value) => value));
      }
    }

    controller = StreamController<bool>(
      onListen: () {
        for (var i = 0; i < ids.length; i++) {
          final index = i;
          subscriptions.add(
            watchPendingForCourse(ids[index]).listen(
              (requests) {
                pending[index] = requests.isNotEmpty;
                emit();
              },
              onError: (Object _, StackTrace _) {
                pending[index] = false;
                emit();
              },
            ),
          );
        }
      },
      onCancel: () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      },
    );
    return controller.stream;
  }

  /// Seeds one local request. Used to simulate an older declined document.
  @visibleForTesting
  void debugSeedLocalRequest(CourseJoinRequest request) {
    if (_db != null) {
      throw StateError('debugSeedLocalRequest is only for local tests.');
    }
    final list = _localRequests.putIfAbsent(request.courseId, () => []);
    final index = list.indexWhere((item) => item.studentId == request.studentId);
    if (index >= 0) {
      list[index] = request;
    } else {
      list.add(request);
    }
    _emitLocalEnrollmentEvent();
  }

  Future<CourseJoinRequest> requestJoin({
    required String courseId,
    required String courseName,
    required String courseCode,
    required String studentId,
    required String studentName,
    String studentEmail = '',
    String memberId = '',
  }) async {
    if (courseId.isEmpty || studentId.isEmpty) {
      throw StateError('A valid course join request is required.');
    }
    final request = CourseJoinRequest(
      studentId: studentId,
      studentName: studentName,
      courseId: courseId,
      courseName: courseName,
      courseCode: courseCode,
      studentEmail: studentEmail,
      memberId: memberId,
    );
    if (_db == null) {
      if (_localMembers[courseId]?.contains(studentId) ?? false) {
        throw StateError('Already enrolled in this course.');
      }
      final list = _localRequests.putIfAbsent(courseId, () => []);
      final existingIndex = list.indexWhere((e) => e.studentId == studentId);
      if (existingIndex >= 0) {
        final existing = list[existingIndex];
        if (existing.isPending) {
          return existing;
        }
        // A rejected (or otherwise closed) request must not block a new one.
        list.removeAt(existingIndex);
      }
      final created = request.copyWith(requestedAt: DateTime.now());
      list.add(created);
      _emitLocalEnrollmentEvent();
      return created;
    }

    final memberRef = _memberCol(courseId)!.doc(studentId);
    final requestRef = _requestCol(courseId)!.doc(studentId);
    await _db.runTransaction((tx) async {
      final member = await tx.get(memberRef);
      if (member.exists) {
        throw StateError('Already enrolled in this course.');
      }
      final existing = await tx.get(requestRef);
      final payload = <String, dynamic>{
        ...request.toCreateMap(),
        'requestedAt': FieldValue.serverTimestamp(),
      };
      if (!existing.exists) {
        tx.set(requestRef, payload);
        return;
      }
      final status = existing.data()?['status'];
      if (status == JoinRequestStatus.pending.name) {
        return;
      }
      if (status != JoinRequestStatus.declined.name) {
        throw StateError('Join request could not be sent.');
      }
      // Older rejects left a declined doc. Students cannot create over it,
      // so reopen that doc as pending. New rejects delete the doc instead.
      tx.update(requestRef, {
        ...payload,
        'respondedAt': FieldValue.delete(),
      });
    });
    return request;
  }

  Future<void> accept({
    required String courseId,
    required String teacherId,
    required String studentId,
  }) async {
    if (courseId.isEmpty || teacherId.isEmpty || studentId.isEmpty) {
      throw StateError('A valid course join request is required.');
    }
    if (_db == null) {
      final list = _localRequests[courseId] ?? [];
      final index = list.indexWhere((e) => e.studentId == studentId);
      if (index < 0) {
        throw StateError('Join request not found.');
      }
      final pending = list[index];
      list[index] = pending.copyWith(
        status: JoinRequestStatus.accepted,
        respondedAt: DateTime.now(),
      );
      _localMembers.putIfAbsent(courseId, () => {}).add(studentId);
      _localMemberDetails.putIfAbsent(courseId, () => {})[studentId] =
          CourseMember(
        studentId: studentId,
        studentName: pending.studentName,
        studentEmail: pending.studentEmail,
        memberId: pending.memberId,
        courseId: courseId,
        joinedAt: DateTime.now(),
      );
      _emitLocalEnrollmentEvent();
      return;
    }

    final courseRef = _db.collection('courses').doc(courseId);
    final requestRef = _requestCol(courseId)!.doc(studentId);
    final memberRef = _memberCol(courseId)!.doc(studentId);
    await _db.runTransaction((tx) async {
      final course = await tx.get(courseRef);
      final request = await tx.get(requestRef);
      if (!course.exists || course.data()?['teacherId'] != teacherId) {
        throw StateError('Course not found.');
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
      tx.update(requestRef, {
        'status': JoinRequestStatus.accepted.name,
        'respondedAt': FieldValue.serverTimestamp(),
      });
      tx.set(memberRef, {
        'studentId': studentId,
        'studentName': data['studentName'] ?? '',
        'studentEmail': data['studentEmail'] ?? '',
        'memberId': data['memberId'] ?? '',
        'courseId': courseId,
        'joinedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> decline({
    required String courseId,
    required String teacherId,
    required String studentId,
  }) async {
    if (courseId.isEmpty || teacherId.isEmpty || studentId.isEmpty) {
      throw StateError('A valid course join request is required.');
    }
    if (_db == null) {
      final list = _localRequests[courseId] ?? [];
      final index = list.indexWhere((e) => e.studentId == studentId);
      if (index < 0) {
        throw StateError('Join request not found.');
      }
      if (!list[index].isPending) {
        throw StateError('Join request is not pending.');
      }
      // Remove the doc so the student can create a new pending request.
      list.removeAt(index);
      _emitLocalEnrollmentEvent();
      return;
    }

    final courseRef = _db.collection('courses').doc(courseId);
    final requestRef = _requestCol(courseId)!.doc(studentId);
    await _db.runTransaction((tx) async {
      final course = await tx.get(courseRef);
      final request = await tx.get(requestRef);
      if (!course.exists || course.data()?['teacherId'] != teacherId) {
        throw StateError('Course not found.');
      }
      if (!request.exists) {
        throw StateError('Join request not found.');
      }
      final data = request.data()!;
      if (data['status'] != JoinRequestStatus.pending.name) {
        throw StateError('Join request is not pending.');
      }
      tx.delete(requestRef);
    });
  }

  Stream<List<CourseMember>> watchMembers(String courseId) {
    if (courseId.isEmpty) {
      return Stream.value(const []);
    }
    if (_db == null) {
      final details = _localMemberDetails[courseId] ?? const {};
      final list = details.values.toList()
        ..sort(
          (a, b) => a.studentName.toLowerCase().compareTo(
                b.studentName.toLowerCase(),
              ),
        );
      return Stream.value(list);
    }
    return _memberCol(courseId)!.snapshots().map((snapshot) {
      final items = snapshot.docs
          .map((doc) => CourseMember.fromMap(doc.id, doc.data()))
          .toList()
        ..sort(
          (a, b) => a.studentName.toLowerCase().compareTo(
                b.studentName.toLowerCase(),
              ),
        );
      return items;
    });
  }


  /// Live list of [candidates] where [studentId] is currently a member.
  /// Emits whenever any membership doc changes (e.g. teacher unenrolls).
  Stream<List<CourseModel>> watchJoinedFromCandidates({
    required String studentId,
    required List<CourseModel> candidates,
  }) {
    if (studentId.isEmpty || candidates.isEmpty) {
      return Stream.value(const []);
    }

    late final StreamController<List<CourseModel>> controller;
    final subscriptions = <StreamSubscription<bool>>[];
    final flags = List<bool>.filled(candidates.length, false);

    void emit() {
      if (controller.isClosed) {
        return;
      }
      final joined = <CourseModel>[
        for (var i = 0; i < candidates.length; i++)
          if (flags[i]) candidates[i],
      ];
      controller.add(joined);
    }

    controller = StreamController<List<CourseModel>>(
      onListen: () {
        for (var i = 0; i < candidates.length; i++) {
          final index = i;
          subscriptions.add(
            watchIsMember(candidates[index].id, studentId).listen((isMember) {
              flags[index] = isMember;
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

  /// Removes a student from the course. Deletes membership and the join
  /// request so they can request to join again later.
  Future<void> removeMember({
    required String courseId,
    required String teacherId,
    required String studentId,
  }) async {
    if (courseId.isEmpty || teacherId.isEmpty || studentId.isEmpty) {
      throw StateError('A valid course membership is required.');
    }
    if (_db == null) {
      _localMembers[courseId]?.remove(studentId);
      _localMemberDetails[courseId]?.remove(studentId);
      final list = _localRequests[courseId];
      if (list != null) {
        list.removeWhere((e) => e.studentId == studentId);
      }
      _emitLocalEnrollmentEvent();
      return;
    }

    final courseRef = _db.collection('courses').doc(courseId);
    final memberRef = _memberCol(courseId)!.doc(studentId);
    final requestRef = _requestCol(courseId)!.doc(studentId);

    // Verify ownership outside the write so a join-request rule failure
    // cannot roll back removing membership (unenroll).
    final course = await courseRef.get();
    if (!course.exists || course.data()?['teacherId'] != teacherId) {
      throw StateError('Course not found.');
    }

    final member = await memberRef.get();
    if (member.exists) {
      await memberRef.delete();
    }

    // Best-effort: clear join request so the student can request again.
    // Older deployed rules may still deny this delete — membership is already gone.
    try {
      final request = await requestRef.get();
      if (request.exists) {
        await requestRef.delete();
      }
    } catch (_) {
      // Ignore — unenroll already succeeded via member delete.
    }
  }
}
