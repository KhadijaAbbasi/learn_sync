import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

import '../models/ai_practice.dart';
import 'ai_practice_generator.dart';
import 'cloud_ai_practice_generator.dart';
import 'unsupported_ai_practice_generator.dart';

/// Direct client-side quiz generation via project-root `.env` `API_KEY`.
/// Provider is detected from key prefix only; the key is never logged.
class HttpAiPracticeGenerator implements AiPracticeGenerator {
  HttpAiPracticeGenerator({http.Client? client})
    : _client = client ?? http.Client();

  final http.Client _client;

  static const _notesMaxChars = 12000;
  static const _systemPrompt =
      'You output ONLY valid JSON arrays for MCQ quizzes. No markdown. No prose.';

  static const _diagnosticSystemPrompt =
      'You are a supportive AI study tutor for university students. '
      'Give constructive, encouraging feedback only. '
      'Never degrade, shame, insult, or belittle the student. '
      'Do not call them weak, dumb, lazy, or a failure. '
      'Be kind, respectful, and growth-focused. '
      'Write plain text only: exactly 3 or 4 short sentences. '
      'No markdown, no bullet lists, no JSON, no titles.';

  @override
  bool get isSupported => true;

  @override
  Future<void> ensureReady({AiDownloadProgress? onProgress}) async {
    onProgress?.call(1);
  }

