import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/ai_practice.dart';
import 'ai_model_prefetch.dart';
import 'ai_practice_generator.dart';
import 'unsupported_ai_practice_generator.dart';

/// MediaPipe Qwen 2.5 0.5B: tiny KV cache + sessions must not overlap.
const _maxNotesChars = 900;
const _maxModelTokens = 768;

AiPracticeGenerator createPlatformAiPracticeGenerator() =>
    GemmaAiPracticeGenerator();

class GemmaAiPracticeGenerator implements AiPracticeGenerator {
  InferenceModel? _model;

  @override
  bool get isSupported => !kIsWeb;

  @override
  Future<void> ensureReady({AiDownloadProgress? onProgress}) {
    return AiModelPrefetch.instance.ensureReady(onProgress: onProgress);
  }

  Future<InferenceModel> _activeModel() async {
    final existing = _model;
    if (existing != null) {
      return existing;
    }
    try {
      final loaded = await FlutterGemma.getActiveModel(
        maxTokens: _maxModelTokens,
        preferredBackend: PreferredBackend.cpu,
        maxConcurrentSessions: 1,
      );
      _model = loaded;
      return loaded;
    } catch (error) {
      debugPrint('CPU model load failed, trying GPU: $error');
      final loaded = await FlutterGemma.getActiveModel(
        maxTokens: _maxModelTokens,
        preferredBackend: PreferredBackend.gpu,
        maxConcurrentSessions: 1,
      );
      _model = loaded;
      return loaded;
    }
  }

  Future<void> _resetModel() async {
    final existing = _model;
    _model = null;
    if (existing == null) {
      return;
    }
    try {
      await existing.close();
    } catch (error) {
      debugPrint('Model close after failure: $error');
    }
  }

  String _clipNotes(String notes) {
    final trimmed = notes.trim();
    if (trimmed.length <= _maxNotesChars) {
      return trimmed;
    }
    return '${trimmed.substring(0, _maxNotesChars)}…';
  }

  @override
  Future<AiQuiz> generateQuiz(AiQuizRequest request) async {
    final notes = request.taughtNotes.trim();
    if (notes.isEmpty) {
      throw const AiPracticeException(AiPracticeException.missingNotes);
    }
    await ensureReady();
    try {
      return await _generateQuizOneByOne(request, notes);
    } on AiPracticeException {
      rethrow;
    } catch (error, stackTrace) {
      debugPrint('Gemma quiz generation failed: $error');
      debugPrint('$stackTrace');
      await _resetModel();
      throw AiPracticeException(
        AiPracticeException.generateFailed,
        'Could not generate a quiz from the lecture notes. $error',
      );
    }
  }

  Future<AiQuiz> _generateQuizOneByOne(
    AiQuizRequest request,
    String notes,
  ) async {
    final clipped = _clipNotes(notes);
    final collected = <AiQuizQuestion>[];
    final avoid = <String>[];

    for (var i = 0; i < kAiPracticeQuestionCount; i++) {
      final question = await _generateSingleQuestion(
        notes: clipped,
        topicTitle: request.topicTitle,
        index: i + 1,
        avoidPrompts: avoid,
      );
      collected.add(question);
      avoid.add(question.prompt);
      // Let MediaPipe fully settle before opening the next session.
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }

    return AiQuiz(questions: collected);
  }

