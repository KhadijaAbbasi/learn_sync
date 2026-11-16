import '../models/ai_practice.dart';
import 'ai_practice_generator.dart';
import 'unsupported_ai_practice_generator.dart';

class StubAiPracticeGenerator implements AiPracticeGenerator {
  StubAiPracticeGenerator({this.readyDelay = Duration.zero});

  final Duration readyDelay;
  var ensureReadyCalls = 0;
  var generateCalls = 0;
  AiQuizRequest? lastRequest;

  @override
  bool get isSupported => true;

  @override
  Future<void> ensureReady({AiDownloadProgress? onProgress}) async {
    ensureReadyCalls++;
    if (readyDelay > Duration.zero) {
      await Future<void>.delayed(readyDelay);
    }
    onProgress?.call(1);
  }

  @override
  Future<AiQuiz> generateQuiz(AiQuizRequest request) async {
    generateCalls++;
    lastRequest = request;
    final notes = request.taughtNotes.trim();
    if (notes.isEmpty) {
      throw const AiPracticeException(AiPracticeException.missingNotes);
    }
    final snippet = notes.length > 42 ? notes.substring(0, 42) : notes;
    return AiQuiz(
      questions: [
        for (var i = 0; i < kAiPracticeQuestionCount; i++)
          AiQuizQuestion(
            prompt:
                'From today\'s notes ($snippet…), which statement is accurate for item ${i + 1}?',
            options: [
              'It matches what was taught: $snippet',
              'It is unrelated to this lecture',
              'It contradicts the teacher notes',
            ],
            correctIndex: 0,
            explanation: 'The quiz is grounded in the teacher notes: $snippet',
          ),
      ],
    );
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
