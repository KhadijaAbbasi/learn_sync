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
import 'package:learnsync/models/ai_practice.dart';
import 'package:learnsync/models/course_model.dart';
import 'package:learnsync/models/lecture_feedback.dart';
import 'package:learnsync/models/live_session_model.dart';
import 'package:learnsync/models/user_model.dart';
import 'package:learnsync/models/user_role.dart';
import 'package:learnsync/screens/student/ai_practice_results_screen.dart';
import 'package:learnsync/screens/student/ai_practice_screen.dart';
import 'package:learnsync/services/auth_service.dart';
import 'package:learnsync/services/course_document_text.dart';
import 'package:learnsync/services/course_enrollment_service.dart';
import 'package:learnsync/services/ai_practice_generator.dart';
import 'package:learnsync/services/stub_ai_practice_generator.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('parseAiQuiz reads tool-style JSON and rejects junk', () {
    final quiz = parseAiQuiz('''
{
  "questions": [
    {"question": "Q1", "options": ["a", "b", "c"], "correctIndex": 1, "reason": "e1"},
    {"question": "Q2", "options": ["a", "b", "c"], "correctIndex": 0, "reason": "e2"},
    {"question": "Q3", "options": ["a", "b", "c"], "correctIndex": 2, "reason": "e3"},
    {"question": "Q4", "options": ["a", "b", "c"], "correctIndex": 1, "reason": "e4"},
    {"question": "Q5", "options": ["a", "b", "c"], "correctIndex": 0, "reason": "e5"}
  ]
}
''');
    expect(quiz.length, 5);
    expect(quiz.questions.first.correctIndex, 1);
    expect(quiz.questions.first.explanation, 'e1');
    expect(
      () => parseAiQuiz('{"questions":[{"question":"only one"}]}'),
      throwsA(isA<AiPracticeException>()),
    );
  });

  test('parseAiQuiz keeps the slide a question came from', () {
    final quiz = parseAiQuiz([
      for (var i = 0; i < 5; i++)
        {
          'question': 'Q$i',
          'options': ['a', 'b', 'c'],
          'correctIndex': 0,
          'sourceIndex': i == 0 ? 1 : 0,
          'fileIndex': 0,
          'slidePage': 4,
          'fileName': 'intro.pptx',
        },
    ]);
    expect(quiz.questions.first.sourceIndex, 1);
    expect(quiz.questions.first.slideFileIndex, 0);
    expect(quiz.questions.first.slidePage, 4);
    expect(quiz.questions.first.slideFileName, 'intro.pptx');
    expect(quiz.questions.first.slideIdentity, 'intro.pptx, slide 4');
  });

  test('stampBelow50QuizSources labels only below-50 slides', () {
    final quiz = parseAiQuiz([
      for (var i = 0; i < 5; i++)
        {
          'question': 'Q$i about the lecture',
          'options': ['a', 'b', 'c'],
          'correctAnswer': i.isEven ? 'A' : 'B',
          if (i == 0) 'sourceIndex': 1,
        },
    ]);
    final stamped = stampBelow50QuizSources(
      quiz: quiz,
      chapterTitle: 'Neural Nets',
      lectureTitle: 'Backprop',
      below50Slides: const [
        WeakSlideFocus(
          fileIndex: 0,
          slidePage: 2,
          fileName: 'intro.pptx',
          levelLabel: 'Below 50% (need help)',
          priority: 3,
        ),
        WeakSlideFocus(
          fileIndex: 1,
          slidePage: 4,
          fileName: 'graphs.pptx',
          levelLabel: 'Below 50% (need help)',
          priority: 3,
        ),
      ],
    );
    expect(stamped.questions.first.chapterTitle, 'Neural Nets');
    expect(stamped.questions.first.lectureTitle, 'Backprop');
    expect(stamped.questions.first.slideFileName, 'graphs.pptx');
    expect(stamped.questions.first.slidePage, 4);
    expect(
      stamped.questions.every(
        (question) =>
            question.slideFileName == 'intro.pptx' ||
            question.slideFileName == 'graphs.pptx',
      ),
      isTrue,
    );
    expect(
      stamped.questions.every((question) => question.slidePage == 2 || question.slidePage == 4),
      isTrue,
    );
  });

  test('stampBelow50QuizSources does not fake Q-index as slide number', () {
    final quiz = parseAiQuiz([
      for (var i = 0; i < 5; i++)
        {
          'question': 'Distinct prompt number $i for hashing',
          'options': ['a', 'b', 'c'],
          'correctAnswer': 'A',
        },
    ]);
    final stamped = stampBelow50QuizSources(
      quiz: quiz,
      chapterTitle: 'Ch',
      lectureTitle: 'L',
      below50Slides: const [
        WeakSlideFocus(
          fileIndex: 0,
          slidePage: 7,
          fileName: 'deck.pptx',
          levelLabel: 'Lecture slide',
          priority: 0,
        ),
        WeakSlideFocus(
          fileIndex: 0,
          slidePage: 11,
          fileName: 'deck.pptx',
          levelLabel: 'Lecture slide',
          priority: 0,
        ),
        WeakSlideFocus(
          fileIndex: 0,
          slidePage: 15,
          fileName: 'deck.pptx',
          levelLabel: 'Lecture slide',
          priority: 0,
        ),
      ],
    );
    final pages = [for (final q in stamped.questions) q.slidePage];
    expect(pages.every((page) => page == 7 || page == 11 || page == 15), isTrue);
    // Must not look like fake sequential Slide 1/2/3 for Q1/Q2/Q3.
    expect(pages, isNot([1, 2, 3, 4, 5]));
  });

  test('textForSlideTargets drops slides that are not below 50', () {
    const slides = [
      SlideTextChunk(
        fileIndex: 0,
        slidePage: 1,
        fileName: 'ok.pptx',
        text: 'This slide was marked 80 percent.',
      ),
      SlideTextChunk(
        fileIndex: 0,
        slidePage: 4,
        fileName: 'ok.pptx',
        text: 'This slide needs help.',
      ),
    ];
    final focused = textForSlideTargets(
      slides: slides,
      targetKeys: const {'0:4'},
      fallbackNotes: 'full lecture notes',
    );
    expect(focused, contains('This slide needs help.'));
    expect(focused, isNot(contains('80 percent')));
    expect(
      textForSlideTargets(
        slides: slides,
        targetKeys: const {'9:9'},
        fallbackNotes: 'full lecture notes',
      ),
      'full lecture notes',
    );
  });

  test('course store persists a completed practice attempt', () async {
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
        id: 'session-practice',
        courseId: 'CS-500',
        chapterId: 'ch-1',
        chapterTitle: 'Neural Nets',
        topicId: 't-1',
        topicTitle: 'Backprop',
        teacherId: 'teacher-1',
        durationMinutes: 40,
      ),
      courseName: 'AI',
      teacherName: 'Demo Teacher',
    );
    await store.endLiveSession('CS-500', started.id, 'teacher-1');
    final quiz = await StubAiPracticeGenerator().generateQuiz(
      const AiQuizRequest(
        taughtNotes: 'Covered backpropagation and vanishing gradients',
        topicTitle: 'Backprop',
      ),
    );
    final selected = List<int>.filled(5, 0);
    final saved = await store.savePracticeAttempt(
      attempt: AiPracticeAttempt(
        id: '',
        lectureId: started.id,
        courseId: 'CS-500',
        courseName: 'AI',
        studentId: 'student-1',
        studentName: 'Ayesha',
        topicTitle: 'Backprop',
        score: scoreQuiz(quiz, selected),
        total: quiz.length,
        selectedIndexes: selected,
        questions: quiz.questions,
        diagnostic: 'Strong grasp of backpropagation.',
      ),
    );
    expect(saved.completed, isTrue);
    expect(saved.passed, isTrue);
    expect(saved.percent, 100);
    final attempts = await store.watchLecturePracticeAttempts(started.id).first;
    expect(attempts.single.studentId, 'student-1');
  });

  testWidgets('AI practice quiz submits to results from taught notes', (
    tester,
  ) async {
    final store = CourseStore();
    final session = SessionController()
      ..signIn(
        const UserModel(
          id: 'student-1',
          fullName: 'Ayesha',
          email: 'ayesha@example.com',
          role: UserRole.student,
        ),
      );
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
        id: 'session-ui-practice',
        courseId: 'CS-500',
        chapterId: 'ch-1',
        chapterTitle: 'Neural Nets',
        topicId: 't-1',
        topicTitle: 'Neural Networks',
        teacherId: 'teacher-1',
        durationMinutes: 40,
        startedAt: DateTime(2026, 9, 4, 10),
      ),
      courseName: 'AI',
      teacherName: 'Demo Teacher',
    );
    await store.submitLiveSlideSignal(
      session: started,
      studentId: 'student-1',
      studentName: 'Ayesha',
      fileIndex: 0,
      page: 4,
      level: UnderstandingLevel.below50,
    );
    await store.submitLiveSlideSignal(
      session: started,
      studentId: 'student-1',
      studentName: 'Ayesha',
      fileIndex: 0,
      page: 2,
      level: UnderstandingLevel.percent80,
    );
    await store.endLiveSession('CS-500', started.id, 'teacher-1');
    final endedLecture = await store.watchLecture(started.id).first;
    await store.saveLectureSummary(
      lectureId: started.id,
      teacherId: 'teacher-1',
      summary: endedLecture!.summary!.copyWith(
        taughtNotes: 'Covered feedforward nets and backpropagation.',
      ),
    );
    expect(
      await store.loadTaughtNotes(started.id),
      'Covered feedforward nets and backpropagation.',
    );
    final ended = started.copyWith(
      status: LiveSessionStatus.ended,
      endedAt: DateTime(2026, 9, 4, 10, 40),
    );
    final generator = StubAiPracticeGenerator();

    tester.view.physicalSize = const Size(800, 2400);
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
        enrollment: CourseEnrollmentService(),
        child: MaterialApp(
          locale: const Locale('en'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          routes: {
            AppRoutes.studentDashboard: (_) =>
                const Scaffold(body: Text('Student Home')),
          },
          home: AiPracticeScreen(
            session: ended,
            courseName: 'AI',
            studentId: 'student-1',
            studentName: 'Ayesha',
            generator: generator,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Practice with AI'), findsOneWidget);
    expect(find.textContaining('Topic: Neural Networks'), findsOneWidget);
    expect(find.text('SUBMIT QUIZ'), findsOneWidget);
    expect(generator.generateCalls, 1);
    expect(generator.lastRequest!.weakSlides, hasLength(1));
    expect(generator.lastRequest!.weakSlides.single.slidePage, 4);
    expect(
      generator.lastRequest!.weakSlides.single.levelLabel,
      contains('Below 50'),
    );
    expect(find.textContaining('Chapter: Neural Nets'), findsOneWidget);
    expect(find.textContaining('Lecture: Neural Networks'), findsOneWidget);
    expect(find.textContaining('Topic: Neural Networks'), findsOneWidget);
    // Real below-50 slide page on every question (not Q1->Slide 1).
    expect(find.textContaining('Slide: 4'), findsNWidgets(5));
    expect(find.textContaining('Slide: 2'), findsNothing);

    final optionTiles = find.textContaining('It matches what was taught');
    expect(optionTiles, findsNWidgets(5));
    for (final element in optionTiles.evaluate()) {
      await tester.tap(find.byWidget(element.widget));
      await tester.pump();
    }
    await tester.tap(find.text('SUBMIT QUIZ'));
    await tester.pumpAndSettle();

    expect(find.byType(AiPracticeResultsScreen), findsOneWidget);
    expect(find.text('AI Quiz Results'), findsOneWidget);
    await tester.tap(find.text('Review Question Explanations'));
    await tester.pumpAndSettle();
    // Results use liveSlideOnPage => "Slide 4" (no colon).
    expect(find.textContaining('Slide 4'), findsWidgets);
    expect(find.textContaining('Slide 2'), findsNothing);
    expect(find.text('Practice Again'), findsOneWidget);
    expect(find.text('End Practice'), findsOneWidget);
    final attempts = await store.watchLecturePracticeAttempts(started.id).first;
    expect(attempts, isNotEmpty);
    expect(attempts.first.score, 5);
  });

  testWidgets('AI practice generates full-lecture quiz when no slide is below 50', (
    tester,
  ) async {
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
        id: 'session-no-below50',
        courseId: 'CS-500',
        chapterId: 'ch-1',
        chapterTitle: 'Neural Nets',
        topicId: 't-1',
        topicTitle: 'Neural Networks',
        teacherId: 'teacher-1',
        durationMinutes: 40,
      ),
      courseName: 'AI',
      teacherName: 'Demo Teacher',
    );
    await store.submitLiveSlideSignal(
      session: started,
      studentId: 'student-1',
      studentName: 'Ayesha',
      fileIndex: 0,
      page: 2,
      level: UnderstandingLevel.percent60,
    );
    await store.submitLiveSlideSignal(
      session: started,
      studentId: 'student-1',
      studentName: 'Ayesha',
      fileIndex: 0,
      page: 3,
      level: UnderstandingLevel.percent80,
    );
    await store.endLiveSession('CS-500', started.id, 'teacher-1');
    final endedLecture = await store.watchLecture(started.id).first;
    await store.saveLectureSummary(
      lectureId: started.id,
      teacherId: 'teacher-1',
      summary: endedLecture!.summary!.copyWith(
        taughtNotes: 'Covered feedforward nets and backpropagation.',
      ),
    );
    final ended = started.copyWith(status: LiveSessionStatus.ended);
    final generator = StubAiPracticeGenerator();

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
          home: AiPracticeScreen(
            session: ended,
            courseName: 'AI',
            studentId: 'student-1',
            studentName: 'Ayesha',
            generator: generator,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // No below-50 feedback => generate a general quiz from full lecture notes.
    expect(find.text('No slides below 50%'), findsNothing);
    expect(find.text('SUBMIT QUIZ'), findsOneWidget);
    expect(generator.generateCalls, 1);
    expect(generator.lastRequest, isNotNull);
    expect(generator.lastRequest!.weakSlides, isEmpty);
    expect(
      generator.lastRequest!.taughtNotes,
      contains('feedforward'),
    );
  });

  testWidgets('AI practice shows notes-required state', (tester) async {
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
        id: 'session-empty-notes',
        courseId: 'CS-500',
        chapterId: 'ch-1',
        chapterTitle: 'Neural Nets',
        topicId: 't-1',
        topicTitle: 'Neural Networks',
        teacherId: 'teacher-1',
        durationMinutes: 40,
      ),
      courseName: 'AI',
      teacherName: 'Demo Teacher',
    );
    await store.endLiveSession('CS-500', started.id, 'teacher-1');
    final ended = started.copyWith(status: LiveSessionStatus.ended);

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
          home: AiPracticeScreen(
            session: ended,
            courseName: 'AI',
            studentId: 'student-1',
            studentName: 'Ayesha',
            generator: StubAiPracticeGenerator(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Lecture notes needed'), findsOneWidget);
    expect(find.text('SUBMIT QUIZ'), findsNothing);
  });
}
