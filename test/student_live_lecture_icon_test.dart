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
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/common/live_session_screen.dart';
import 'package:learnsync/screens/student/student_dashboard.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late CourseStore store;
  late CourseEnrollmentService enrollment;
  late SessionController session;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = CourseStore();
    enrollment = CourseEnrollmentService();
    session = SessionController()
      ..signIn(
        const UserModel(
          id: 'student-1',
          fullName: 'dijah',
          email: 'dijah@example.com',
          role: UserRole.student,
          connectedTeacherId: 'teacher-1',
          connectedTeacherEmail: 'soma@example.com',
        ),
      );

    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'AI',
        code: 'AI-0221',
        teacherId: 'teacher-1',
      ),
    );
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'Data Science',
        code: '5102',
        teacherId: 'teacher-1',
      ),
    );
    store.watchTeacher('teacher-1');

    await enrollment.requestJoin(
      courseId: 'AI-0221',
      courseName: 'AI',
      courseCode: 'AI-0221',
      studentId: 'student-1',
      studentName: 'dijah',
    );
    await enrollment.accept(
      courseId: 'AI-0221',
      teacherId: 'teacher-1',
      studentId: 'student-1',
    );
  });

  Future<void> pumpDashboard(WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      AppScope(
        authService: MockAuthService(),
        localeController: LocaleController(),
        themeController: ThemeController(),
        sessionController: session,
        courseStore: store,
        meetingStore: MeetingStore(),
        enrollment: enrollment,
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          home: const StudentDashboard(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder liveLecturesButton() =>
      find.widgetWithIcon(IconButton, Icons.podcasts_rounded);

  Icon liveIcon(WidgetTester tester) {
    return tester.widget<Icon>(
      find.descendant(
        of: liveLecturesButton(),
        matching: find.byIcon(Icons.podcasts_rounded),
      ),
    );
  }

  IconButton liveButton(WidgetTester tester) {
    return tester.widget<IconButton>(liveLecturesButton());
  }

  LiveSessionModel sessionFor(String courseId, String id, String topic) {
    return LiveSessionModel(
      id: id,
      courseId: courseId,
      chapterId: 'chapter-1',
      chapterTitle: 'Chapter',
      topicId: 'topic-1',
      topicTitle: topic,
      teacherId: 'teacher-1',
      durationMinutes: 45,
    );
  }

  testWidgets('live icon follows joined courses and opens the lecture', (
    tester,
  ) async {
    await pumpDashboard(tester);
    expect(liveIcon(tester).color, isNull);
    expect(liveButton(tester).onPressed, isNull);

    final other = await store.startLiveSession(
      sessionFor('5102', 'live-other', 'Statistics'),
      courseName: 'Data Science',
      teacherName: 'Soma',
    );
    await tester.pump();
    expect(liveIcon(tester).color, isNull);
    expect(liveButton(tester).onPressed, isNull);

    await store.endLiveSession('5102', other.id, 'teacher-1');
    final joined = await store.startLiveSession(
      sessionFor('AI-0221', 'live-ai', 'Neural nets'),
      courseName: 'AI',
      teacherName: 'Soma',
    );
    await tester.pump();
    expect(liveIcon(tester).color, AppColors.coral);
    expect(liveButton(tester).onPressed, isNotNull);

    await tester.tap(liveLecturesButton());
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Join the live lecture for AI?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Join Lecture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(find.byType(LiveSessionScreen), findsOneWidget);

    navigator(tester).pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await store.endLiveSession('AI-0221', joined.id, 'teacher-1');
    await tester.pump();
    expect(liveIcon(tester).color, isNull);
    expect(liveButton(tester).onPressed, isNull);
  });

  testWidgets('multiple joined lives open the picker', (tester) async {
    await enrollment.requestJoin(
      courseId: '5102',
      courseName: 'Data Science',
      courseCode: '5102',
      studentId: 'student-1',
      studentName: 'dijah',
    );
    await enrollment.accept(
      courseId: '5102',
      teacherId: 'teacher-1',
      studentId: 'student-1',
    );
    await store.startLiveSession(
      sessionFor('AI-0221', 'live-ai', 'Neural nets'),
      courseName: 'AI',
      teacherName: 'Soma',
    );
    await store.startLiveSession(
      sessionFor(
        '5102',
        'live-ds',
        'Statistics',
      ).copyWith(teacherId: 'teacher-2'),
      courseName: 'Data Science',
      teacherName: 'Other',
    );

    await pumpDashboard(tester);
    expect(liveIcon(tester).color, AppColors.coral);

    await tester.tap(liveLecturesButton());
    await tester.pumpAndSettle();
    expect(find.text('Choose a live lecture to join'), findsOneWidget);
    expect(find.text('AI'), findsWidgets);
    expect(find.text('Data Science'), findsWidgets);

    await tester.tap(find.widgetWithText(FilledButton, 'Join Lecture').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Join the live lecture for'), findsOneWidget);
  });
}

NavigatorState navigator(WidgetTester tester) {
  return tester.state<NavigatorState>(find.byType(Navigator));
}
