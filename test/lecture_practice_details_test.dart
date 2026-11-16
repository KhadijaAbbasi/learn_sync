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
import 'package:learnsync/models/lecture_model.dart';
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/common/course_detail_screen.dart';
import 'package:learnsync/screens/common/profile_settings_screen.dart';
import 'package:learnsync/screens/teacher/lecture_practice_details_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';
import 'package:learnsync/widgets/category_share_bar_chart.dart';
import 'package:learnsync/widgets/lecture_analytics_details_chrome.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('categoryShareLabel formats whole and fractional percents', () {
    expect(categoryShareLabel(1, 2), '50%');
    expect(categoryShareLabel(18, 42), '42.9%');
    expect(categoryShareLabel(0, 0), '0%');
  });

  test('lectureStudentDisplayId prefers memberId', () {
    expect(
      lectureStudentDisplayId(memberId: '1003', studentId: 'uid-1'),
      '1003',
    );
    expect(lectureStudentDisplayId(memberId: '', studentId: 'uid-1'), 'uid-1');
    expect(lectureStudentDisplayId(), '');
  });

  testWidgets('renders empty practice details without crashing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(
        home: LecturePracticeDetailsScreen(
          lecture: _lecture(),
          course: _course(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('AI Practice Details'), findsOneWidget);
    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      find.text('No AI practice attempts for this lecture yet.'),
      findsOneWidget,
    );
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('filters the list to the selected bar and search query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final env = await _seedLecture(withPractice: true);

    await tester.pumpWidget(
      _scope(
        store: env.store,
        session: env.session,
        home: LecturePracticeDetailsScreen(
          lecture: env.lecture,
          course: env.course,
          practiced: 1,
          notPracticed: 1,
          attendeeCount: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI Practice Details'), findsOneWidget);
    expect(find.text('AI Practice Overview'), findsOneWidget);
    expect(find.text('Total Practice'), findsOneWidget);
    expect(find.text('1 / 2'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('1003'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsNothing);
    expect(find.text('1004'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('practice-bar-notPracticed')));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Khan'), findsNothing);
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('1004'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bilal');
    await tester.pumpAndSettle();
    expect(find.text('Bilal Ahmed'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No students match your search.'), findsOneWidget);
  });

  testWidgets('student row opens a read-only shared profile', (tester) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final env = await _seedLecture(withPractice: true);
    final auth = MockAuthService()
      ..seedUser(
        const UserModel(
          id: 's1',
          fullName: 'Ayesha Khan',
          email: 'ayesha@example.com',
          role: UserRole.student,
          memberId: '1003',
        ),
      );

    await tester.pumpWidget(
      _scope(
        store: env.store,
        session: env.session,
        auth: auth,
        home: LecturePracticeDetailsScreen(
          lecture: env.lecture,
          course: env.course,
          practiced: 1,
          notPracticed: 1,
          attendeeCount: 2,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('practice-student-s1')));
    await tester.pumpAndSettle();

    expect(find.byType(ProfileSettingsScreen), findsOneWidget);
    expect(find.text('Student Profile'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsWidgets);
    expect(find.text('Delete Account'), findsNothing);
    expect(find.byTooltip('Edit'), findsNothing);
  });

  testWidgets('Lecture Analytics AI Practice card opens the details screen', (
    tester,
  ) async {
    final env = await _seedLecture(withPractice: true);
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

    expect(find.text('2. AI Practice'), findsOneWidget);
    await tester.tap(find.text('2. AI Practice'));
    await tester.pumpAndSettle();

    expect(find.byType(LecturePracticeDetailsScreen), findsOneWidget);
    expect(find.text('AI Practice Details'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);
  });
}

class _Env {
  const _Env({
    required this.store,
    required this.session,
    required this.course,
    required this.lecture,
  });

  final CourseStore store;
  final SessionController session;
  final CourseModel course;
  final LectureModel lecture;
}

Future<_Env> _seedLecture({required bool withPractice}) async {
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
      id: 'session-practice',
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
    memberId: '1003',
  );
  await store.markLectureAttendance(
    lectureId: started.id,
    studentId: 's2',
    studentName: 'Bilal Ahmed',
    studentEmail: 'bilal@example.com',
    memberId: '1004',
  );
  await store.endLiveSession('CS-500', started.id, 'teacher-1');
  if (withPractice) {
    await store.savePracticeAttempt(
      attempt: AiPracticeAttempt(
        id: '',
        lectureId: started.id,
        courseId: course.id,
        courseName: 'AI',
        teacherId: 'teacher-1',
        studentId: 's1',
        studentName: 'Ayesha Khan',
        topicTitle: 'Backprop',
        score: 4,
        total: 5,
        selectedIndexes: const [0, 0, 0, 0, 0],
      ),
    );
  }
  final session = SessionController()
    ..signIn(
      const UserModel(
        id: 'teacher-1',
        fullName: 'Soma Karim',
        email: 'soma@example.com',
        role: UserRole.teacher,
      ),
    );
  final lecture = await store.watchLecture(started.id).first;
  return _Env(
    store: store,
    session: session,
    course: course,
    lecture: lecture ?? _lecture(),
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
    studentCount: 0,
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

Widget _scope({
  required Widget home,
  CourseStore? store,
  SessionController? session,
  AuthService? auth,
}) {
  return AppScope(
    authService: auth ?? MockAuthService(),
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
