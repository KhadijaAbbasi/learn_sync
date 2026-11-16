import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:learnsync/core/di/app_scope.dart';
import 'package:learnsync/core/localization/locale_controller.dart';
import 'package:learnsync/core/session/course_store.dart';
import 'package:learnsync/core/session/meeting_store.dart';
import 'package:learnsync/core/session/session_controller.dart';
import 'package:learnsync/core/theme/app_theme.dart';
import 'package:learnsync/core/theme/theme_controller.dart';
import 'package:learnsync/l10n/app_localizations.dart';
import 'package:learnsync/models/course_model.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/auth/login_screen.dart';
import 'package:learnsync/screens/common/course_detail_screen.dart';
import 'package:learnsync/screens/teacher/teacher_shell.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';
import 'package:learnsync/widgets/app_sidebar.dart';
import 'package:learnsync/widgets/live_lecture_workspace.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final previewKey = GlobalKey();
  late CourseStore store;
  late SessionController session;

  const course = CourseModel(
    id: 'CS-301',
    code: 'CS-301',
    name: 'Artificial Intelligence',
    teacherId: 'teacher-1',
    teacherName: 'Soma Khan',
    semester: 'Semester 5',
    department: 'Computer Science',
    creditHours: 3,
  );

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = CourseStore();
    session = SessionController()
      ..signIn(
        const UserModel(
          id: 'teacher-1',
          fullName: 'Soma Khan',
          email: 'soma@example.com',
          role: UserRole.teacher,
        ),
      );
    await store.addCourse(course);
    await store.addCourse(
      course.copyWith(id: 'CS-302', code: 'CS-302', name: 'Database Systems'),
    );
    await store.addCourse(
      course.copyWith(
        id: 'CS-303',
        code: 'CS-303',
        name: 'Software Engineering',
      ),
    );
    store.watchTeacher('teacher-1');
  });

  Future<void> pumpPage(
    WidgetTester tester,
    Widget page,
    Size size, {
    Locale locale = const Locale('en'),
    bool dark = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final locales = LocaleController()..setLocale(locale);
    await tester.pumpWidget(
      AppScope(
        authService: MockAuthService(),
        localeController: locales,
        themeController: ThemeController(),
        sessionController: session,
        courseStore: store,
        meetingStore: MeetingStore(),
        enrollment: CourseEnrollmentService(),
        child: RepaintBoundary(
          key: previewKey,
          child: MaterialApp(
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: dark
                ? AppTheme.dark(locale: locale)
                : AppTheme.light(locale: locale),
            home: page,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> preview(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('CAPTURE_DESKTOP_PREVIEWS')) return;
    await tester.runAsync(() async {
      final boundary =
          previewKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('build/desktop-previews/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'desktop dashboard has sidebar, flowing course columns and navigation',
    (tester) async {
      await pumpPage(tester, const TeacherShell(), const Size(1440, 900));
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);
      final first = tester.getTopLeft(find.text('Artificial Intelligence'));
      final second = tester.getTopLeft(find.text('Database Systems'));
      expect(second.dx, greaterThan(first.dx));
      expect(second.dy, closeTo(first.dy, 1));
      expect(tester.takeException(), isNull);
      await preview(tester, 'teacher-dashboard');
      final profile = find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Profile'),
      );
      await tester.ensureVisible(profile);
      await tester.tap(profile);
      await tester.pumpAndSettle();
      expect(
        TeacherShellScope.of(tester.element(find.byType(AppSidebar))).index,
        4,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'short laptop sidebar scrolls and phone keeps bottom navigation',
    (tester) async {
      await pumpPage(tester, const TeacherShell(), const Size(1024, 600));
      expect(tester.takeException(), isNull);
      final settings = find.descendant(
        of: find.byType(AppSidebar),
        matching: find.text('Settings'),
      );
      await tester.ensureVisible(settings);
      expect(settings.hitTestable(), findsOneWidget);
      await pumpPage(tester, const TeacherShell(), const Size(390, 844));
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop login fits laptop and supports Arabic dark layout', (
    tester,
  ) async {
    await pumpPage(tester, const LoginScreen(), const Size(1366, 768));
    expect(find.text('Login'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await preview(tester, 'desktop-login');
    await pumpPage(
      tester,
      const LoginScreen(),
      const Size(1024, 600),
      locale: const Locale('ar'),
      dark: true,
    );
    expect(tester.takeException(), isNull);
    await preview(tester, 'arabic-login');
  });

  testWidgets(
    'desktop course details show readable credit hours beside metadata',
    (tester) async {
      await pumpPage(
        tester,
        const CourseDetailScreen(course: course),
        const Size(1366, 768),
      );
      expect(find.text('3 credit hours'), findsOneWidget);
      expect(
        tester.getTopLeft(find.text('Course ID')).dx,
        lessThan(tester.getTopLeft(find.text('Course name')).dx),
      );
      expect(tester.takeException(), isNull);
      await preview(tester, 'course-details');
    },
  );

  testWidgets('lecture slides use main column on desktop and stack on phone', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    final workspace = Scaffold(
      body: LiveLectureWorkspace(
        controller: controller,
        courseIdentity: const Text('Course identity'),
        lectureInfo: const Text('Lecture information'),
        slides: Container(
          height: 460,
          color: Colors.teal,
          child: const Column(children: [Text('Slides'), _SlideStateProbe()]),
        ),
        attendees: const Text('Attendees'),
      ),
    );
    await pumpPage(tester, workspace, const Size(1440, 900));
    expect(
      tester.getTopLeft(find.text('Slides')).dx,
      lessThan(tester.getTopLeft(find.text('Course identity')).dx),
    );
    expect(tester.takeException(), isNull);
    await tester.tap(find.text('Next slide'));
    await tester.pump();
    expect(find.text('Slide 2'), findsOneWidget);
    await pumpPage(tester, workspace, const Size(390, 844));
    expect(find.text('Slide 2'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Slides')).dy,
      greaterThan(tester.getTopLeft(find.text('Course identity')).dy),
    );
    expect(tester.takeException(), isNull);
  });
}

class _SlideStateProbe extends StatefulWidget {
  const _SlideStateProbe();

  @override
  State<_SlideStateProbe> createState() => _SlideStateProbeState();
}

class _SlideStateProbeState extends State<_SlideStateProbe> {
  var page = 1;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Text('Slide $page'),
      TextButton(
        onPressed: () => setState(() => page++),
        child: const Text('Next slide'),
      ),
    ],
  );
}
