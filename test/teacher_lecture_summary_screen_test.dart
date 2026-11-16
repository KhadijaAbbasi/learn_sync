import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learnsync/core/constants/app_routes.dart';
import 'package:learnsync/core/di/app_scope.dart';
import 'package:learnsync/core/localization/locale_controller.dart';
import 'package:learnsync/core/session/course_store.dart';
import 'package:learnsync/core/session/meeting_store.dart';
import 'package:learnsync/core/session/session_controller.dart';
import 'package:learnsync/core/theme/theme_controller.dart';
import 'package:learnsync/l10n/app_localizations.dart';
import 'package:learnsync/models/course_model.dart';
import 'package:learnsync/models/lecture_model.dart';
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/screens/teacher/teacher_lecture_feedback_screen.dart';
import 'package:learnsync/screens/teacher/teacher_lecture_summary_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('teacher summary shows lecture details and opens feedback', (
    tester,
  ) async {
    final store = CourseStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'Algorithms',
        code: 'CS-401',
        teacherId: 'teacher-1',
        department: 'Computer Science',
        semester: 'Fall 2026',
      ),
    );
    final started = await store.startLiveSession(
      LiveSessionModel(
        id: 'session-ui',
        courseId: 'CS-401',
        chapterId: 'chapter-1',
        chapterTitle: 'Graphs',
        topicId: 'topic-1',
        topicTitle: 'Shortest Paths',
        teacherId: 'teacher-1',
        durationMinutes: 45,
        startedAt: DateTime(2026, 9, 4, 10),
      ),
      courseName: 'Algorithms',
      teacherName: 'Demo Teacher',
    );
    await store.markLectureAttendance(
      lectureId: started.id,
      studentId: 'student-1',
      studentName: 'Ayesha',
      studentEmail: 'ayesha@example.com',
    );
    await store.endLiveSession('CS-401', started.id, 'teacher-1');
    final ended = started.copyWith(
      status: LiveSessionStatus.ended,
      endedAt: DateTime(2026, 9, 4, 10, 42),
    );

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        authService: MockAuthService(),
        localeController: LocaleController(),
        themeController: ThemeController(),
        sessionController: SessionController(),
        courseStore: store,
        meetingStore: MeetingStore(),
        enrollment: CourseEnrollmentService(),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routes: {
            AppRoutes.teacherDashboard: (_) =>
                const Scaffold(body: Text('Teacher Home')),
          },
          home: TeacherLectureSummaryScreen(
            session: ended,
            courseName: 'Algorithms',
            courseCode: 'CS-401',
            department: 'Computer Science',
            semester: 'Fall 2026',
            teacherId: 'teacher-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lecture Summary'), findsOneWidget);
    expect(find.text('Shortest Paths'), findsWidgets);
    expect(find.text('Graphs'), findsOneWidget);
    expect(find.text('Algorithms'), findsWidgets);
    expect(find.text('CS-401'), findsWidgets);
    expect(find.text('Computer Science'), findsWidgets);
    expect(find.text('Attendees (1)'), findsOneWidget);
    expect(find.text('Ayesha'), findsOneWidget);
    expect(find.text('View student feedback'), findsOneWidget);
    expect(find.text('What did you teach today?'), findsOneWidget);

    final notesField = find.byType(TextFormField);
    await tester.ensureVisible(notesField);
    await tester.enterText(notesField, 'Covered Dijkstra and Bellman-Ford');
    await tester.tap(find.text('View student feedback'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherLectureFeedbackScreen), findsOneWidget);
    expect(find.text('Back to Dashboard'), findsOneWidget);
    expect(
      (await store.watchLecture(started.id).first)?.summary?.taughtNotes,
      'Covered Dijkstra and Bellman-Ford',
    );

    await tester.tap(find.text('Back to Dashboard'));
    await tester.pumpAndSettle();
    expect(find.text('Teacher Home'), findsOneWidget);
    expect(find.byType(TeacherLectureFeedbackScreen), findsNothing);
  });

  testWidgets('teacher summary blocks continue when taught notes are empty', (
    tester,
  ) async {
    final store = CourseStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'Algorithms',
        code: 'CS-401',
        teacherId: 'teacher-1',
        department: 'Computer Science',
        semester: 'Fall 2026',
      ),
    );
    final started = await store.startLiveSession(
      LiveSessionModel(
        id: 'session-required-notes',
        courseId: 'CS-401',
        chapterId: 'chapter-1',
        chapterTitle: 'Graphs',
        topicId: 'topic-1',
        topicTitle: 'Shortest Paths',
        teacherId: 'teacher-1',
        durationMinutes: 45,
        startedAt: DateTime(2026, 9, 4, 10),
      ),
      courseName: 'Algorithms',
      teacherName: 'Demo Teacher',
    );
    await store.endLiveSession('CS-401', started.id, 'teacher-1');
    final ended = started.copyWith(
      status: LiveSessionStatus.ended,
      endedAt: DateTime(2026, 9, 4, 10, 42),
    );

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        authService: MockAuthService(),
        localeController: LocaleController(),
        themeController: ThemeController(),
        sessionController: SessionController(),
        courseStore: store,
        meetingStore: MeetingStore(),
        enrollment: CourseEnrollmentService(),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TeacherLectureSummaryScreen(
            session: ended,
            courseName: 'Algorithms',
            courseCode: 'CS-401',
            department: 'Computer Science',
            semester: 'Fall 2026',
            teacherId: 'teacher-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('View student feedback'));
    await tester.pump();
    expect(find.byType(TeacherLectureFeedbackScreen), findsNothing);
    expect(find.byType(TeacherLectureSummaryScreen), findsOneWidget);
    expect(find.text('Please enter what you taught today.'), findsWidgets);

    final notesField = find.byType(TextFormField);
    await tester.ensureVisible(notesField);
    await tester.enterText(notesField, '   ');
    await tester.tap(find.text('View student feedback'));
    await tester.pump();
    expect(find.byType(TeacherLectureFeedbackScreen), findsNothing);
    expect(find.text('Please enter what you taught today.'), findsWidgets);

    await tester.enterText(notesField, 'Covered shortest paths');
    await tester.tap(find.text('View student feedback'));
    await tester.pumpAndSettle();
    expect(find.byType(TeacherLectureFeedbackScreen), findsOneWidget);
    expect(
      (await store.watchLecture(started.id).first)?.summary?.taughtNotes,
      'Covered shortest paths',
    );
  });

  testWidgets('teacher summary prefills saved taught notes', (tester) async {
    final store = CourseStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'Algorithms',
        code: 'CS-401',
        teacherId: 'teacher-1',
        department: 'Computer Science',
        semester: 'Fall 2026',
      ),
    );
    final started = await store.startLiveSession(
      LiveSessionModel(
        id: 'session-notes',
        courseId: 'CS-401',
        chapterId: 'chapter-1',
        chapterTitle: 'Graphs',
        topicId: 'topic-1',
        topicTitle: 'Shortest Paths',
        teacherId: 'teacher-1',
        durationMinutes: 45,
        startedAt: DateTime(2026, 9, 4, 10),
      ),
      courseName: 'Algorithms',
      teacherName: 'Demo Teacher',
    );
    await store.endLiveSession('CS-401', started.id, 'teacher-1');
    final endedLecture = await store.watchLecture(started.id).first;
    final existingSummary = endedLecture?.summary;
    expect(existingSummary, isNotNull);
    await store.saveLectureSummary(
      lectureId: started.id,
      teacherId: 'teacher-1',
      summary: existingSummary!.copyWith(taughtNotes: 'Trees and heaps'),
    );
    final saved = await store.watchLecture(started.id).first;
    final ended = started.copyWith(
      status: LiveSessionStatus.ended,
      endedAt: DateTime(2026, 9, 4, 10, 42),
    );

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        authService: MockAuthService(),
        localeController: LocaleController(),
        themeController: ThemeController(),
        sessionController: SessionController(),
        courseStore: store,
        meetingStore: MeetingStore(),
        enrollment: CourseEnrollmentService(),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TeacherLectureSummaryScreen(
            session: ended,
            courseName: 'Algorithms',
            courseCode: 'CS-401',
            department: 'Computer Science',
            semester: 'Fall 2026',
            teacherId: 'teacher-1',
            summary: saved?.summary,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Trees and heaps'), findsOneWidget);
  });

  testWidgets('teacher summary blocks continue when notes fail to save', (
    tester,
  ) async {
    final store = _FailingSummaryStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'Algorithms',
        code: 'CS-401',
        teacherId: 'teacher-1',
        department: 'Computer Science',
        semester: 'Fall 2026',
      ),
    );
    final started = await store.startLiveSession(
      LiveSessionModel(
        id: 'session-save-fail',
        courseId: 'CS-401',
        chapterId: 'chapter-1',
        chapterTitle: 'Graphs',
        topicId: 'topic-1',
        topicTitle: 'Shortest Paths',
        teacherId: 'teacher-1',
        durationMinutes: 45,
        startedAt: DateTime(2026, 9, 4, 10),
      ),
      courseName: 'Algorithms',
      teacherName: 'Demo Teacher',
    );
    await store.endLiveSession('CS-401', started.id, 'teacher-1');
    final ended = started.copyWith(
      status: LiveSessionStatus.ended,
      endedAt: DateTime(2026, 9, 4, 10, 42),
    );

    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        authService: MockAuthService(),
        localeController: LocaleController(),
        themeController: ThemeController(),
        sessionController: SessionController(),
        courseStore: store,
        meetingStore: MeetingStore(),
        enrollment: CourseEnrollmentService(),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TeacherLectureSummaryScreen(
            session: ended,
            courseName: 'Algorithms',
            courseCode: 'CS-401',
            department: 'Computer Science',
            semester: 'Fall 2026',
            teacherId: 'teacher-1',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final notesField = find.byType(TextFormField);
    await tester.ensureVisible(notesField);
    await tester.enterText(notesField, 'Covered Dijkstra');
    await tester.tap(find.text('View student feedback'));
    await tester.pumpAndSettle();

    expect(find.byType(TeacherLectureFeedbackScreen), findsNothing);
    expect(find.byType(TeacherLectureSummaryScreen), findsOneWidget);
    expect(
      find.text('Could not save the lecture summary. Try again.'),
      findsOneWidget,
    );
  });

  test('startLiveSession stores taught notes immediately', () async {
    final store = CourseStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'Algorithms',
        code: 'CS-401',
        teacherId: 'teacher-1',
        department: 'Computer Science',
        semester: 'Fall 2026',
      ),
    );
    final started = await store.startLiveSession(
      LiveSessionModel(
        id: 'session-start-notes',
        courseId: 'CS-401',
        chapterId: 'chapter-1',
        chapterTitle: 'Graphs',
        topicId: 'topic-1',
        topicTitle: 'Shortest Paths',
        teacherId: 'teacher-1',
        durationMinutes: 45,
      ),
      courseName: 'Algorithms',
      teacherName: 'Demo Teacher',
      taughtNotes: '  Intro BFS and DFS  ',
    );
    final lecture = await store.watchLecture(started.id).first;
    expect(lecture?.taughtNotes, 'Intro BFS and DFS');
    expect(lecture?.summary?.taughtNotes, 'Intro BFS and DFS');
    expect(lecture?.resolvedTaughtNotes, 'Intro BFS and DFS');
    expect(await store.loadTaughtNotes(started.id), 'Intro BFS and DFS');
  });
}

class _FailingSummaryStore extends CourseStore {
  @override
  Future<void> saveLectureSummary({
    required String lectureId,
    required String teacherId,
    required LectureSummary summary,
  }) async {
    throw StateError('permission-denied');
  }
}