  @override
  Future<AiQuiz> generateQuiz(AiQuizRequest request) async {
    final notes = request.taughtNotes.trim();
    final topic = request.topicTitle.trim();
    if (topic.isEmpty || notes.isEmpty) {
      throw AiPracticeException(
        AiPracticeException.missingNotes,
        topic.isEmpty
            ? 'Topic name is missing from the quiz payload.'
            : 'Lecture notes are missing from the quiz payload.',
      );
    }

    final apiKey = _readApiKey();
    final provider = _detectProvider(apiKey);
    debugPrint('AI practice HTTP provider=$provider (fresh call, no cache)');

    final prompt = _buildQuizPrompt(request: request);

    try {
      final raw = await _generateFromProvider(
        apiKey: apiKey,
        provider: provider,
        prompt: prompt,
      );
      final jsonText = _extractJsonText(raw);
      if (jsonText.isEmpty) {
        throw const AiPracticeException(
          AiPracticeException.malformed,
          'Quiz response was empty or invalid.',
        );
      }
      final decoded = jsonDecode(jsonText);
      return parseCloudAiPracticeQuiz(decoded);
    } on AiPracticeException {
      rethrow;
    } on FormatException catch (error) {
      debugPrint('AI practice JSON parse failed: $error');
      throw const AiPracticeException(
        AiPracticeException.malformed,
        'Could not parse quiz JSON.',
      );
    } catch (error, stackTrace) {
      debugPrint('AI practice HTTP failed: $error');
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
    final fallback = fallbackDiagnostic(
      quiz: quiz,
      selectedIndexes: selectedIndexes,
      score: score,
    );
    try {
      final apiKey = _readApiKey();
      final provider = _detectProvider(apiKey);
      final prompt = _buildDiagnosticPrompt(
        request: request,
        quiz: quiz,
        selectedIndexes: selectedIndexes,
        score: score,
      );
      debugPrint('AI practice diagnostic provider=$provider');
      final raw = await _generateFromProvider(
        apiKey: apiKey,
        provider: provider,
        prompt: prompt,
        systemPrompt: _diagnosticSystemPrompt,
        temperature: 0.4,
      );
      final text = raw.trim();
      if (text.isEmpty) {
        return fallback;
      }
      return text;
    } catch (error, stackTrace) {
      debugPrint('AI practice diagnostic failed: $error');
      debugPrint('$stackTrace');
      return fallback;
    }
  }

  String _buildDiagnosticPrompt({
    required AiQuizRequest request,
    required AiQuiz quiz,
    required List<int> selectedIndexes,
    required int score,
  }) {
    final missed = <String>[];
    final correct = <String>[];
    for (var i = 0; i < quiz.questions.length; i++) {
      final q = quiz.questions[i];
      final picked = i < selectedIndexes.length ? selectedIndexes[i] : -1;
      if (picked == q.correctIndex) {
        correct.add(q.prompt);
      } else {
        missed.add(q.prompt);
      }
    }
    final topic = request.topicTitle.trim().isEmpty
        ? '(unspecified)'
        : request.topicTitle.trim();
    final course = request.courseName.trim().isEmpty
        ? '(unspecified)'
        : request.courseName.trim();
    return 'Student quiz result for AI practice.\n'
        'Course: $course\n'
        'Topic: $topic\n'
        'Score: $score out of ${quiz.length}\n'
        'Correct questions: ${correct.isEmpty ? '(none)' : correct.take(3).join('; ')}\n'
        'Missed questions: ${missed.isEmpty ? '(none)' : missed.take(3).join('; ')}\n\n'
        'Teacher lecture notes (for grounding only):\n'
        '${_clipNotes(request.taughtNotes)}\n\n'
        'Write encouraging diagnostic evaluation and guidance in 3 or 4 short sentences. '
        'Praise effort, name 1-2 ideas to review from the notes if anything was missed, '
        'and suggest a gentle next step. Do not degrade the student.';
  }

  String _readApiKey() {
    final key = (dotenv.env['API_KEY'] ?? '').trim();
    if (key.isEmpty || key == 'your_api_key_here') {
      throw const AiPracticeException(
        AiPracticeException.generateFailed,
        'Quiz generation is not configured. Set API_KEY in project-root .env.',
      );
    }
    return key;
  }

  /// Detect provider from key prefix without logging the key.
  String _detectProvider(String apiKey) {
    if (apiKey.startsWith('gsk_')) {
      return 'groq';
    }
    if (apiKey.startsWith('AIza')) {
      return 'google';
    }
    if (apiKey.startsWith('xai-')) {
      return 'xai';
    }
    return 'openai';
  }

  String _clipNotes(String notes) {
    final trimmed = notes.trim();
    if (trimmed.length <= _notesMaxChars) {
      return trimmed;
    }
    return '${trimmed.substring(0, _notesMaxChars)}...';
  }

  String _buildQuizPrompt({required AiQuizRequest request}) {
    final chapter = request.chapterTitle.trim().isEmpty
        ? '(unspecified)'
        : request.chapterTitle.trim();
    final topic = request.topicTitle.trim().isEmpty
        ? '(unspecified)'
        : request.topicTitle.trim();
    final course = request.courseName.trim().isEmpty
        ? '(unspecified)'
        : request.courseName.trim();
    final sourceLabel = request.sourceKind == 'documents'
        ? 'Teacher lecture documents / slides (source of truth)'
        : 'Teacher lecture notes (source of truth)';
    final focusLines = <String>[];
    final sorted = [...request.weakSlides]
      ..sort((a, b) => b.priority.compareTo(a.priority));
    for (final slide in sorted) {
      focusLines.add(
        '- File ${slide.fileIndex + 1} Slide ${slide.slidePage}: '
        '${slide.levelLabel} (priority ${slide.priority})',
      );
    }
    final focusBlock = focusLines.isEmpty
        ? 'No slides were marked ≤70% (60% or below 50%). Write a general practice quiz from '
              'the FULL lecture source (all slides / notes). Cover the main ideas '
              'across the lecture. When the source labels slides, set fileIndex and '
              'slidePage on each question to the best matching slide.\n'
        : 'The student marked these slides as weak (60% need recap or Below 50% need help). '
              'Every one of the $kAiPracticeQuestionCount questions MUST be '
              'about these slides and no others:\n'
              '${focusLines.join('\n')}\n';
    return 'You are generating a practice quiz for university students.\n'
        'Use ONLY the source material below. Do not invent facts missing from it.\n'
        'Course: $course\n'
        'Chapter: $chapter\n'
        'Topic: $topic\n\n'
        '$sourceLabel:\n'
        '${_clipNotes(request.taughtNotes)}\n\n'
        '$focusBlock\n'
        'Return ONLY a JSON array of exactly $kAiPracticeQuestionCount objects. '
        'No markdown fences. No commentary.\n'
        'Each object MUST have this exact shape:\n'
        '{"question":"...","options":["A text","B text","C text"],"correctAnswer":"A","reason":"..."}\n'
        'Rules:\n'
        '- Exactly $kAiPracticeQuestionCount MCQs, ordered easy to difficult.\n'
        '- Exactly $kAiPracticeOptionCount option strings (A, B, C); plain text without A)/B)/C) prefixes.\n'
        '- correctAnswer MUST be one letter A, B, or C matching the correct option.\n'
        '- reason MUST be one short line explaining why that answer is correct.\n'
        '- Strictly from the provided source material only; questions must be distinct.\n'
        '- When below-50 slides are listed, every question must target only those slides.\n'
        '- When no below-50 slides are listed, use the full lecture source (general quiz).\n'
        '- Output language: infer from the source; default to English if unclear.\n';
  }

  Future<String> _generateFromProvider({
    required String apiKey,
    required String provider,
    required String prompt,
    String systemPrompt = _systemPrompt,
    double temperature = 0.2,
  }) async {
    switch (provider) {
      case 'google':
        return _callGoogleGenerative(
          apiKey: apiKey,
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
        );
      case 'groq':
        return _callOpenAiCompatible(
          apiKey: apiKey,
          baseUrl: 'https://api.groq.com/openai/v1',
          model: 'llama-3.3-70b-versatile',
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
        );
      case 'xai':
        return _callOpenAiCompatible(
          apiKey: apiKey,
          baseUrl: 'https://api.x.ai/v1',
          model: 'grok-2-latest',
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
        );
      default:
        return _callOpenAiCompatible(
          apiKey: apiKey,
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
          prompt: prompt,
          systemPrompt: systemPrompt,
          temperature: temperature,
        );
    }
  }

  Future<String> _callOpenAiCompatible({
    required String apiKey,
    required String baseUrl,
    required String model,
    required String prompt,
    String systemPrompt = _systemPrompt,
    double temperature = 0.2,
  }) async {
    final uri = Uri.parse('$baseUrl/chat/completions');
    final response = await _client
        .post(
          uri,
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'model': model,
            'temperature': temperature,
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': prompt},
            ],
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = 'Upstream quiz API failed: status=${response.statusCode}';
      debugPrint(detail);
      final body = response.body.trim();
      final snippet = body.length > 280 ? '${body.substring(0, 280)}...' : body;
      throw AiPracticeException(
        AiPracticeException.generateFailed,
        snippet.isEmpty ? detail : '$detail\n$snippet',
      );
    }

    late final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiPracticeException(
        AiPracticeException.generateFailed,
        'Quiz provider returned non-JSON.',
      );
    }

