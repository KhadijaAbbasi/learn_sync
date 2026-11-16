import 'dart:async';

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
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/screens/common/live_session_screen.dart';
import 'package:learnsync/screens/student/lecture_feedback_screen.dart';
import 'package:learnsync/screens/student/student_slide_feedback_summary_screen.dart';
import 'package:learnsync/screens/teacher/teacher_lecture_summary_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('student reaches slide feedback summary then Lecture End', (
    tester,
  ) async {
    final sessions = StreamController<LiveSessionModel?>();
    addTearDown(sessions.close);
    final active = _session();
    final store = _ScriptedLiveStore(sessions.stream);

    await _pumpLiveSession(
      tester,
      store: store,
      session: active,
      canManage: false,
    );
    // Advance the header pulse so ending the session has to stop a ticker
    // that is mid-animation, which is what used to notify dependents during
    // the StreamBuilder build.
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(LiveSessionScreen), findsOneWidget);
    expect(find.text('You are currently attending live'), findsOneWidget);

    sessions.add(
      active.copyWith(
        status: LiveSessionStatus.ended,
        endedAt: DateTime(2026, 9, 4, 10, 42),
      ),
    );
    await _pumpRouteTransition(tester);

    expect(find.byType(LiveSessionScreen), findsNothing);
    expect(find.byType(StudentSlideFeedbackSummaryScreen), findsOneWidget);
    expect(find.textContaining('slide feedback'), findsWidgets);
    expect(
      find.text(
        'You did not leave feedback on any slides during this lecture.',
      ),
      findsOneWidget,
    );
    expect(find.byType(LectureFeedbackScreen), findsNothing);

    await tester.tap(find.widgetWithText(FilledButton, 'Next'));
    await _pumpRouteTransition(tester);

    expect(find.byType(StudentSlideFeedbackSummaryScreen), findsNothing);
    expect(find.byType(LectureFeedbackScreen), findsOneWidget);
    expect(find.byType(ErrorWidget), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('student who opens an already ended lecture is not redirected', (
    tester,
  ) async {
    final ended = _session().copyWith(
      status: LiveSessionStatus.ended,
      endedAt: DateTime(2026, 9, 4, 10, 42),
    );
    final sessions = StreamController<LiveSessionModel?>();
    addTearDown(sessions.close);
    final store = _ScriptedLiveStore(sessions.stream);

    await _pumpLiveSession(
      tester,
      store: store,
      session: ended,
      canManage: false,
    );
    sessions.add(ended);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(LiveSessionScreen), findsOneWidget);
    expect(find.byType(StudentSlideFeedbackSummaryScreen), findsNothing);
    expect(find.byType(LectureFeedbackScreen), findsNothing);
    expect(find.text('ENDED'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('teacher end still opens the lecture summary', (tester) async {
    final store = CourseStore();
    await store.addCourse(
      const CourseModel(
        id: '',
        name: 'Algorithms',
        code: 'CS-401',
        teacherId: 'teacher-1',
        teacherName: 'Demo Teacher',
        department: 'Computer Science',
        semester: 'Fall 2026',
      ),
    );
    final started = await store.startLiveSession(
      _session(startedAt: DateTime.now()),
      courseName: 'Algorithms',
      teacherName: 'Demo Teacher',
    );

    await _pumpLiveSession(
      tester,
      store: store,
      session: started,
      canManage: true,
      teacherId: 'teacher-1',
    );
    await tester.pump();

    await tester.tap(find.widgetWithText(FilledButton, 'End Lecture'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.text('End this live lecture for all students?'),
      findsOneWidget,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'End Lecture').last);
    await _pumpRouteTransition(tester);

    expect(find.byType(LiveSessionScreen), findsNothing);
    expect(find.byType(TeacherLectureSummaryScreen), findsOneWidget);
    expect(find.text('Shortest Paths'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}

class _ScriptedLiveStore extends CourseStore {
  _ScriptedLiveStore(this._sessions);

  final Stream<LiveSessionModel?> _sessions;

  @override
  Stream<LiveSessionModel?> watchLiveSession(
    String courseId,
    String sessionId,
  ) {
    return _sessions;
  }
}

LiveSessionModel _session({DateTime? startedAt}) {
  return LiveSessionModel(
    id: 'session-1',
    courseId: 'CS-401',
    chapterId: 'chapter-1',
    chapterTitle: 'Graphs',
    topicId: 'topic-1',
    topicTitle: 'Shortest Paths',
    teacherId: 'teacher-1',
    durationMinutes: 45,
    startedAt: startedAt ?? DateTime(2026, 9, 4, 10),
  );
}

Future<void> _pumpLiveSession(
  WidgetTester tester, {
  required CourseStore store,
  required LiveSessionModel session,
  required bool canManage,
  String teacherId = '',
}) async {
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final navigator = GlobalKey<NavigatorState>();
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
        navigatorKey: navigator,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routes: {
          AppRoutes.studentDashboard: (_) =>
              const Scaffold(body: Text('Student Home')),
          AppRoutes.teacherDashboard: (_) =>
              const Scaffold(body: Text('Teacher Home')),
        },
        home: const Scaffold(body: Text('Student shell')),
      ),
    ),
  );
  navigator.currentState!.push(
    MaterialPageRoute<void>(
      builder: (_) => LiveSessionScreen(
        courseName: 'Algorithms',
        session: session,
        canManage: canManage,
        teacherId: teacherId,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

/// Lets a post-frame [Navigator.pushReplacement] start and finish, then paints
/// the destination's own post-frame work (summary screen or Lecture End dialog).
Future<void> _pumpRouteTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}
