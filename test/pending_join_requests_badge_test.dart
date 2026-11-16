import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learnsync/core/di/app_scope.dart';
import 'package:learnsync/core/localization/locale_controller.dart';
import 'package:learnsync/core/session/course_store.dart';
import 'package:learnsync/core/session/meeting_store.dart';
import 'package:learnsync/core/session/session_controller.dart';
import 'package:learnsync/core/theme/app_colors.dart';
import 'package:learnsync/core/theme/theme_controller.dart';
import 'package:learnsync/l10n/app_localizations.dart';
import 'package:learnsync/models/course_model.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/teacher/teacher_shell.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';
import 'package:learnsync/widgets/app_sidebar.dart';
import 'package:learnsync/widgets/pending_join_requests_badge.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  const courseCode = '5102';

  late CourseEnrollmentService enrollment;
  late CourseStore courses;
  late SessionController session;

  setUp(() {
    enrollment = CourseEnrollmentService();
    courses = CourseStore();
    session = SessionController()
      ..signIn(
        const UserModel(
          id: 'teacher-1',
          fullName: 'Soma Karim',
          email: 'soma@example.com',
          role: UserRole.teacher,
        ),
      );
  });

  Future<void> addCourse() {
    return courses.addCourse(
      const CourseModel(
        id: courseCode,
        name: 'Data Science',
        code: courseCode,
        teacherId: 'teacher-1',
        department: 'Software Engineering',
      ),
    );
  }

  Future<void> pumpShell(
    WidgetTester tester,
    Size size, {
    int initialIndex = 0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        authService: MockAuthService(),
        localeController: LocaleController(),
        themeController: ThemeController(),
        sessionController: session,
        courseStore: courses,
        meetingStore: MeetingStore(),
        enrollment: enrollment,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: TeacherShell(initialIndex: initialIndex),
        ),
      ),
    );
    await tester.pump();
  }

  Future<void> requestJoin(String studentId) {
    return enrollment.requestJoin(
      courseId: courseCode,
      courseName: 'Data Science',
      courseCode: courseCode,
      studentId: studentId,
      studentName: 'Dijah',
    );
  }

  Finder dotIn(Finder scope) {
    return find.descendant(
      of: scope,
      matching: find.byKey(PendingJoinRequestsBadge.dotKey),
    );
  }

  void expectDot(WidgetTester tester, Finder scope, bool visible) {
    final dot = dotIn(scope);
    expect(dot, visible ? findsOneWidget : findsNothing);
    if (!visible) {
      return;
    }
    final box = tester.widget<DecoratedBox>(
      find.descendant(of: dot, matching: find.byType(DecoratedBox)),
    );
    final decoration = box.decoration as BoxDecoration;
    expect(decoration.color, AppColors.error);
    expect(decoration.shape, BoxShape.circle);
    final stack = tester.widget<Stack>(
      find.ancestor(of: dot, matching: find.byType(Stack)).first,
    );
    expect(stack.clipBehavior, Clip.none);
  }

  testWidgets('bottom nav dot tracks pending requests for teacher courses', (
    tester,
  ) async {
    await addCourse();
    await pumpShell(tester, const Size(400, 900));

    final bar = find.byType(NavigationBar);
    expectDot(tester, bar, false);

    await requestJoin('student-1');
    await tester.pump();
    expectDot(tester, bar, true);

    await requestJoin('student-2');
    await enrollment.accept(
      courseId: courseCode,
      teacherId: 'teacher-1',
      studentId: 'student-1',
    );
    await tester.pump();
    expectDot(tester, bar, true);

    await enrollment.decline(
      courseId: courseCode,
      teacherId: 'teacher-1',
      studentId: 'student-2',
    );
    await tester.pump();
    expectDot(tester, bar, false);

    await requestJoin('student-2');
    await tester.pump();
    expectDot(tester, bar, true);
  });

  testWidgets('dot shows on the joining tab once that course is in the store', (
    tester,
  ) async {
    await addCourse();
    await requestJoin('student-1');
    await pumpShell(tester, const Size(400, 900), initialIndex: 2);

    final bar = find.byType(NavigationBar);
    expect(find.byIcon(Icons.person_add_alt_1_rounded), findsOneWidget);
    expect(find.text('Dijah'), findsWidgets);
    expectDot(tester, bar, true);
  });

  testWidgets('dot appears when the course list loads after the request', (
    tester,
  ) async {
    await requestJoin('student-1');
    await pumpShell(tester, const Size(400, 900));

    final bar = find.byType(NavigationBar);
    expectDot(tester, bar, false);

    await addCourse();
    await tester.pump();
    await tester.pump();
    expectDot(tester, bar, true);
  });

  testWidgets('desktop sidebar joining requests entry shows the same dot', (
    tester,
  ) async {
    await addCourse();
    await pumpShell(tester, const Size(1200, 900));

    expect(find.byType(NavigationBar), findsNothing);
    final sidebar = find.byType(AppSidebar);
    expectDot(tester, sidebar, false);

    await requestJoin('student-1');
    await tester.pump();
    expectDot(tester, sidebar, true);

    await enrollment.accept(
      courseId: courseCode,
      teacherId: 'teacher-1',
      studentId: 'student-1',
    );
    await tester.pump();
    expectDot(tester, sidebar, false);
  });
}