    final choices = parsed['choices'];
    if (choices is! List || choices.isEmpty) {
      return '';
    }
    final first = choices.first;
    if (first is! Map) {
      return '';
    }
    final message = first['message'];
    if (message is! Map) {
      return '';
    }
    return (message['content'] ?? '').toString();
  }

  Future<String> _callGoogleGenerative({
    required String apiKey,
    required String prompt,
    String systemPrompt = _systemPrompt,
    double temperature = 0.2,
  }) async {
    const model = 'gemini-2.0-flash';
    final uri = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/'
      '$model:generateContent?key=${Uri.encodeQueryComponent(apiKey)}',
    );
    final mergedPrompt = '$systemPrompt\n\n$prompt';
    final response = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': mergedPrompt},
                ],
              },
            ],
            'generationConfig': {'temperature': temperature},
          }),
        )
        .timeout(const Duration(seconds: 120));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      final detail = 'Upstream quiz API failed: status=${response.statusCode}';
      debugPrint(detail);
      final body = response.body.trim();
      final snippet = body.length > 280 ? '${body.substring(0, 280)}...' : body;
      throw AiPracticeException(
        AiPracticeException.generateFailed,
        snippet.isEmpty ? detail : '$detail\n$snippet',
      );
    }

    late final Map<String, dynamic> parsed;
    try {
      parsed = jsonDecode(response.body) as Map<String, dynamic>;
    } catch (_) {
      throw const AiPracticeException(
        AiPracticeException.generateFailed,
        'Quiz provider returned non-JSON.',
      );
    }

    final candidates = parsed['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      return '';
    }
    final first = candidates.first;
    if (first is! Map) {
      return '';
    }
    final content = first['content'];
    if (content is! Map) {
      return '';
    }
    final parts = content['parts'];
    if (parts is! List) {
      return '';
    }
    final buffer = StringBuffer();
    for (final part in parts) {
      if (part is Map && part['text'] != null) {
        buffer.write(part['text']);
      }
    }
    return buffer.toString();
  }

  String _extractJsonText(String raw) {
    final text = raw.trim();
    if (text.isEmpty) {
      return '';
    }
    final fence = RegExp(
      r'```(?:json)?\s*([\s\S]*?)```',
      caseSensitive: false,
    ).firstMatch(text);
    if (fence != null) {
      final inner = fence.group(1)?.trim();
      if (inner != null && inner.isNotEmpty) {
        return inner;
      }
    }
    final startArr = text.indexOf('[');
    final startObj = text.indexOf('{');
    var begin = -1;
    var endChar = ']';
    if (startArr >= 0 && (startObj < 0 || startArr < startObj)) {
      begin = startArr;
      endChar = ']';
    } else if (startObj >= 0) {
      begin = startObj;
      endChar = '}';
    }
    if (begin < 0) {
      return text;
    }
    final end = text.lastIndexOf(endChar);
    if (end <= begin) {
      return text;
    }
    return text.substring(begin, end + 1);
  }
}
