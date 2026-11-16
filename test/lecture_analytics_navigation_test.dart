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
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/models/meeting_request.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/common/course_detail_screen.dart';
import 'package:learnsync/screens/teacher/course_lectures_screen.dart';
import 'package:learnsync/screens/teacher/lecture_analytics_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('meetingMatchesLecture prefers lectureId then topic keys', () {
    const withLectureId = MeetingRequest(
      id: 'm1',
      studentId: 's1',
      studentName: 'Ayesha',
      teacherId: 'teacher-1',
      teacherName: 'Soma',
      courseId: 'CS-500',
      courseName: 'AI',
      topicTitle: 'Other',
      reason: 'Help',
      lectureId: 'lec-a',
    );
    expect(
      meetingMatchesLecture(
        withLectureId,
        courseId: 'CS-500',
        lectureId: 'lec-a',
        topicId: 't-2',
        topicTitle: 'Other',
      ),
      isTrue,
    );
    expect(
      meetingMatchesLecture(
        withLectureId,
        courseId: 'CS-500',
        lectureId: 'lec-b',
        topicId: 't-2',
        topicTitle: 'Other',
      ),
      isFalse,
    );

    const byTopic = MeetingRequest(
      id: 'm2',
      studentId: 's1',
      studentName: 'Ayesha',
      teacherId: 'teacher-1',
      teacherName: 'Soma',
      courseId: 'CS-500',
      courseName: 'AI',
      topicId: 't-1',
      topicTitle: 'Backprop',
      reason: 'Help',
    );
    expect(
      meetingMatchesLecture(
        byTopic,
        courseId: 'CS-500',
        lectureId: 'lec-a',
        topicId: 't-1',
        topicTitle: 'Backprop',
      ),
      isTrue,
    );
    expect(
      meetingMatchesLecture(
        byTopic,
        courseId: 'CS-401',
        lectureId: 'lec-a',
        topicId: 't-1',
        topicTitle: 'Backprop',
      ),
      isFalse,
    );
  });

  testWidgets('teacher course details shows Lecture Analytics card', (
    tester,
  ) async {
    final env = await _seedCourse();
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(
        store: env.store,
        session: env.session,
        home: CourseDetailScreen(course: env.course),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lecture Analytics'), findsOneWidget);
    expect(
      find.text('See how students engaged with each lecture.'),
      findsOneWidget,
    );
  });

  testWidgets('students do not see Lecture Analytics on course details', (
    tester,
  ) async {
    final env = await _seedCourse();
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(
        store: env.store,
        session: env.session,
        home: CourseDetailScreen(course: env.course, canDelete: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Lecture Analytics'), findsNothing);
  });

  testWidgets('course lectures list shows empty state', (tester) async {
    final env = await _seedCourse();
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(
        store: env.store,
        session: env.session,
        home: CourseLecturesScreen(course: env.course),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.text(
        'No lectures yet for this course. After you run a live lecture, it will appear here.',
      ),
      findsOneWidget,
    );
  });

  testWidgets(
    'teacher can open lecture analytics and lecture-only meetings',
    (tester) async {
      final env = await _seedCourse();
      final started = await env.store.startLiveSession(
        LiveSessionModel(
          id: 'session-analytics-nav',
          courseId: 'CS-500',
          chapterId: 'ch-1',
          chapterTitle: 'Neural Nets',
          topicId: 't-1',
          topicTitle: 'Backprop',
          teacherId: 'teacher-1',
          durationMinutes: 40,
          startedAt: DateTime(2026, 9, 4, 9, 15),
        ),
        courseName: 'AI',
        teacherName: 'Soma Karim',
      );
      await env.store.markLectureAttendance(
        lectureId: started.id,
        studentId: 's1',
        studentName: 'Ayesha',
      );
      await env.store.endLiveSession('CS-500', started.id, 'teacher-1');
      await env.store.submitLectureFeedback(
        session: started.copyWith(status: LiveSessionStatus.ended),
        courseName: 'AI',
        teacherName: 'Soma Karim',
        studentId: 's1',
        studentName: 'Ayesha',
        level: UnderstandingLevel.percent100,
      );
      await env.store.savePracticeAttempt(
        attempt: AiPracticeAttempt(
          id: '',
          lectureId: started.id,
          courseId: 'CS-500',
          courseName: 'AI',
          teacherId: 'teacher-1',
          studentId: 's1',
          studentName: 'Ayesha',
          topicTitle: 'Backprop',
          score: 4,
          total: 5,
          selectedIndexes: const [0, 0, 0, 0, 0],
        ),
      );
      await env.meetings.createRequest(
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
      await env.meetings.createRequest(
        studentId: 's2',
        studentName: 'Bilal',
        teacherId: 'teacher-1',
        teacherName: 'Soma Karim',
        courseId: 'CS-500',
        courseName: 'AI',
        topicTitle: 'Optimizers',
        reason: 'Different topic',
        chapterId: 'ch-2',
        topicId: 't-9',
      );

      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        _scope(
          store: env.store,
          session: env.session,
          meetings: env.meetings,
          home: CourseDetailScreen(course: env.course),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lecture Analytics'));
      await tester.pumpAndSettle();
      expect(find.text('Course Lectures'), findsOneWidget);
      expect(find.text('Backprop'), findsOneWidget);

      await tester.tap(find.text('Backprop'));
      await tester.pumpAndSettle();

      expect(find.byType(LectureAnalyticsScreen), findsOneWidget);
      expect(find.text('1. Understanding'), findsOneWidget);
      expect(find.text('2. AI Practice'), findsOneWidget);
      expect(find.text('3. Meetings'), findsOneWidget);
      expect(find.text('Back to Lectures'), findsOneWidget);
      expect(find.byType(TabBar), findsNothing);

      await tester.tap(find.byTooltip('Lecture Meetings'));
      await tester.pumpAndSettle();
      expect(find.text('Requests for this lecture only.'), findsOneWidget);
      expect(find.text('Pending requests'), findsOneWidget);
      expect(find.text('Scheduled meetings'), findsOneWidget);
      expect(find.text('Attended'), findsOneWidget);

      await tester.tap(find.text('Pending requests'));
      await tester.pumpAndSettle();
      expect(find.text('Ayesha'), findsWidgets);
      expect(find.text('Bilal'), findsNothing);
    },
  );
}

class _Env {
  const _Env({
    required this.store,
    required this.meetings,
    required this.session,
    required this.course,
  });

  final CourseStore store;
  final MeetingStore meetings;
  final SessionController session;
  final CourseModel course;
}

Future<_Env> _seedCourse() async {
  final store = CourseStore();
  await store.addCourse(
    const CourseModel(
      id: '',
      name: 'AI',
      code: 'CS-500',
      teacherId: 'teacher-1',
      semester: 'Spring 2024',
    ),
  );
  final course = store.courses.first;
  final session = SessionController()
    ..signIn(
      const UserModel(
        id: 'teacher-1',
        fullName: 'Soma Karim',
        email: 'soma@example.com',
        role: UserRole.teacher,
      ),
    );
  return _Env(
    store: store,
    meetings: MeetingStore(),
    session: session,
    course: course,
  );
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
