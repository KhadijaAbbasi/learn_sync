import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learnsync/core/di/app_scope.dart';
import 'package:learnsync/core/localization/locale_controller.dart';
import 'package:learnsync/core/session/course_store.dart';
import 'package:learnsync/core/session/meeting_store.dart';
import 'package:learnsync/core/session/session_controller.dart';
import 'package:learnsync/core/theme/theme_controller.dart';
import 'package:learnsync/l10n/app_localizations.dart';
import 'package:learnsync/models/ai_practice.dart';
import 'package:learnsync/models/course_model.dart';
import 'package:learnsync/models/lecture_feedback.dart';
import 'package:learnsync/models/lecture_model.dart';
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/models/meeting_request.dart';
import 'package:learnsync/models/teacher_analytics.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/teacher/teacher_analytics_screen.dart';
import 'package:learnsync/screens/teacher/teacher_dashboard.dart';
import 'package:learnsync/services/ai_practice_generator.dart';
import 'package:learnsync/services/course_enrollment_service.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/stub_ai_practice_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test(
    'aggregates understanding, practice, and meetings with filters',
    () async {
      final now = DateTime(2026, 9, 5, 12);
      final lectures = [
        LectureModel(
          id: 'lec-a',
          courseId: 'CS-500',
          courseName: 'AI',
          teacherId: 'teacher-1',
          teacherName: 'Soma',
          chapterId: 'ch-1',
          chapterTitle: 'Neural Nets',
          topicId: 't-1',
          topicTitle: 'Backprop',
          durationMinutes: 40,
          studentCount: 2,
          endedAt: DateTime(2026, 9, 4, 11),
        ),
        LectureModel(
          id: 'lec-b',
          courseId: 'CS-401',
          courseName: 'Algorithms',
          teacherId: 'teacher-1',
          teacherName: 'Soma',
          chapterId: 'ch-2',
          chapterTitle: 'Graphs',
          topicId: 't-2',
          topicTitle: 'BFS',
          durationMinutes: 40,
          studentCount: 1,
          endedAt: DateTime(2026, 8, 1, 11),
        ),
      ];
      final feedback = [
        LectureFeedback(
          id: 'lec-a_s1',
          lectureId: 'lec-a',
          sessionId: 'lec-a',
          courseId: 'CS-500',
          courseName: 'AI',
          teacherId: 'teacher-1',
          teacherName: 'Soma',
          studentId: 's1',
          studentName: 'Ayesha',
          level: UnderstandingLevel.below50,
          topicId: 't-1',
          topicTitle: 'Backprop',
          chapterId: 'ch-1',
          chapterTitle: 'Neural Nets',
        ),
        LectureFeedback(
          id: 'lec-a_s2',
          lectureId: 'lec-a',
          sessionId: 'lec-a',
          courseId: 'CS-500',
          courseName: 'AI',
          teacherId: 'teacher-1',
          teacherName: 'Soma',
          studentId: 's2',
          studentName: 'Bilal',
          level: UnderstandingLevel.percent100,
          topicId: 't-1',
          topicTitle: 'Backprop',
          chapterId: 'ch-1',
          chapterTitle: 'Neural Nets',
        ),
      ];
      final quiz = await StubAiPracticeGenerator().generateQuiz(
        const AiQuizRequest(
          taughtNotes: 'Covered backpropagation',
          topicTitle: 'Backprop',
        ),
      );
      final attempts = [
        AiPracticeAttempt(
          id: 'a1',
          lectureId: 'lec-a',
          courseId: 'CS-500',
          courseName: 'AI',
          teacherId: 'teacher-1',
          studentId: 's2',
          studentName: 'Bilal',
          topicTitle: 'Backprop',
          score: 4,
          total: quiz.length,
          selectedIndexes: const [0, 0, 0, 0, 0],
        ),
      ];
      final meetings = [
        MeetingRequest(
          id: 'm1',
          studentId: 's1',
          studentName: 'Ayesha',
          teacherId: 'teacher-1',
          teacherName: 'Soma',
          courseId: 'CS-500',
          courseName: 'AI',
          topicTitle: 'Backprop',
          reason: 'Need help',
          chapterId: 'ch-1',
          topicId: 't-1',
          requestedAt: DateTime(2026, 9, 4, 15),
        ),
      ];

      final all = aggregateTeacherAnalytics(
        TeacherAnalyticsInputs(
          lectures: lectures,
          feedback: feedback,
          attempts: attempts,
          meetings: meetings,
          attendeesByLecture: {
            'lec-a': const [
              LectureAttendee(studentId: 's1', studentName: 'Ayesha'),
              LectureAttendee(studentId: 's2', studentName: 'Bilal'),
            ],
          },
          courses: const [
            (id: 'CS-500', name: 'AI'),
            (id: 'CS-401', name: 'Algorithms'),
          ],
        ),
        const TeacherAnalyticsFilter(),
        now: now,
      );

      expect(all.understanding.total, 2);
      expect(all.understandingAverage, 70);
      expect(all.practice.participants, 1);
      expect(all.practice.attendeeCount, 3);
      expect(all.practice.completionPercent, 33);
      expect(all.practice.averageScore, 80);
      expect(all.meetings.pending, 1);
      expect(all.byTopic.single.label, 'Backprop');
      expect(all.lowUnderstanding.single.studentName, 'Ayesha');
      expect(all.incompletePractice.single.studentName, 'Ayesha');
      expect(all.pendingMeetings.single.studentName, 'Ayesha');

      final filtered = aggregateTeacherAnalytics(
        TeacherAnalyticsInputs(
          lectures: lectures,
          feedback: feedback,
          attempts: attempts,
          meetings: meetings,
          courses: const [
            (id: 'CS-500', name: 'AI'),
            (id: 'CS-401', name: 'Algorithms'),
          ],
        ),
        const TeacherAnalyticsFilter(courseId: 'CS-401'),
        now: now,
      );
      expect(filtered.lectureCount, 1);
      expect(filtered.understanding.total, 0);
      expect(filtered.meetings.total, 0);

      final courseA = aggregateTeacherAnalytics(
        TeacherAnalyticsInputs(
          lectures: lectures,
          feedback: feedback,
          attempts: attempts,
          meetings: meetings,
          attendeesByLecture: {
            'lec-a': const [
              LectureAttendee(studentId: 's1', studentName: 'Ayesha'),
              LectureAttendee(studentId: 's2', studentName: 'Bilal'),
            ],
          },
        ),
        const TeacherAnalyticsFilter(courseId: 'CS-500'),
        now: now,
      );
      expect(courseA.practice.completionPercent, 50);

      final recent = aggregateTeacherAnalytics(
        TeacherAnalyticsInputs(
          lectures: lectures,
          feedback: feedback,
          attempts: attempts,
          meetings: meetings,
        ),
        const TeacherAnalyticsFilter(
          dateRange: TeacherAnalyticsDateRange.last7,
        ),
        now: now,
      );
      expect(recent.lectureCount, 1);
      expect(recent.understanding.total, 2);
    },
  );


  test('topic filter combines multiple lectures for same topic', () {
    final now = DateTime(2026, 9, 5, 12);
    final lectures = [
      LectureModel(
        id: 'lec-1',
        courseId: 'PF',
        courseName: 'Programming Fundamentals',
        teacherId: 'teacher-1',
        teacherName: 'Soma',
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        topicId: 'oop',
        topicTitle: 'OOP',
        durationMinutes: 40,
        studentCount: 2,
        endedAt: DateTime(2026, 9, 1, 11),
      ),
      LectureModel(
        id: 'lec-2',
        courseId: 'PF',
        courseName: 'Programming Fundamentals',
        teacherId: 'teacher-1',
        teacherName: 'Soma',
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
        topicId: 'oop',
        topicTitle: 'OOP',
        durationMinutes: 45,
        studentCount: 2,
        endedAt: DateTime(2026, 9, 3, 11),
      ),
    ];
    final feedback = [
      LectureFeedback(
        id: 'lec-1_s1',
        lectureId: 'lec-1',
        sessionId: 'lec-1',
        courseId: 'PF',
        courseName: 'Programming Fundamentals',
        teacherId: 'teacher-1',
        teacherName: 'Soma',
        studentId: 's1',
        studentName: 'Ayesha',
        level: UnderstandingLevel.percent60,
        topicId: 'oop',
        topicTitle: 'OOP',
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
      ),
      LectureFeedback(
        id: 'lec-2_s1',
        lectureId: 'lec-2',
        sessionId: 'lec-2',
        courseId: 'PF',
        courseName: 'Programming Fundamentals',
        teacherId: 'teacher-1',
        teacherName: 'Soma',
        studentId: 's1',
        studentName: 'Ayesha',
        level: UnderstandingLevel.percent80,
        topicId: 'oop',
        topicTitle: 'OOP',
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
      ),
      LectureFeedback(
        id: 'lec-2_s2',
        lectureId: 'lec-2',
        sessionId: 'lec-2',
        courseId: 'PF',
        courseName: 'Programming Fundamentals',
        teacherId: 'teacher-1',
        teacherName: 'Soma',
        studentId: 's2',
        studentName: 'Bilal',
        level: UnderstandingLevel.percent100,
        topicId: 'oop',
        topicTitle: 'OOP',
        chapterId: 'ch-1',
        chapterTitle: 'Chapter 1',
      ),
    ];

    final report = aggregateTeacherAnalytics(
      TeacherAnalyticsInputs(
        lectures: lectures,
        feedback: feedback,
        attempts: const [],
        meetings: const [],
        attendeesByLecture: {
          'lec-1': const [
            LectureAttendee(studentId: 's1', studentName: 'Ayesha'),
            LectureAttendee(studentId: 's2', studentName: 'Bilal'),
          ],
          'lec-2': const [
            LectureAttendee(studentId: 's1', studentName: 'Ayesha'),
            LectureAttendee(studentId: 's2', studentName: 'Bilal'),
          ],
        },
      ),
      const TeacherAnalyticsFilter(
        courseId: 'PF',
        chapterId: 'ch-1',
        topicId: 'oop',
      ),
      now: now,
    );

    expect(report.lectureCount, 2);
    expect(report.uniqueStudentCount, 2);
    expect(report.practice.attendeeCount, 2);
    expect(report.understanding.total, 3);
    expect(report.studentRows.length, 2);
    final ayesha = report.studentRows.firstWhere((r) => r.studentId == 's1');
    expect(ayesha.understandingPercent, 70);
  });

  testWidgets('sidebar opens teacher analytics', (tester) async {
    final store = CourseStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'AI',
        code: 'CS-500',
        teacherId: 'teacher-1',
      ),
    );
    final session = SessionController()
      ..signIn(
        const UserModel(
          id: 'teacher-1',
          fullName: 'Soma Karim',
          email: 'soma@example.com',
          role: UserRole.teacher,
        ),
      );

    tester.view.physicalSize = const Size(1100, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(store: store, session: session, home: const TeacherDashboard()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meeting requests'), findsNothing);
    expect(find.text('Teacher Analytics'), findsOneWidget);
    await tester.tap(find.text('Teacher Analytics'));
    await tester.pumpAndSettle();
    expect(find.text('Teacher Analytics'), findsWidgets);
  });

  testWidgets('analytics screen shows overview and student names', (
    tester,
  ) async {
    final store = CourseStore();
    final meetings = MeetingStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'AI',
        code: 'CS-500',
        teacherId: 'teacher-1',
      ),
    );
    final started = await store.startLiveSession(
      LiveSessionModel(
        id: 'session-analytics',
        courseId: 'CS-500',
        chapterId: 'ch-1',
        chapterTitle: 'Neural Nets',
        topicId: 't-1',
        topicTitle: 'Backprop',
        teacherId: 'teacher-1',
        durationMinutes: 40,
        startedAt: DateTime(2026, 9, 4, 10),
      ),
      courseName: 'AI',
      teacherName: 'Soma Karim',
    );
    await store.markLectureAttendance(
      lectureId: started.id,
      studentId: 's1',
      studentName: 'Ayesha',
    );
    await store.markLectureAttendance(
      lectureId: started.id,
      studentId: 's2',
      studentName: 'Bilal',
    );
    await store.endLiveSession('CS-500', started.id, 'teacher-1');
    final ended = started.copyWith(status: LiveSessionStatus.ended);
    await store.submitLectureFeedback(
      session: ended,
      courseName: 'AI',
      teacherName: 'Soma Karim',
      studentId: 's1',
      studentName: 'Ayesha',
      level: UnderstandingLevel.below50,
    );
    await store.submitLectureFeedback(
      session: ended,
      courseName: 'AI',
      teacherName: 'Soma Karim',
      studentId: 's2',
      studentName: 'Bilal',
      level: UnderstandingLevel.percent100,
    );
    final quiz = await StubAiPracticeGenerator().generateQuiz(
      const AiQuizRequest(
        taughtNotes: 'Covered backpropagation',
        topicTitle: 'Backprop',
      ),
    );
    await store.savePracticeAttempt(
      attempt: AiPracticeAttempt(
        id: '',
        lectureId: started.id,
        courseId: 'CS-500',
        courseName: 'AI',
        teacherId: 'teacher-1',
        studentId: 's2',
        studentName: 'Bilal',
        topicTitle: 'Backprop',
        score: 5,
        total: quiz.length,
        selectedIndexes: const [0, 0, 0, 0, 0],
        questions: quiz.questions,
      ),
    );
    await meetings.createRequest(
      studentId: 's1',
      studentName: 'Ayesha',
      teacherId: 'teacher-1',
      teacherName: 'Soma Karim',
      courseId: 'CS-500',
      courseName: 'AI',
      topicTitle: 'Backprop',
      reason: 'Need a review session',
      chapterId: 'ch-1',
      topicId: 't-1',
    );

    final session = SessionController()
      ..signIn(
        const UserModel(
          id: 'teacher-1',
          fullName: 'Soma Karim',
          email: 'soma@example.com',
          role: UserRole.teacher,
        ),
      );

    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(
        store: store,
        session: session,
        meetings: meetings,
        home: TeacherAnalyticsScreen(
          initialFilter: TeacherAnalyticsFilter(
            courseId: store.courses.first.id,
            chapterId: 'ch-1',
            topicId: 't-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Understanding'), findsWidgets);
    expect(find.text('AI practice'), findsWidgets);
    expect(find.text('Ayesha'), findsWidgets);
    expect(find.text('Backprop'), findsWidgets);
    expect(find.text('70%'), findsWidgets);
  });

  test(
    'practice fallback loads attempts from lecture subcollections',
    () async {
      final store = CourseStore();
      await store.addCourse(
        const CourseModel(
          id: '',
          name: 'AI',
          code: 'CS-500',
          teacherId: 'teacher-1',
        ),
      );
      final started = await store.startLiveSession(
        LiveSessionModel(
          id: 'session-fallback',
          courseId: 'CS-500',
          chapterId: 'ch-1',
          chapterTitle: 'Neural Nets',
          topicId: 't-1',
          topicTitle: 'Backprop',
          teacherId: 'teacher-1',
          durationMinutes: 40,
        ),
        courseName: 'AI',
        teacherName: 'Soma Karim',
      );
      await store.endLiveSession('CS-500', started.id, 'teacher-1');
      await store.savePracticeAttempt(
        attempt: AiPracticeAttempt(
          id: 'attempt-1',
          lectureId: started.id,
          courseId: 'CS-500',
          courseName: 'AI',
          teacherId: 'teacher-1',
          studentId: 's2',
          studentName: 'Bilal',
          topicTitle: 'Backprop',
          score: 4,
          total: 5,
          selectedIndexes: const [0, 0, 0, 0, 0],
        ),
      );

      final fromLectures = await store.watchPracticeAttemptsForLectures([
        started.id,
      ], teacherId: 'teacher-1').first;
      expect(fromLectures.single.studentName, 'Bilal');

      final viaTeacher = await store
          .watchTeacherPracticeAttempts('teacher-1', lectureIds: [started.id])
          .first;
      expect(viaTeacher.single.lectureId, started.id);
    },
  );

  testWidgets('analytics still renders when practice stream errors', (
    tester,
  ) async {
    final store = CourseStore();
    final meetings = MeetingStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'AI',
        code: 'CS-500',
        teacherId: 'teacher-1',
      ),
    );
    final started = await store.startLiveSession(
      LiveSessionModel(
        id: 'session-practice-error',
        courseId: 'CS-500',
        chapterId: 'ch-1',
        chapterTitle: 'Neural Nets',
        topicId: 't-1',
        topicTitle: 'Backprop',
        teacherId: 'teacher-1',
        durationMinutes: 40,
        startedAt: DateTime(2026, 9, 4, 10),
      ),
      courseName: 'AI',
      teacherName: 'Soma Karim',
    );
    await store.endLiveSession('CS-500', started.id, 'teacher-1');
    await store.submitLectureFeedback(
      session: started.copyWith(status: LiveSessionStatus.ended),
      courseName: 'AI',
      teacherName: 'Soma Karim',
      studentId: 's1',
      studentName: 'Ayesha',
      level: UnderstandingLevel.below50,
    );
    await meetings.createRequest(
      studentId: 's1',
      studentName: 'Ayesha',
      teacherId: 'teacher-1',
      teacherName: 'Soma Karim',
      courseId: 'CS-500',
      courseName: 'AI',
      topicTitle: 'Backprop',
      reason: 'Need a review session',
      chapterId: 'ch-1',
      topicId: 't-1',
    );

    tester.view.physicalSize = const Size(900, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(
        store: store,
        session: SessionController()
          ..signIn(
            const UserModel(
              id: 'teacher-1',
              fullName: 'Soma Karim',
              email: 'soma@example.com',
              role: UserRole.teacher,
            ),
          ),
        meetings: meetings,
        home: TeacherAnalyticsScreen(
          initialFilter: TeacherAnalyticsFilter(
            courseId: store.courses.first.id,
            chapterId: 'ch-1',
            topicId: 't-1',
          ),
          practiceAttemptsStream: Stream<List<AiPracticeAttempt>>.error(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'failed-precondition',
              message: 'The query requires an index',
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load analytics. Try again.'), findsNothing);
    expect(find.text('Understanding'), findsWidgets);
    expect(find.text('Ayesha'), findsWidgets);
    expect(
      find.text(
        'AI practice stats are unavailable right now. Understanding and meetings are still shown.',
      ),
      findsOneWidget,
    );
  });
}

Widget _scope({
  required CourseStore store,
  required SessionController session,
  required Widget home,
  MeetingStore? meetings,
}) {
  return AppScope(
    authService: MockAuthService(),
    localeController: LocaleController(),
    themeController: ThemeController(),
    sessionController: session,
    courseStore: store,
    meetingStore: meetings ?? MeetingStore(),
    enrollment: CourseEnrollmentService(),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}
