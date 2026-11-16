import 'package:flutter_test/flutter_test.dart';
import 'package:learnsync/core/session/course_store.dart';
import 'package:learnsync/models/chapter_model.dart';
import 'package:learnsync/models/course_model.dart';
import 'package:learnsync/models/lecture_feedback.dart';
import 'package:learnsync/models/lecture_model.dart';
import 'package:learnsync/models/live_session_model.dart';

void main() {
  group('Chapter and topic models', () {
    test('parse and serialize content fields', () {
      final chapter = ChapterModel.fromMap('chapter-1', {
        'title': 'Foundations',
        'description': 'Core ideas',
        'position': 2,
      });
      final topic = TopicModel.fromMap('topic-1', {
        'title': 'Introduction',
        'description': 'First lesson',
        'position': 1,
      });

      expect(chapter.id, 'chapter-1');
      expect(chapter.position, 2);
      expect(chapter.toMap()['title'], 'Foundations');
      expect(topic.id, 'topic-1');
      expect(topic.position, 1);
      expect(topic.toMap()['description'], 'First lesson');
    });

    test('parses lecture summary snapshots', () {
      final lecture = LectureModel.fromMap('lecture-1', {
        'courseId': 'COURSE-1',
        'courseName': 'Course One',
        'teacherId': 'teacher-1',
        'teacherName': 'Demo Teacher',
        'chapterId': 'chapter-1',
        'chapterTitle': 'Chapter One',
        'topicId': 'topic-1',
        'topicTitle': 'Topic One',
        'durationMinutes': 30,
        'status': 'ended',
        'actualDurationMinutes': 28,
        'studentCount': 4,
        'lectureDate': '2026-09-04',
        'summary': {
          'lectureId': 'lecture-1',
          'sessionId': 'lecture-1',
          'courseId': 'COURSE-1',
          'courseName': 'Course One',
          'courseCode': 'COURSE-1',
          'department': 'CS',
          'semester': 'Fall 2026',
          'section': 'A',
          'teacherId': 'teacher-1',
          'teacherName': 'Demo Teacher',
          'chapterId': 'chapter-1',
          'chapterTitle': 'Chapter One',
          'topicId': 'topic-1',
          'topicTitle': 'Topic One',
          'durationMinutes': 30,
          'actualDurationMinutes': 28,
          'attendeeCount': 4,
          'lectureDate': '2026-09-04',
          'taughtNotes': 'Covered binary trees',
        },
      });

      expect(lecture.summary?.courseCode, 'COURSE-1');
      expect(lecture.summary?.attendeeCount, 4);
      expect(lecture.summary?.toMap()['topicTitle'], 'Topic One');
      expect(lecture.summary?.taughtNotes, 'Covered binary trees');
      expect(lecture.summary?.toMap()['taughtNotes'], 'Covered binary trees');
    });
  });

  group('Local chapter and topic store', () {
    test('creates, reorders, and deletes chapters and topics', () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course One',
          code: 'COURSE-1',
          teacherId: 'teacher-1',
        ),
      );

      await store.addChapter(
        'COURSE-1',
        const ChapterModel(id: 'chapter-1', title: 'Chapter One'),
      );
      await store.addChapter(
        'COURSE-1',
        const ChapterModel(id: 'chapter-2', title: 'Chapter Two'),
      );

      var chapters = await store.watchChapters('COURSE-1').first;
      expect(chapters.map((item) => item.id), ['chapter-1', 'chapter-2']);

      await store.reorderChapters('COURSE-1', chapters.reversed.toList());
      chapters = await store.watchChapters('COURSE-1').first;
      expect(chapters.map((item) => item.id), ['chapter-2', 'chapter-1']);

      await store.addTopic(
        'COURSE-1',
        'chapter-1',
        const TopicModel(id: 'topic-1', title: 'Topic One'),
      );
      await store.addTopic(
        'COURSE-1',
        'chapter-1',
        const TopicModel(id: 'topic-2', title: 'Topic Two'),
      );

      var topics = await store.watchTopics('COURSE-1', 'chapter-1').first;
      expect(topics.map((item) => item.id), ['topic-1', 'topic-2']);
      expect(store.courses.single.topicCount, 2);

      await store.deleteTopic('COURSE-1', 'chapter-1', 'topic-1');
      topics = await store.watchTopics('COURSE-1', 'chapter-1').first;
      expect(topics.single.id, 'topic-2');
      expect(store.courses.single.topicCount, 1);

      await store.deleteChapter('COURSE-1', 'chapter-1');
      chapters = await store.watchChapters('COURSE-1').first;
      expect(chapters.single.id, 'chapter-2');
      expect(await store.watchTopics('COURSE-1', 'chapter-1').first, isEmpty);
      expect(store.courses.single.topicCount, 0);
    });
  });

  group('Live sessions', () {
    test('parses synchronized timing fields', () {
      final startedAt = DateTime(2026, 8, 29, 12);
      final session = LiveSessionModel.fromMap('session-1', 'course-1', {
        'chapterId': 'chapter-1',
        'chapterTitle': 'Chapter One',
        'topicId': 'topic-1',
        'topicTitle': 'Topic One',
        'teacherId': 'teacher-1',
        'durationMinutes': 45,
        'status': 'active',
        'startedAt': startedAt,
      });

      expect(session.isActive, isTrue);
      expect(session.scheduledEnd, startedAt.add(const Duration(minutes: 45)));
      expect(
        session.remainingAt(startedAt.add(const Duration(minutes: 5))),
        const Duration(minutes: 40),
      );
    });

    test('allows only one active session per course', () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course One',
          code: 'COURSE-1',
          teacherId: 'teacher-1',
        ),
      );
      const session = LiveSessionModel(
        id: 'session-1',
        courseId: 'COURSE-1',
        chapterId: 'chapter-1',
        chapterTitle: 'Chapter One',
        topicId: 'topic-1',
        topicTitle: 'Topic One',
        teacherId: 'teacher-1',
        durationMinutes: 45,
      );

      final started = await store.startLiveSession(
        session,
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
      );
      expect(
        (await store.watchActiveSession('COURSE-1').first)?.id,
        'session-1',
      );
      expect(store.courses.single.isLive, isTrue);
      await expectLater(
        store.startLiveSession(
          session.copyWith(id: 'session-2'),
          courseName: 'Course One',
          teacherName: 'Demo Teacher',
        ),
        throwsA(isA<TeacherAlreadyLiveException>()),
      );

      await store.endLiveSession('COURSE-1', started.id, 'teacher-1');
      expect(await store.watchActiveSession('COURSE-1').first, isNull);
      expect(store.courses.single.isLive, isFalse);
    });

    test('records lecture history and attendance', () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course One',
          code: 'COURSE-1',
          teacherId: 'teacher-1',
        ),
      );
      final started = await store.startLiveSession(
        const LiveSessionModel(
          id: 'session-attendance',
          courseId: 'COURSE-1',
          chapterId: 'chapter-1',
          chapterTitle: 'Chapter One',
          topicId: 'topic-1',
          topicTitle: 'Topic One',
          teacherId: 'teacher-1',
          durationMinutes: 30,
        ),
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
      );

      final lecture = await store.watchLecture(started.id).first;
      expect(lecture, isNotNull);
      expect(lecture!.courseName, 'Course One');
      expect(lecture.teacherName, 'Demo Teacher');
      expect(lecture.isActive, isTrue);

      await store.markLectureAttendance(
        lectureId: started.id,
        studentId: 'student-1',
        studentName: 'Ayesha',
        studentEmail: 'ayesha@example.com',
        memberId: 'S-2001',
      );
      await store.markLectureAttendance(
        lectureId: started.id,
        studentId: 'student-1',
        studentName: 'Ayesha',
      );

      final attendees = await store.watchLectureAttendees(started.id).first;
      expect(attendees.length, 1);
      expect(attendees.single.studentName, 'Ayesha');
      expect((await store.watchLecture(started.id).first)?.studentCount, 1);

      final summary = await store.endLiveSession(
        'COURSE-1',
        started.id,
        'teacher-1',
      );
      final ended = await store.watchLecture(started.id).first;
      expect(ended?.isActive, isFalse);
      expect(ended?.studentCount, 1);
      expect(summary?.topicTitle, 'Topic One');
      expect(ended?.summary, isNotNull);
      expect(ended?.summary?.topicTitle, 'Topic One');
      expect(ended?.summary?.chapterTitle, 'Chapter One');
      expect(ended?.summary?.courseName, 'Course One');
      expect(ended?.summary?.attendeeCount, 1);
      expect(ended?.summary?.courseCode, 'COURSE-1');
    });

    test('saves an enriched lecture summary after the session ends', () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course One',
          code: 'COURSE-1',
          teacherId: 'teacher-1',
          department: 'Computer Science',
          semester: 'Fall 2026',
        ),
      );
      final started = await store.startLiveSession(
        const LiveSessionModel(
          id: 'session-summary',
          courseId: 'COURSE-1',
          chapterId: 'chapter-1',
          chapterTitle: 'Chapter One',
          topicId: 'topic-1',
          topicTitle: 'Topic One',
          teacherId: 'teacher-1',
          durationMinutes: 30,
        ),
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
      );

      await store.endLiveSession('COURSE-1', started.id, 'teacher-1');
      final ended = await store.watchLecture(started.id).first;
      expect(ended?.summary?.department, 'Computer Science');

      await store.saveLectureSummary(
        lectureId: started.id,
        teacherId: 'teacher-1',
        summary: ended!.summary!.copyWith(
          courseCode: 'COURSE-1',
          section: 'A',
          taughtNotes: 'Introduced binary search trees',
        ),
      );
      final saved = await store.watchLecture(started.id).first;
      expect(saved?.summary?.courseCode, 'COURSE-1');
      expect(saved?.summary?.section, 'A');
      expect(saved?.summary?.topicTitle, 'Topic One');
      expect(saved?.summary?.taughtNotes, 'Introduced binary search trees');
      expect(saved?.taughtNotes, 'Introduced binary search trees');
      expect(saved?.resolvedTaughtNotes, 'Introduced binary search trees');
      expect(
        await store.loadTaughtNotes(started.id),
        'Introduced binary search trees',
      );
    });

    test('allows only one active live lecture per teacher', () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course One',
          code: 'COURSE-1',
          teacherId: 'teacher-1',
        ),
      );
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course Two',
          code: 'COURSE-2',
          teacherId: 'teacher-1',
        ),
      );
      await store.startLiveSession(
        const LiveSessionModel(
          id: 'session-1',
          courseId: 'COURSE-1',
          chapterId: 'chapter-1',
          chapterTitle: 'Chapter One',
          topicId: 'topic-1',
          topicTitle: 'Topic One',
          teacherId: 'teacher-1',
          durationMinutes: 45,
        ),
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
      );
      await expectLater(
        store.startLiveSession(
          const LiveSessionModel(
            id: 'session-2',
            courseId: 'COURSE-2',
            chapterId: 'chapter-2',
            chapterTitle: 'Chapter Two',
            topicId: 'topic-2',
            topicTitle: 'Topic Two',
            teacherId: 'teacher-1',
            durationMinutes: 30,
          ),
          courseName: 'Course Two',
          teacherName: 'Demo Teacher',
        ),
        throwsA(isA<TeacherAlreadyLiveException>()),
      );
    });

    test('requires teacher acceptance before joining', () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course One',
          code: 'COURSE-1',
          teacherId: 'teacher-1',
        ),
      );
      final started = await store.startLiveSession(
        const LiveSessionModel(
          id: 'session-join',
          courseId: 'COURSE-1',
          chapterId: 'chapter-1',
          chapterTitle: 'Chapter One',
          topicId: 'topic-1',
          topicTitle: 'Topic One',
          teacherId: 'teacher-1',
          durationMinutes: 30,
        ),
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
      );

      await store.requestJoinLecture(
        courseId: 'COURSE-1',
        sessionId: started.id,
        studentId: 'student-1',
        studentName: 'Ayesha',
        studentEmail: 'ayesha@example.com',
        memberId: 'S-2001',
      );
      await store.requestJoinLecture(
        courseId: 'COURSE-1',
        sessionId: started.id,
        studentId: 'student-2',
        studentName: 'Omar',
        studentEmail: 'omar@example.com',
        memberId: 'S-2002',
      );

      final pending = await store
          .watchJoinRequests('COURSE-1', started.id)
          .first;
      expect(pending.where((item) => item.isPending).length, 2);
      expect((await store.watchLectureAttendees(started.id).first).length, 0);

      await store.acceptJoinRequest(
        courseId: 'COURSE-1',
        sessionId: started.id,
        teacherId: 'teacher-1',
        studentId: 'student-1',
      );
      expect(
        (await store
                .watchMyJoinRequest('COURSE-1', started.id, 'student-1')
                .first)
            ?.isAccepted,
        isTrue,
      );
      expect(
        (await store.watchLectureAttendees(started.id).first)
            .single
            .studentName,
        'Ayesha',
      );

      await store.acceptAllJoinRequests(
        courseId: 'COURSE-1',
        sessionId: started.id,
        teacherId: 'teacher-1',
      );
      final attendees = await store.watchLectureAttendees(started.id).first;
      expect(attendees.length, 2);
      expect(
        (await store.watchJoinRequests('COURSE-1', started.id).first).every(
          (item) => item.isAccepted,
        ),
        isTrue,
      );
    });

    test('collects understanding feedback after lecture ends', () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'Course One',
          code: 'COURSE-1',
          teacherId: 'teacher-1',
          teacherName: 'Demo Teacher',
        ),
      );
      final started = await store.startLiveSession(
        const LiveSessionModel(
          id: 'session-feedback',
          courseId: 'COURSE-1',
          chapterId: 'chapter-1',
          chapterTitle: 'Chapter One',
          topicId: 'topic-1',
          topicTitle: 'Topic One',
          teacherId: 'teacher-1',
          durationMinutes: 30,
        ),
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
      );
      await store.requestJoinLecture(
        courseId: 'COURSE-1',
        sessionId: started.id,
        studentId: 'student-1',
        studentName: 'Ayesha',
      );
      await store.acceptJoinRequest(
        courseId: 'COURSE-1',
        sessionId: started.id,
        teacherId: 'teacher-1',
        studentId: 'student-1',
      );

      await expectLater(
        store.submitLectureFeedback(
          session: started,
          courseName: 'Course One',
          teacherName: 'Demo Teacher',
          studentId: 'student-1',
          studentName: 'Ayesha',
          level: UnderstandingLevel.percent80,
        ),
        throwsStateError,
      );

      await store.endLiveSession('COURSE-1', started.id, 'teacher-1');
      final endedSession = started.copyWith(status: LiveSessionStatus.ended);

      final saved = await store.submitLectureFeedback(
        session: endedSession,
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
        studentId: 'student-1',
        studentName: 'Ayesha',
        level: UnderstandingLevel.percent80,
      );
      expect(saved.level, UnderstandingLevel.percent80);
      expect(saved.teacherId, 'teacher-1');
      expect(saved.lectureId, started.id);

      await store.submitLectureFeedback(
        session: endedSession,
        courseName: 'Course One',
        teacherName: 'Demo Teacher',
        studentId: 'student-1',
        studentName: 'Ayesha',
        level: UnderstandingLevel.percent100,
      );

      final mine = await store
          .watchMyLectureFeedback(started.id, 'student-1')
          .first;
      expect(mine?.level, UnderstandingLevel.percent100);

      final all = await store.watchLectureFeedback(started.id).first;
      expect(LectureFeedbackCounts.fromList(all).percent100, 1);
      expect(LectureFeedbackCounts.fromList(all).total, 1);
    });
  });
}
