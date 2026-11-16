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
import 'package:learnsync/models/lecture_model.dart';
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/models/meeting_request.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/common/course_detail_screen.dart';
import 'package:learnsync/screens/teacher/lecture_meetings_details_screen.dart';
import 'package:learnsync/screens/teacher/lecture_meetings_hub_screen.dart';
import 'package:learnsync/screens/teacher/meeting_detail_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_enrollment_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('defaultMeetingBucket picks the first non-empty status', () {
    expect(defaultMeetingBucket(const []), LectureMeetingBucket.pending);
    expect(
      defaultMeetingBucket([
        _meeting(status: MeetingRequestStatus.accepted),
        _meeting(status: MeetingRequestStatus.completed),
      ]),
      LectureMeetingBucket.scheduled,
    );
    expect(
      defaultMeetingBucket([
        _meeting(status: MeetingRequestStatus.completed),
      ]),
      LectureMeetingBucket.attended,
    );
  });

  testWidgets('renders empty meetings details without crashing', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _scope(
        home: LectureMeetingsDetailsScreen(
          lecture: _lecture(),
          course: _course(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(tester.takeException(), isNull);
    expect(find.text('Meetings Details'), findsOneWidget);
    expect(find.text('0 / 0'), findsOneWidget);
    expect(
      find.text('No meeting requests for this lecture yet.'),
      findsOneWidget,
    );
    expect(find.byType(TabBar), findsNothing);
  });

  testWidgets('filters meeting rows to the selected bar and search query', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final env = await _seedLecture();
    final pending = await env.meetings.createRequest(
      studentId: 's1',
      studentName: 'Ayesha Khan',
      teacherId: 'teacher-1',
      teacherName: 'Soma Karim',
      courseId: env.course.id,
      courseName: 'AI',
      topicTitle: 'Backprop',
      reason: 'Need a review session',
      memberId: '1003',
      topicId: 't-1',
    );
    final scheduledDraft = await env.meetings.createRequest(
      studentId: 's2',
      studentName: 'Bilal Ahmed',
      teacherId: 'teacher-1',
      teacherName: 'Soma Karim',
      courseId: env.course.id,
      courseName: 'AI',
      topicTitle: 'Backprop',
      reason: 'Office hours',
      memberId: '1004',
      topicId: 't-1',
    );
    await env.meetings.acceptRequest(
      requestId: scheduledDraft.id,
      teacherId: 'teacher-1',
      scheduledAt: DateTime.now().add(const Duration(days: 1)),
    );
    final attendedDraft = await env.meetings.createRequest(
      studentId: 's3',
      studentName: 'Hania Malik',
      teacherId: 'teacher-1',
      teacherName: 'Soma Karim',
      courseId: env.course.id,
      courseName: 'AI',
      topicTitle: 'Backprop',
      reason: 'Follow up',
      memberId: '1005',
      topicId: 't-1',
    );
    await env.meetings.acceptRequest(
      requestId: attendedDraft.id,
      teacherId: 'teacher-1',
      scheduledAt: DateTime.now().subtract(const Duration(hours: 2)),
    );
    await env.meetings.completeRequest(
      requestId: attendedDraft.id,
      teacherId: 'teacher-1',
    );

    await tester.pumpWidget(
      _scope(
        store: env.store,
        session: env.session,
        meetings: env.meetings,
        home: LectureMeetingsDetailsScreen(
          lecture: env.lecture,
          course: env.course,
          meetings: [pending, scheduledDraft, attendedDraft],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Meetings Details'), findsOneWidget);
    expect(find.text('Meetings Overview'), findsOneWidget);
    expect(find.text('Total Meetings'), findsOneWidget);
    expect(find.text('3 / 3'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.text('1003'), findsOneWidget);
    expect(find.text('Bilal Ahmed'), findsNothing);
    expect(find.text('Hania Malik'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('meetings-bar-scheduled')));
    await tester.pumpAndSettle();
    expect(find.text('Ayesha Khan'), findsNothing);
    expect(find.text('Bilal Ahmed'), findsOneWidget);
    expect(find.text('1004'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'bilal');
    await tester.pumpAndSettle();
    expect(find.text('Bilal Ahmed'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No meetings match your search.'), findsOneWidget);
  });

  testWidgets('meeting row opens the existing meeting detail screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final env = await _seedLecture();
    final pending = await env.meetings.createRequest(
      studentId: 's1',
      studentName: 'Ayesha Khan',
      teacherId: 'teacher-1',
      teacherName: 'Soma Karim',
      courseId: env.course.id,
      courseName: 'AI',
      topicTitle: 'Backprop',
      reason: 'Need a review session',
      memberId: '1003',
      topicId: 't-1',
    );

    await tester.pumpWidget(
      _scope(
        store: env.store,
        session: env.session,
        meetings: env.meetings,
        home: LectureMeetingsDetailsScreen(
          lecture: env.lecture,
          course: env.course,
          meetings: [pending],
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(ValueKey('meetings-row-${pending.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(MeetingDetailScreen), findsOneWidget);
    expect(find.text('Meeting details'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsWidgets);
    expect(find.text('Need a review session'), findsOneWidget);
  });

  testWidgets('Lecture Analytics Meetings card opens details, icon opens hub', (
    tester,
  ) async {
    final env = await _seedLecture();
    await env.meetings.createRequest(
      studentId: 's1',
      studentName: 'Ayesha Khan',
      teacherId: 'teacher-1',
      teacherName: 'Soma Karim',
      courseId: env.course.id,
      courseName: 'AI',
      topicTitle: 'Backprop',
      reason: 'Need a review session',
      memberId: '1003',
      topicId: 't-1',
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
    await tester.tap(find.text('Backprop'));
    await tester.pumpAndSettle();

    expect(find.text('3. Meetings'), findsOneWidget);
    await tester.tap(find.text('3. Meetings'));
    await tester.pumpAndSettle();

    expect(find.byType(LectureMeetingsDetailsScreen), findsOneWidget);
    expect(find.text('Meetings Details'), findsOneWidget);
    expect(find.text('Ayesha Khan'), findsOneWidget);
    expect(find.byType(TabBar), findsNothing);

    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Lecture Meetings'));
    await tester.pumpAndSettle();
    expect(find.byType(LectureMeetingsHubScreen), findsOneWidget);
    expect(find.text('Requests for this lecture only.'), findsOneWidget);
    expect(find.text('Pending requests'), findsOneWidget);
  });
}

MeetingRequest _meeting({
  MeetingRequestStatus status = MeetingRequestStatus.pending,
}) {
  return MeetingRequest(
    id: 'm-${status.name}',
    studentId: 's1',
    studentName: 'Ayesha',
    teacherId: 'teacher-1',
    teacherName: 'Soma',
    courseId: 'CS-500',
    courseName: 'AI',
    topicTitle: 'Backprop',
    reason: 'Help',
    status: status,
  );
}

class _Env {
  const _Env({
    required this.store,
    required this.meetings,
    required this.session,
    required this.course,
    required this.lecture,
  });

  final CourseStore store;
  final MeetingStore meetings;
  final SessionController session;
  final CourseModel course;
  final LectureModel lecture;
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
      id: 'session-meetings',
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
  await store.endLiveSession('CS-500', started.id, 'teacher-1');
  final lecture = await store.watchLecture(started.id).first;
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
  MeetingStore? meetings,
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