  Future<AiQuizQuestion> _generateSingleQuestion({
    required String notes,
    required String topicTitle,
    required int index,
    required List<String> avoidPrompts,
  }) async {
    final model = await _activeModel();
    final chat = await model.createChat(
      temperature: 0.2,
      topK: 10,
      systemInstruction:
          'You write one multiple-choice question for university students. '
          'Use ONLY the teacher lecture notes. Do not invent facts that are not in the notes. '
          'Do not rely on the topic title alone. '
          'Reply with ONLY one JSON object. No markdown. No extra keys. '
          'Format: {"question":"...","options":["A","B","C","D"],"correctIndex":0,'
          '"explanation":"one short sentence grounded in the notes"}. correctIndex is 0-3. '
          'Options must be plain text without A)/B) prefixes. Stop after the JSON.',
    );

    final prompt = StringBuffer()
      ..writeln('Teacher lecture notes (source of truth for this question):')
      ..writeln(notes)
      ..writeln()
      ..writeln(
        'Write MCQ #$index only as JSON about something explicitly covered in those notes.',
      );
    if (topicTitle.trim().isNotEmpty) {
      prompt.writeln(
        'Lecture topic label (context only; do not replace the notes): ${topicTitle.trim()}',
      );
    }
    if (avoidPrompts.isNotEmpty) {
      prompt.writeln('Do not repeat: ${avoidPrompts.join(' | ')}');
    }

    await chat.addQueryChunk(
      Message.text(text: prompt.toString(), isUser: true),
    );

    final buffer = StringBuffer();
    try {
      // IMPORTANT: drain the full stream before closing the session.
      // Early return + close while MediaPipe is still decoding causes
      // "Previous invocation still processing" and native SIGSEGV.
      await for (final response in chat.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }
    } catch (error, stackTrace) {
      debugPrint('Single MCQ stream failed: $error');
      debugPrint('$stackTrace');
      final salvaged = salvageAiQuizQuestions(buffer.toString());
      if (salvaged.isNotEmpty) {
        return salvaged.first;
      }
      await _safeCloseChat(chat);
      await _resetModel();
      rethrow;
    }

    await _safeCloseChat(chat);

    final salvaged = salvageAiQuizQuestions(buffer.toString());
    if (salvaged.isNotEmpty) {
      return salvaged.first;
    }
    debugPrint('Single MCQ raw output: ${buffer.toString()}');
    throw const AiPracticeException(
      AiPracticeException.malformed,
      'The on-device model did not return a valid question.',
    );
  }

  Future<void> _safeCloseChat(InferenceChat chat) async {
    try {
      await chat.close();
    } catch (error) {
      debugPrint('Chat close: $error');
      // Give native side time if close raced with decode.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      try {
        await chat.close();
      } catch (error2) {
        debugPrint('Chat close retry: $error2');
      }
    }
  }

  @override
  Future<String> generateDiagnostic({
    required AiQuizRequest request,
    required AiQuiz quiz,
    required List<int> selectedIndexes,
    required int score,
  }) async {
    final fallback = fallbackDiagnostic(
      quiz: quiz,
      selectedIndexes: selectedIndexes,
      score: score,
    );
    try {
      final model = await _activeModel();
      final chat = await model.createChat(
        temperature: 0.4,
        topK: 20,
        systemInstruction:
            'Write 2 short sentences of study guidance grounded in the lecture notes '
            'and missed questions. No JSON.',
      );
      final missed = <String>[];
      for (var i = 0; i < quiz.questions.length; i++) {
        if (i >= selectedIndexes.length ||
            selectedIndexes[i] != quiz.questions[i].correctIndex) {
          missed.add(quiz.questions[i].prompt);
        }
      }
      await chat.addQueryChunk(
        Message.text(
          text:
              'Lecture notes:\n${_clipNotes(request.taughtNotes)}\n\n'
              'Score $score/${quiz.length}. Missed: ${missed.take(3).join('; ')}. '
              'Give brief guidance grounded in the notes.',
          isUser: true,
        ),
      );
      final buffer = StringBuffer();
      try {
        await for (final response in chat.generateChatResponseAsync()) {
          if (response is TextResponse) {
            buffer.write(response.token);
          }
        }
      } finally {
        await _safeCloseChat(chat);
      }
      final text = buffer.toString().trim();
      if (text.isNotEmpty) {
        return text;
      }
    } catch (error) {
      debugPrint('Gemma diagnostic failed: $error');
      await _resetModel();
    }
    return fallback;
  }
}