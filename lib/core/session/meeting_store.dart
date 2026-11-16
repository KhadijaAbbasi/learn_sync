import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../../models/meeting_request.dart';

class MeetingStore extends ChangeNotifier {
  MeetingStore({FirebaseFirestore? firestore}) : _db = firestore;

  final FirebaseFirestore? _db;
  final Map<String, MeetingRequest> _local = {};

  CollectionReference<Map<String, dynamic>> get _collection =>
      _db!.collection('meetingRequests');

  Stream<List<MeetingRequest>> watchStudentRequests(String studentId) {
    if (studentId.isEmpty) {
      return Stream.value(const []);
    }
    if (_db == null) {
      final items = _local.values
          .where((item) => item.studentId == studentId)
          .toList()
        ..sort(_byRequestedDesc);
      return Stream.value(items);
    }
    return _collection
        .where('studentId', isEqualTo: studentId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => MeetingRequest.fromMap(doc.id, doc.data()))
              .toList()
            ..sort(_byRequestedDesc);
          return items;
        });
  }

  Stream<List<MeetingRequest>> watchTeacherRequests(String teacherId) {
    if (teacherId.isEmpty) {
      return Stream<List<MeetingRequest>>.value(const []).asBroadcastStream();
    }
    if (_db == null) {
      final items = _local.values
          .where((item) => item.teacherId == teacherId)
          .toList()
        ..sort(_byRequestedDesc);
      return Stream<List<MeetingRequest>>.value(items).asBroadcastStream();
    }
    return _collection
        .where('teacherId', isEqualTo: teacherId)
        .snapshots()
        .map((snapshot) {
          final items = snapshot.docs
              .map((doc) => MeetingRequest.fromMap(doc.id, doc.data()))
              .toList()
            ..sort(_byRequestedDesc);
          return items;
        });
  }

  Stream<MeetingRequest?> watchRequest(String requestId) {
    if (requestId.isEmpty) {
      return Stream.value(null);
    }
    if (_db == null) {
      return Stream.value(_local[requestId]);
    }
    return _collection.doc(requestId).snapshots().map(
      (snapshot) => snapshot.exists
          ? MeetingRequest.fromMap(snapshot.id, snapshot.data()!)
          : null,
    );
  }

  Stream<int> watchPendingCountForTeacher(String teacherId) {
    return watchTeacherRequests(teacherId).map(
      (items) => items.where((item) => item.needsTeacherAction).length,
    );
  }

  Future<MeetingRequest> createRequest({
    required String studentId,
    required String studentName,
    required String teacherId,
    required String teacherName,
    required String courseId,
    required String courseName,
    required String topicTitle,
    required String reason,
    String studentEmail = '',
    String memberId = '',
    String chapterId = '',
    String chapterTitle = '',
    String topicId = '',
  }) async {
    final trimmedReason = reason.trim();
    final trimmedTopic = topicTitle.trim();
    if (studentId.isEmpty ||
        teacherId.isEmpty ||
        courseId.isEmpty ||
        trimmedTopic.isEmpty ||
        trimmedReason.isEmpty) {
      throw StateError('A complete meeting request is required.');
    }
    if (studentId == teacherId) {
      throw StateError('Students can only request meetings with a teacher.');
    }

    final draft = MeetingRequest(
      id: '',
      studentId: studentId,
      studentName: studentName,
      studentEmail: studentEmail,
      memberId: memberId,
      teacherId: teacherId,
      teacherName: teacherName,
      courseId: courseId,
      courseName: courseName,
      chapterId: chapterId,
      chapterTitle: chapterTitle,
      topicId: topicId,
      topicTitle: trimmedTopic,
      reason: trimmedReason,
    );

    if (_db == null) {
      final id = DateTime.now().microsecondsSinceEpoch.toString();
      final now = DateTime.now();
      final saved = MeetingRequest(
        id: id,
        studentId: draft.studentId,
        studentName: draft.studentName,
        studentEmail: draft.studentEmail,
        memberId: draft.memberId,
        teacherId: draft.teacherId,
        teacherName: draft.teacherName,
        courseId: draft.courseId,
        courseName: draft.courseName,
        chapterId: draft.chapterId,
        chapterTitle: draft.chapterTitle,
        topicId: draft.topicId,
        topicTitle: draft.topicTitle,
        reason: draft.reason,
        requestedAt: now,
      );
      _local[id] = saved;
      notifyListeners();
      return saved;
    }

    final doc = _collection.doc();
    await doc.set({
      ...draft.toCreateMap(),
      'requestedAt': FieldValue.serverTimestamp(),
      'scheduledAt': null,
      'respondedAt': null,
      'completedAt': null,
    });
    final snap = await doc.get();
    return MeetingRequest.fromMap(snap.id, snap.data() ?? draft.toCreateMap());
  }

  Future<void> acceptRequest({
    required String requestId,
    required String teacherId,
    required DateTime scheduledAt,
    String teacherNote = '',
  }) async {
    await _respond(
      requestId: requestId,
      teacherId: teacherId,
      status: MeetingRequestStatus.accepted,
      scheduledAt: scheduledAt,
      teacherNote: teacherNote,
      allowFromStatuses: const {
        MeetingRequestStatus.pending,
        MeetingRequestStatus.rescheduleRequested,
      },
    );
  }

  Future<void> declineRequest({
    required String requestId,
    required String teacherId,
    String teacherNote = '',
  }) async {
    await _respond(
      requestId: requestId,
      teacherId: teacherId,
      status: MeetingRequestStatus.declined,
      teacherNote: teacherNote,
      allowFromStatuses: const {MeetingRequestStatus.pending},
    );
  }

  Future<void> requestReschedule({
    required String requestId,
    required String studentId,
    String note = '',
  }) async {
    if (requestId.isEmpty || studentId.isEmpty) {
      throw StateError('A valid meeting request is required.');
    }
    final trimmedNote = note.trim();

    if (_db == null) {
      final existing = _local[requestId];
      if (existing == null || existing.studentId != studentId) {
        throw StateError('Meeting request not found.');
      }
      if (!existing.isAccepted) {
        throw StateError('Only accepted meetings can be rescheduled.');
      }
      _local[requestId] = existing.copyWith(
        status: MeetingRequestStatus.rescheduleRequested,
        rescheduleNote: trimmedNote,
      );
      notifyListeners();
      return;
    }

    final ref = _collection.doc(requestId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        throw StateError('Meeting request not found.');
      }
      final data = snap.data()!;
      if (data['studentId'] != studentId) {
        throw StateError('Only the student can request a reschedule.');
      }
      if (data['status'] != MeetingRequestStatus.accepted.storageValue) {
        throw StateError('Only accepted meetings can be rescheduled.');
      }
      final payload = <String, dynamic>{
        'status': MeetingRequestStatus.rescheduleRequested.storageValue,
        'rescheduleRequestedAt': FieldValue.serverTimestamp(),
      };
      if (trimmedNote.isNotEmpty) {
        payload['rescheduleNote'] = trimmedNote;
      }
      transaction.update(ref, payload);
    });
  }

  Future<void> completeRequest({
    required String requestId,
    required String teacherId,
  }) async {
    if (requestId.isEmpty || teacherId.isEmpty) {
      throw StateError('A valid meeting request is required.');
    }
    if (_db == null) {
      final existing = _local[requestId];
      if (existing == null || existing.teacherId != teacherId) {
        throw StateError('Meeting request not found.');
      }
      if (!existing.canMarkCompleted) {
        throw StateError(
          'Meeting can be completed only after the scheduled time.',
        );
      }
      _local[requestId] = existing.copyWith(
        status: MeetingRequestStatus.completed,
        completedAt: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    final ref = _collection.doc(requestId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        throw StateError('Meeting request not found.');
      }
      final data = snap.data()!;
      if (data['teacherId'] != teacherId) {
        throw StateError('Only the assigned teacher can update this request.');
      }
      if (data['status'] != MeetingRequestStatus.accepted.storageValue) {
        throw StateError('Only accepted meetings can be completed.');
      }
      final scheduledRaw = data['scheduledAt'];
      DateTime? scheduled;
      if (scheduledRaw is Timestamp) {
        scheduled = scheduledRaw.toDate();
      } else if (scheduledRaw is DateTime) {
        scheduled = scheduledRaw;
      }
      if (scheduled == null || DateTime.now().isBefore(scheduled)) {
        throw StateError(
          'Meeting can be completed only after the scheduled time.',
        );
      }
      transaction.update(ref, {
        'status': MeetingRequestStatus.completed.storageValue,
        'completedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> _respond({
    required String requestId,
    required String teacherId,
    required MeetingRequestStatus status,
    required Set<MeetingRequestStatus> allowFromStatuses,
    DateTime? scheduledAt,
    String teacherNote = '',
  }) async {
    if (requestId.isEmpty || teacherId.isEmpty) {
      throw StateError('A valid meeting request is required.');
    }
    if (status == MeetingRequestStatus.accepted && scheduledAt == null) {
      throw StateError('Choose a meeting date and time before accepting.');
    }

    if (_db == null) {
      final existing = _local[requestId];
      if (existing == null || existing.teacherId != teacherId) {
        throw StateError('Meeting request not found.');
      }
      if (!allowFromStatuses.contains(existing.status)) {
        throw StateError('This request cannot be updated right now.');
      }
      _local[requestId] = existing.copyWith(
        status: status,
        teacherNote: teacherNote.trim(),
        scheduledAt: scheduledAt,
        respondedAt: DateTime.now(),
      );
      notifyListeners();
      return;
    }

    final ref = _collection.doc(requestId);
    await _db.runTransaction((transaction) async {
      final snap = await transaction.get(ref);
      if (!snap.exists) {
        throw StateError('Meeting request not found.');
      }
      final data = snap.data()!;
      if (data['teacherId'] != teacherId) {
        throw StateError('Only the assigned teacher can update this request.');
      }
      final current = MeetingRequestStatusX.fromStorage(
        data['status'] as String?,
      );
      if (!allowFromStatuses.contains(current)) {
        throw StateError('This request cannot be updated right now.');
      }
      final payload = <String, dynamic>{
        'status': status.storageValue,
        'teacherNote': teacherNote.trim(),
        'respondedAt': FieldValue.serverTimestamp(),
      };
      if (status == MeetingRequestStatus.accepted) {
        payload['scheduledAt'] = Timestamp.fromDate(scheduledAt!);
      } else {
        payload['scheduledAt'] = null;
      }
      transaction.update(ref, payload);
    });
  }

  int _byRequestedDesc(MeetingRequest a, MeetingRequest b) {
    final left = a.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    final right = b.requestedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
    return right.compareTo(left);
  }
}
