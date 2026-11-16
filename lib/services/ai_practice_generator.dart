import '../models/ai_practice.dart';

typedef AiDownloadProgress = void Function(double progress);

/// A slide used as a quiz source.
///
/// Weak understanding (≤70%): below-50 → priority 3, 60% → priority 2.
/// All-slides stamp (no weak feedback) uses priority 0.
class WeakSlideFocus {
  const WeakSlideFocus({
    required this.fileIndex,
    required this.slidePage,
    required this.levelLabel,
    required this.priority,
    this.fileName = '',
  });

  final int fileIndex;
  final int slidePage;
  final String fileName;
  final String levelLabel;

  /// Below-50 = 3, 60% = 2. Practice focus ignores 80 / 100 (priority 0/1).
  final int priority;
}

/// Copies chapter, lecture, and a source slide onto every question.
///
/// Prefers a slide the model / Cloud Function named (file + page, then
/// [AiQuizQuestion.sourceIndex], then page-only). Otherwise picks a stable
/// non-sequential slide from [below50Slides] so the UI never shows fake
/// Slide 1/2/3 by question index. When the list is empty, keeps model fields.
AiQuiz stampBelow50QuizSources({
  required AiQuiz quiz,
  required String chapterTitle,
  required String lectureTitle,
  required List<WeakSlideFocus> below50Slides,
}) {
  final chapter = chapterTitle.trim();
  final lecture = lectureTitle.trim();
  final questions = <AiQuizQuestion>[];
  for (var i = 0; i < quiz.questions.length; i++) {
    final q = quiz.questions[i];
    if (below50Slides.isEmpty) {
      questions.add(
        q.withSource(
          chapterTitle: chapter,
          lectureTitle: lecture,
          slideFileName: q.slideFileName,
          slideFileIndex: q.slideFileIndex,
          slidePage: q.slidePage,
        ),
      );
      continue;
    }
    final slide = _slideForQuestion(q, below50Slides);
    questions.add(
      q.withSource(
        chapterTitle: chapter,
        lectureTitle: lecture,
        slideFileName: slide.fileName,
        slideFileIndex: slide.fileIndex,
        slidePage: slide.slidePage,
      ),
    );
  }
  return AiQuiz(questions: questions);
}

WeakSlideFocus _slideForQuestion(
  AiQuizQuestion question,
  List<WeakSlideFocus> slides,
) {
  if (slides.isEmpty) {
    return const WeakSlideFocus(
      fileIndex: 0,
      slidePage: 1,
      levelLabel: '',
      priority: 0,
    );
  }
  // Prefer the slide the model / Cloud Function named.
  if (question.slideFileIndex >= 0 && question.slidePage > 0) {
    for (final slide in slides) {
      if (slide.fileIndex == question.slideFileIndex &&
          slide.slidePage == question.slidePage) {
        return slide;
      }
    }
  }
  final source = question.sourceIndex;
  if (source >= 0 && source < slides.length) {
    return slides[source];
  }
  // Page-only match when file index was omitted.
  if (question.slidePage > 0) {
    final matches = [
      for (final slide in slides)
        if (slide.slidePage == question.slidePage) slide,
    ];
    if (matches.isNotEmpty) {
      return matches.first;
    }
  }
  // Stable non-sequential pick from real slides (never Q-index -> Slide N).
  final hash = question.prompt.hashCode.abs();
  return slides[hash % slides.length];
}

class AiQuizRequest {
  const AiQuizRequest({
    required this.taughtNotes,
    required this.topicTitle,
    this.chapterTitle = '',
    this.courseName = '',
    this.weakSlides = const [],
    this.sourceKind = 'notes',
  });

  /// Source material for the quiz (topic documents and/or legacy notes).
  final String taughtNotes;
  final String topicTitle;
  final String chapterTitle;
  final String courseName;
  final List<WeakSlideFocus> weakSlides;

  /// `documents` or `notes` — used only for prompt wording.
  final String sourceKind;
}

abstract class AiPracticeGenerator {
  bool get isSupported;

  Future<void> ensureReady({AiDownloadProgress? onProgress});

  Future<AiQuiz> generateQuiz(AiQuizRequest request);

  Future<String> generateDiagnostic({
    required AiQuizRequest request,
    required AiQuiz quiz,
    required List<int> selectedIndexes,
    required int score,
  });
}
