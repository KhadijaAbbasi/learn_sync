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
import 'package:learnsync/models/course_model.dart';
import 'package:learnsync/models/lecture_feedback.dart';
import 'package:learnsync/models/lecture_model.dart';
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/common/course_detail_screen.dart';
import 'package:learnsync/screens/common/profile_settings_screen.dart';
import 'package:learnsync/screens/teacher/lecture_understanding_details_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('defaultSelectedLevel picks the first non-empty bucket', () {
    expect(
      const LectureFeedbackCounts().defaultSelectedLevel,
      UnderstandingLevel.percent100,
    );
    expect(
      const LectureFeedbackCounts(percent80: 2).defaultSelectedLevel,
      UnderstandingLevel.percent80,
    );
    expect(
      const LectureFeedbackCounts(
        percent60: 1,
        below50: 4,
      ).defaultSelectedLevel,
      UnderstandingLevel.percent60,
    );
    expect(
      const LectureFeedbackCounts(below50: 3).defaultSelectedLevel,
      UnderstandingLevel.below50,
    );
  });

  test('shareLabel formats whole and fractional percents', () {
    const counts = LectureFeedbackCounts(
      percent100: 18,
      percent80: 12,
      percent60: 7,
      below50: 5,
    );
    expect(counts.shareLabel(UnderstandingLevel.percent100), '42.9%');
    expect(counts.shareLabel(UnderstandingLevel.percent80), '28.6%');
    expect(
      const LectureFeedbackCounts().shareLabel(UnderstandingLevel.percent100),
      '0%',
    );
  });

  test('resolveLectureAudienceCount falls back without crashing', () {
    expect(
      resolveLectureAudienceCount(
        attendeeRecords: 8,
        lectureStudentCount: 10,
        responseCount: 5,
      ),
      8,
    );
    expect(
      resolveLectureAudienceCount(
        attendeeRecords: 0,
        lectureStudentCount: 10,
        responseCount: 5,
      ),
      10,
    );
    expect(
      resolveLectureAudienceCount(
        attendeeRecords: 0,
        lectureStudentCount: 0,
        responseCount: 5,
      ),
      5,
    );
    expect(
      resolveLectureAudienceCount(
        attendeeRecords: 0,
        lectureStudentCount: 0,
        responseCount: 0,
      ),
      0,
    );
  });

  testWidgets('renders on a phone-width viewport without overflow', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final feedback = [
      _feedback('s1', 'Ayesha Khan', UnderstandingLevel.percent100),
      _feedback('s2', 'Bilal Ahmed', UnderstandingLevel.percent80),
    ];

    await tester.pumpWidget(
      _scope(
        home: LectureUnderstandingDetailsScreen(
          lecture: _lecture(),
          course: _course(),
          feedback: feedback,
          counts: LectureFeedbackCounts.fromList(feedback),
          attendeeCount: 2,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Understanding Details'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
  });

  testWidgets('filters the list to the selected bar and search query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final feedback = [
      _feedback('s1', 'Ayesha Khan', UnderstandingLevel.percent100),
      _feedback('s2', 'Bilal Ahmed', UnderstandingLevel.percent80),
      _feedback('s3', 'Hania Malik', UnderstandingLevel.percent80),
      _feedback('s4', 'Omar Said', UnderstandingLevel.below50),
    ];

    await tester.pumpWidget(
      _scope(
        home: LectureUnderstandingDetailsScreen(
          lecture: _lecture(),
          course: _course(),
          feedback: feedback,
          counts: LectureFeedbackCounts.fromList(feedback),
          attendeeCount: 4,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Understanding Details'), findsOneWidget);
    expect(find.text('Understanding Overview'), findsOneWidget);
    expect(find.text('Total Responses'), findsOneWidget);
    expect(find.text('4 / 4'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('understanding-bar-percent80')));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Khan'), findsNothing);
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('Hania Malik'), findsOneWidget);
    expect(find.text('Omar Said'), findsNothing);

    await tester.enterText(find.byType(TextField), 'hania');
    await tester.pumpAndSettle();
    expect(find.text('Hania Malik'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No students match your search.'), findsOneWidget);
  });

  testWidgets('student row opens a read-only teacher profile', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final feedback = [
      _feedback(
        's1',
        'Ayesha Khan',
        UnderstandingLevel.percent100,
        email: 'ayesha@example.com',
      ),
    ];

    await tester.pumpWidget(
      _scope(
        home: LectureUnderstandingDetailsScreen(
          lecture: _lecture(),
          course: _course(),
          feedback: feedback,
          counts: LectureFeedbackCounts.fromList(feedback),
          attendeeCount: 1,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('understanding-student-s1')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSettingsScreen), findsOneWidget);
    expect(find.text('Student Profile'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsWidgets);
    expect(find.text('ayesha@example.com'), findsOneWidget);
    expect(find.text('Understanding for this lecture'), findsOneWidget);
    expect(find.text('Understood perfectly'), findsOneWidget);
  });

  testWidgets('Lecture Analytics Understanding card opens the details screen', (
    tester,
  ) async {
    final env = await _seedLecture();
    tester.view.physicalSize = const Size(800, 2400);
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

    await tester.tap(find.text('Lecture Analytics'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Backprop'));
    await tester.pumpAndSettle();

    expect(find.text('1. Understanding'), findsOneWidget);
    await tester.tap(find.text('1. Understanding'));
    await tester.pumpAndSettle();

    expect(find.byType(LectureUnderstandingDetailsScreen), findsOneWidget);
    expect(find.text('Understanding Details'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });
}

LectureFeedback _feedback(
  String id,
  String name,
  UnderstandingLevel level, {
  String email = '',
}) {
  return LectureFeedback(
    id: 'lec-1_$id',
    lectureId: 'lec-1',
    sessionId: 'lec-1',
    courseId: 'CS-500',
    courseName: 'AI',
    teacherId: 'teacher-1',
    teacherName: 'Soma Karim',
    studentId: id,
    studentName: name,
    studentEmail: email,
    level: level,
    chapterTitle: 'Neural Nets',
    topicTitle: 'Backprop',
  );
}

LectureModel _lecture() {
  return LectureModel(
    id: 'lec-1',
    courseId: 'CS-500',
    courseName: 'AI',
    teacherId: 'teacher-1',
    teacherName: 'Soma Karim',
    chapterId: 'ch-1',
    chapterTitle: 'Neural Nets',
    topicId: 't-1',
    topicTitle: 'Backprop',
    durationMinutes: 40,
    status: LectureStatus.ended,
    startedAt: DateTime(2026, 5, 28, 9, 15),
    endedAt: DateTime(2026, 5, 28, 10, 30),
    studentCount: 4,
  );
}

CourseModel _course() {
  return const CourseModel(
    id: 'CS-500',
    name: 'AI',
    code: 'CS-500',
    teacherId: 'teacher-1',
    semester: 'Spring 2024',
  );
}

class _Env {
  const _Env({
    required this.store,
    required this.session,
    required this.course,
  });

  final CourseStore store;
  final SessionController session;
  final CourseModel course;
}

Future<_Env> _seedLecture() async {
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
  final started = await store.startLiveSession(
    LiveSessionModel(
      id: 'session-understanding',
      courseId: course.id,
      chapterId: 'ch-1',
      chapterTitle: 'Neural Nets',
      topicId: 't-1',
      topicTitle: 'Backprop',
      teacherId: 'teacher-1',
      durationMinutes: 40,
      startedAt: DateTime(2026, 5, 28, 9, 15),
    ),
    courseName: 'AI',
    teacherName: 'Soma Karim',
  );
  await store.markLectureAttendance(
    lectureId: started.id,
    studentId: 's1',
    studentName: 'Ayesha Khan',
    studentEmail: 'ayesha@example.com',
  );
  await store.endLiveSession('CS-500', started.id, 'teacher-1');
  await store.submitLectureFeedback(
    session: started.copyWith(status: LiveSessionStatus.ended),
    courseName: 'AI',
    teacherName: 'Soma Karim',
    studentId: 's1',
    studentName: 'Ayesha Khan',
    studentEmail: 'ayesha@example.com',
    level: UnderstandingLevel.percent100,
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
  return _Env(store: store, session: session, course: course);
}

Widget _scope({
  required Widget home,
  CourseStore? store,
  SessionController? session,
}) {
  return AppScope(
    authService: MockAuthService(),
    localeController: LocaleController(),
    themeController: ThemeController(),
    sessionController:
        session ??
        (SessionController()..signIn(
          const UserModel(
            id: 'teacher-1',
            fullName: 'Soma Karim',
            email: 'soma@example.com',
            role: UserRole.teacher,
          ),
        )),
    courseStore: store ?? CourseStore(),
    meetingStore: MeetingStore(),
    enrollment: CourseEnrollmentService(),
    child: MaterialApp(
      locale: const Locale('en'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: home,
    ),
  );
}
