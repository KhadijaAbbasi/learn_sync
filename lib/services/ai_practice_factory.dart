import 'ai_practice_generator.dart';
import 'cloud_ai_practice_generator.dart';

/// Production path: Cloud Function `generateAiPracticeQuiz` (Gemini on the
/// client Firebase project). API keys never ship in the Flutter app.
AiPracticeGenerator createAiPracticeGenerator() => CloudAiPracticeGenerator();
