import '../models/ai_practice.dart';
import 'ai_practice_generator.dart';

class UnsupportedAiPracticeGenerator implements AiPracticeGenerator {
  const UnsupportedAiPracticeGenerator();

  @override
  bool get isSupported => false;

  @override
  Future<void> ensureReady({AiDownloadProgress? onProgress}) async {
    throw const AiPracticeException(
      AiPracticeException.unsupported,
      'On-device AI practice is not available on this platform.',
    );
  }

  @override
  Future<AiQuiz> generateQuiz(AiQuizRequest request) {
    return ensureReady().then((_) => const AiQuiz(questions: []));
  }

  @override
  Future<String> generateDiagnostic({
    required AiQuizRequest request,
    required AiQuiz quiz,
    required List<int> selectedIndexes,
    required int score,
  }) async {
    return fallbackDiagnostic(
      quiz: quiz,
      selectedIndexes: selectedIndexes,
      score: score,
    );
  }
}

AiPracticeGenerator createPlatformAiPracticeGenerator() =>
    const UnsupportedAiPracticeGenerator();

String fallbackDiagnostic({
  required AiQuiz quiz,
  required List<int> selectedIndexes,
  required int score,
}) {
  final wrong = <String>[];
  for (var i = 0; i < quiz.questions.length; i++) {
    if (i >= selectedIndexes.length ||
        selectedIndexes[i] != quiz.questions[i].correctIndex) {
      wrong.add(quiz.questions[i].prompt);
    }
  }
  if (wrong.isEmpty) {
    return 'Strong grasp of the lecture notes. You answered every question '
        'correctly — keep using these ideas in the next class.';
  }
  final focus = wrong.take(2).join(' ');
  return 'You scored $score of ${quiz.questions.length}. Review: $focus '
      'Re-read the teacher notes on those points and try the quiz again.';
}
