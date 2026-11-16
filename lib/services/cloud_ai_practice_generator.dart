import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../models/ai_practice.dart';
import 'ai_practice_generator.dart';
import 'unsupported_ai_practice_generator.dart';
import 'windows_callable_client.dart';

/// Server-side quiz generation via callable Cloud Function.
/// API keys never ship in the Flutter client.
class CloudAiPracticeGenerator implements AiPracticeGenerator {
  CloudAiPracticeGenerator({FirebaseFunctions? functions})
    : _functions =
          functions ??
          (_useWindowsHttp
              ? null
              : FirebaseFunctions.instanceFor(region: 'us-central1'));

  final FirebaseFunctions? _functions;
  static bool get _useWindowsHttp =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;

  static const _callableName = 'generateAiPracticeQuiz';

  @override
  bool get isSupported => true;

  @override
  Future<void> ensureReady({AiDownloadProgress? onProgress}) async {
    onProgress?.call(1);
  }

  @override
  Future<AiQuiz> generateQuiz(AiQuizRequest request) async {
    final notes = request.taughtNotes.trim();
    if (notes.isEmpty) {
      throw const AiPracticeException(AiPracticeException.missingNotes);
    }

    try {
      final data = <String, dynamic>{
        'taughtNotes': notes,
        'chapterTitle': request.chapterTitle.trim(),
        'topicTitle': request.topicTitle.trim(),
        'courseName': request.courseName.trim(),
        'sourceKind': request.sourceKind.trim().isEmpty
            ? 'notes'
            : request.sourceKind.trim(),
        'weakSlides': [
          for (final slide in request.weakSlides)
            <String, dynamic>{
              'fileIndex': slide.fileIndex,
              'slidePage': slide.slidePage,
              'fileName': slide.fileName,
              'levelLabel': slide.levelLabel,
              'priority': slide.priority,
            },
        ],
      };
      final functions = _functions;
      final Object? result;
      if (functions == null) {
        result = await WindowsCallableClient(
          projectId: Firebase.app().options.projectId,
          idToken: () async => FirebaseAuth.instance.currentUser?.getIdToken(),
        ).call(_callableName, data);
      } else {
        result =
            (await functions
                    .httpsCallable(
                      _callableName,
                      options: HttpsCallableOptions(
                        timeout: const Duration(seconds: 120),
                      ),
                    )
                    .call(data))
                .data;
      }
      return parseCloudAiPracticeQuiz(result);
    } on AiPracticeException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      debugPrint(
        'Cloud AI practice failed: code=${error.code} message=${error.message}',
      );
      if (error.code == 'unauthenticated') {
        throw const AiPracticeException(
          AiPracticeException.generateFailed,
          'Sign in to generate a practice quiz.',
        );
      }
      if (error.code == 'invalid-argument') {
        throw const AiPracticeException(AiPracticeException.missingNotes);
      }
      if (error.code == 'failed-precondition' &&
          (error.details == 'no-below50' ||
              (error.message ?? '').toLowerCase().contains('below 50'))) {
        throw const AiPracticeException(AiPracticeException.noBelow50);
      }
      throw AiPracticeException(
        AiPracticeException.generateFailed,
        error.message ?? 'Could not generate a practice quiz.',
      );
    } catch (error, stackTrace) {
      debugPrint('Cloud AI practice failed: $error');
      debugPrint('$stackTrace');
      throw AiPracticeException(
        AiPracticeException.generateFailed,
        'Could not generate a practice quiz. $error',
      );
    }
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

/// Maps callable payload `{ quiz: [...] }` (or a raw list) into [AiQuiz].
/// Accepts `correctAnswer` as letter A-D or option text; UI uses [correctIndex].
AiQuiz parseCloudAiPracticeQuiz(Object? data) {
  Object? payload = data;
  if (data is Map) {
    final map = Map<String, dynamic>.from(data);
    payload = map['quiz'] ?? map['questions'] ?? map;
  }
  if (payload is List) {
    return parseAiQuiz(payload);
  }
  if (payload is String) {
    return parseAiQuiz(payload);
  }
  if (payload is Map) {
    return parseAiQuiz(Map<String, dynamic>.from(payload));
  }
  throw const AiPracticeException(
    AiPracticeException.malformed,
    'Quiz response was empty or invalid.',
  );
}
