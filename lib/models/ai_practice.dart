import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';

const kAiPracticeQuestionCount = 5;
const kAiPracticeOptionCount = 3;
const kAiPracticePassPercent = 60;

class AiPracticeException implements Exception {
  const AiPracticeException(this.code, [this.message = '']);

  final String code;
  final String message;

  static const missingNotes = 'missingNotes';
  static const unsupported = 'unsupported';
  static const downloadFailed = 'downloadFailed';
  static const generateFailed = 'generateFailed';
  static const malformed = 'malformed';

  /// The student has no slides marked below 50%, so there is no quiz to write.
  static const noBelow50 = 'noBelow50';

  @override
  String toString() => message.isEmpty ? 'AiPracticeException($code)' : message;
}

class AiQuizQuestion {
  const AiQuizQuestion({
    required this.prompt,
    required this.options,
    required this.correctIndex,
    this.explanation = '',
    this.chapterTitle = '',
    this.lectureTitle = '',
    this.slideFileName = '',
    this.slideFileIndex = -1,
    this.slidePage = 0,
    this.sourceIndex = -1,
  });

  final String prompt;
  final List<String> options;
  final int correctIndex;
  final String explanation;

  /// Chapter this question was written from.
  final String chapterTitle;

  /// Lecture / topic this question was written from.
  final String lectureTitle;

  /// Attachment name when the app knows it; otherwise empty.
  final String slideFileName;

  /// 0-based file index in the topic attachments. -1 when unknown.
  final int slideFileIndex;

  /// 1-based slide or page number. 0 when unknown.
  final int slidePage;

  /// Index into the below-50 slide list sent to the generator. -1 when unset.
  final int sourceIndex;

  /// File name plus slide page, or "File N, slide P" when the name is unknown.
  String get slideIdentity {
    final name = slideFileName.trim();
    final page = slidePage > 0 ? 'slide $slidePage' : '';
    if (name.isNotEmpty && page.isNotEmpty) {
      return '$name, $page';
    }
    if (name.isNotEmpty) {
      return name;
    }
    if (slideFileIndex >= 0 && page.isNotEmpty) {
      return 'File ${slideFileIndex + 1}, $page';
    }
    return page;
  }

  bool get hasSource =>
      chapterTitle.trim().isNotEmpty ||
      lectureTitle.trim().isNotEmpty ||
      slideIdentity.isNotEmpty;

  AiQuizQuestion copyWithoutAnswer() {
    return AiQuizQuestion(
      prompt: prompt,
      options: options,
      correctIndex: -1,
      chapterTitle: chapterTitle,
      lectureTitle: lectureTitle,
      slideFileName: slideFileName,
      slideFileIndex: slideFileIndex,
      slidePage: slidePage,
      sourceIndex: sourceIndex,
    );
  }

  AiQuizQuestion withSource({
    required String chapterTitle,
    required String lectureTitle,
    required String slideFileName,
    required int slideFileIndex,
    required int slidePage,
  }) {
    return AiQuizQuestion(
      prompt: prompt,
      options: options,
      correctIndex: correctIndex,
      explanation: explanation,
      chapterTitle: chapterTitle,
      lectureTitle: lectureTitle,
      slideFileName: slideFileName,
      slideFileIndex: slideFileIndex,
      slidePage: slidePage,
      sourceIndex: sourceIndex,
    );
  }

  Map<String, dynamic> toStudentMap() {
    return {
      'prompt': prompt,
      'options': options,
      'chapterTitle': chapterTitle,
      'lectureTitle': lectureTitle,
      'slideFileName': slideFileName,
      'slideFileIndex': slideFileIndex,
      'slidePage': slidePage,
    };
  }

  Map<String, dynamic> toFullMap() {
    return {
      'prompt': prompt,
      'options': options,
      'correctIndex': correctIndex,
      'explanation': explanation,
      'chapterTitle': chapterTitle,
      'lectureTitle': lectureTitle,
      'slideFileName': slideFileName,
      'slideFileIndex': slideFileIndex,
      'slidePage': slidePage,
      'sourceIndex': sourceIndex,
    };
  }

  factory AiQuizQuestion.fromMap(Map<String, dynamic> data) {
    final options = <String>[
      for (final item in (data['options'] as List? ?? const []))
        if (item is String) item.trim(),
    ];
    final source = _sourceFromMap(data);
    return AiQuizQuestion(
      prompt: (data['prompt'] as String? ?? data['question'] as String? ?? '')
          .trim(),
      options: options,
      correctIndex: (data['correctIndex'] as num?)?.toInt() ?? -1,
      explanation:
          (data['explanation'] as String? ?? data['reason'] as String? ?? '')
              .trim(),
      chapterTitle: source.chapterTitle,
      lectureTitle: source.lectureTitle,
      slideFileName: source.slideFileName,
      slideFileIndex: source.slideFileIndex,
      slidePage: source.slidePage,
      sourceIndex: source.sourceIndex,
    );
  }
}

class AiQuiz {
  const AiQuiz({required this.questions});

  final List<AiQuizQuestion> questions;

  int get length => questions.length;

  AiQuiz scoredView() => this;

  List<AiQuizQuestion> get studentFacingQuestions {
    return [for (final question in questions) question.copyWithoutAnswer()];
  }
}

class AiPracticeAttempt {
  const AiPracticeAttempt({
    required this.id,
    required this.lectureId,
    required this.courseId,
    required this.studentId,
    required this.studentName,
    required this.topicTitle,
    required this.score,
    required this.total,
    required this.selectedIndexes,
    this.teacherId = '',
    this.chapterTitle = '',
    this.courseName = '',
    this.diagnostic = '',
    this.questions = const [],
    this.completed = true,
    this.createdAt,
    this.completedAt,
  });

  final String id;
  final String lectureId;
  final String courseId;
  final String courseName;
  final String teacherId;
  final String studentId;
  final String studentName;
  final String topicTitle;
  final String chapterTitle;
  final int score;
  final int total;
  final List<int> selectedIndexes;
  final String diagnostic;
  final List<AiQuizQuestion> questions;
  final bool completed;
  final DateTime? createdAt;
  final DateTime? completedAt;

  int get percent => total == 0 ? 0 : ((score / total) * 100).round();

  bool get passed => percent >= kAiPracticePassPercent;

  int get wrongCount => (total - score).clamp(0, total);

  factory AiPracticeAttempt.fromMap(String id, Map<String, dynamic> data) {
    return AiPracticeAttempt(
      id: id,
      lectureId: data['lectureId'] as String? ?? '',
      courseId: data['courseId'] as String? ?? '',
      courseName: data['courseName'] as String? ?? '',
      teacherId: data['teacherId'] as String? ?? '',
      studentId: data['studentId'] as String? ?? '',
      studentName: data['studentName'] as String? ?? '',
      topicTitle: data['topicTitle'] as String? ?? '',
      chapterTitle: data['chapterTitle'] as String? ?? '',
      score: (data['score'] as num?)?.toInt() ?? 0,
      total: (data['total'] as num?)?.toInt() ?? kAiPracticeQuestionCount,
      selectedIndexes: [
        for (final item in (data['selectedIndexes'] as List? ?? const []))
          if (item is num) item.toInt(),
      ],
      diagnostic: data['diagnostic'] as String? ?? '',
      questions: [
        for (final item in (data['questions'] as List? ?? const []))
          if (item is Map)
            AiQuizQuestion.fromMap(Map<String, dynamic>.from(item)),
      ],
      completed: data['completed'] as bool? ?? true,
      createdAt: _dateFrom(data['createdAt']),
      completedAt: _dateFrom(data['completedAt']),
    );
  }

  Map<String, dynamic> toCreateMap() {
    return {
      'lectureId': lectureId,
      'courseId': courseId,
      'courseName': courseName.trim(),
      'teacherId': teacherId,
      'studentId': studentId,
      'studentName': studentName.trim(),
      'topicTitle': topicTitle.trim(),
      'chapterTitle': chapterTitle.trim(),
      'score': score,
      'total': total,
      'percent': percent,
      'passed': passed,
      'completed': true,
      'selectedIndexes': selectedIndexes,
      'diagnostic': diagnostic.trim(),
      'questions': [for (final question in questions) question.toFullMap()],
    };
  }
}

int scoreQuiz(AiQuiz quiz, List<int> selectedIndexes) {
  var score = 0;
  for (var i = 0; i < quiz.questions.length; i++) {
    if (i < selectedIndexes.length &&
        selectedIndexes[i] == quiz.questions[i].correctIndex) {
      score++;
    }
  }
  return score;
}

List<AiQuizQuestion> salvageAiQuizQuestions(String raw) {
  final questions = <AiQuizQuestion>[];
  final seen = <String>{};
  for (final map in _extractQuestionMaps(raw)) {
    final question = _questionFromMap(map);
    if (question == null) {
      continue;
    }
    final key = question.prompt.toLowerCase();
    if (!seen.add(key)) {
      continue;
    }
    questions.add(question);
    if (questions.length >= kAiPracticeQuestionCount) {
      break;
    }
  }
  return questions;
}

List<Map<String, dynamic>> _extractQuestionMaps(String raw) {
  final maps = <Map<String, dynamic>>[];
  final text = raw;
  var i = 0;
  while (i < text.length) {
    final start = text.indexOf('{', i);
    if (start < 0) {
      break;
    }
    var depth = 0;
    var end = -1;
    for (var j = start; j < text.length; j++) {
      final ch = text[j];
      if (ch == '{') {
        depth++;
      } else if (ch == '}') {
        depth--;
        if (depth == 0) {
          end = j;
          break;
        }
      }
    }
    if (end < 0) {
      break;
    }
    final slice = text.substring(start, end + 1);
    i = end + 1;
    try {
      final decoded = jsonDecode(slice);
      if (decoded is Map) {
        final map = Map<String, dynamic>.from(decoded);
        if (map.containsKey('question') || map.containsKey('prompt')) {
          maps.add(map);
        } else if (map['questions'] is List) {
          for (final item in map['questions'] as List) {
            if (item is Map) {
              maps.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }
    } catch (_) {
      // Skip non-JSON braces.
    }
  }
  return maps;
}

int? resolveCorrectIndex(Map<String, dynamic> map, List<String> options) {
  final asNum =
      (map['correctIndex'] as num?)?.toInt() ??
      (map['answer'] is num ? (map['answer'] as num).toInt() : null) ??
      (map['correct'] is num ? (map['correct'] as num).toInt() : null);
  if (asNum != null && asNum >= 0 && asNum < kAiPracticeOptionCount) {
    return asNum;
  }

  final raw = map['correctAnswer'] ?? map['answer'] ?? map['correct'];
  if (raw == null) {
    return null;
  }
  final text = raw.toString().trim();
  if (text.isEmpty) {
    return null;
  }
  if (text.length == 1) {
    final code = text.toUpperCase().codeUnitAt(0) - 65;
    if (code >= 0 && code < kAiPracticeOptionCount) {
      return code;
    }
  }
  final prefixed = RegExp(r'^([A-Ca-c])(?:[).:\-\s]|$)').firstMatch(text);
  if (prefixed != null) {
    final code = prefixed.group(1)!.toUpperCase().codeUnitAt(0) - 65;
    if (code >= 0 && code < kAiPracticeOptionCount) {
      return code;
    }
  }
  final lower = text.toLowerCase();
  for (var i = 0; i < options.length && i < kAiPracticeOptionCount; i++) {
    if (options[i].trim().toLowerCase() == lower) {
      return i;
    }
  }
  return null;
}

class _QuestionSource {
  const _QuestionSource({
    this.chapterTitle = '',
    this.lectureTitle = '',
    this.slideFileName = '',
    this.slideFileIndex = -1,
    this.slidePage = 0,
    this.sourceIndex = -1,
  });

  final String chapterTitle;
  final String lectureTitle;
  final String slideFileName;
  final int slideFileIndex;
  final int slidePage;
  final int sourceIndex;
}

_QuestionSource _sourceFromMap(Map<String, dynamic> map) {
  final fileIndex = map['slideFileIndex'] ?? map['fileIndex'];
  return _QuestionSource(
    chapterTitle: (map['chapterTitle'] as String? ?? '').trim(),
    lectureTitle: (map['lectureTitle'] as String? ?? '').trim(),
    slideFileName:
        (map['slideFileName'] as String? ?? map['fileName'] as String? ?? '')
            .trim(),
    slideFileIndex: fileIndex is num ? fileIndex.toInt() : -1,
    slidePage: (map['slidePage'] as num?)?.toInt() ?? 0,
    sourceIndex: (map['sourceIndex'] as num?)?.toInt() ?? -1,
  );
}

AiQuizQuestion? _questionFromMap(Map<String, dynamic> map) {
  final options = <String>[
    for (final option in (map['options'] as List? ?? const []))
      option.toString().trim(),
  ];
  while (options.length < kAiPracticeOptionCount) {
    options.add('');
  }
  if (options.length > kAiPracticeOptionCount) {
    options.removeRange(kAiPracticeOptionCount, options.length);
  }
  if (options.any((option) => option.isEmpty)) {
    return null;
  }
  // Prefer correctIndex; also accept correctAnswer letter (A-C) or option text.
  final correct = resolveCorrectIndex(map, options);
  if (correct == null || correct < 0 || correct >= kAiPracticeOptionCount) {
    return null;
  }
  final prompt = (map['question'] as String? ?? map['prompt'] as String? ?? '')
      .trim();
  if (prompt.isEmpty) {
    return null;
  }
  var explanation =
      (map['explanation'] as String? ?? map['reason'] as String? ?? '').trim();
  // Tiny models sometimes put the letter in explanation; ignore junk.
  if (explanation.length <= 3) {
    explanation = '';
  }
  final source = _sourceFromMap(map);
  return AiQuizQuestion(
    prompt: prompt,
    options: options,
    correctIndex: correct,
    explanation: explanation,
    chapterTitle: source.chapterTitle,
    lectureTitle: source.lectureTitle,
    slideFileName: source.slideFileName,
    slideFileIndex: source.slideFileIndex,
    slidePage: source.slidePage,
    sourceIndex: source.sourceIndex,
  );
}

AiQuiz parseAiQuiz(Object? raw) {
  final decoded = raw is String ? _decodeJson(raw) : raw;
  List<dynamic>? items;
  if (decoded is List) {
    items = decoded;
  } else if (decoded is Map) {
    final questions = decoded['questions'] ?? decoded['quiz'];
    if (questions is List) {
      items = questions;
    }
  }
  if (items == null) {
    throw const AiPracticeException(
      AiPracticeException.malformed,
      'Quiz JSON did not contain a questions array.',
    );
  }

  final questions = <AiQuizQuestion>[];
  for (final item in items) {
    if (item is! Map) {
      continue;
    }
    final map = Map<String, dynamic>.from(item);
    final options = <String>[
      for (final option in (map['options'] as List? ?? const []))
        option.toString().trim(),
    ];
    while (options.length < kAiPracticeOptionCount) {
      options.add('');
    }
    if (options.length > kAiPracticeOptionCount) {
      options.removeRange(kAiPracticeOptionCount, options.length);
    }
    if (options.any((option) => option.isEmpty)) {
      continue;
    }
    final correct = resolveCorrectIndex(map, options);
    if (correct == null || correct < 0 || correct >= kAiPracticeOptionCount) {
      continue;
    }
    final prompt =
        (map['question'] as String? ?? map['prompt'] as String? ?? '').trim();
    if (prompt.isEmpty) {
      continue;
    }
    final source = _sourceFromMap(map);
    questions.add(
      AiQuizQuestion(
        prompt: prompt,
        options: options,
        correctIndex: correct,
        explanation:
            (map['explanation'] as String? ?? map['reason'] as String? ?? '')
                .trim(),
        chapterTitle: source.chapterTitle,
        lectureTitle: source.lectureTitle,
        slideFileName: source.slideFileName,
        slideFileIndex: source.slideFileIndex,
        slidePage: source.slidePage,
        sourceIndex: source.sourceIndex,
      ),
    );
  }

  if (questions.length < kAiPracticeQuestionCount && raw is String) {
    for (final extra in salvageAiQuizQuestions(raw)) {
      final key = extra.prompt.toLowerCase();
      if (questions.any((q) => q.prompt.toLowerCase() == key)) {
        continue;
      }
      questions.add(extra);
      if (questions.length >= kAiPracticeQuestionCount) {
        break;
      }
    }
  }
  if (questions.length < kAiPracticeQuestionCount) {
    throw AiPracticeException(
      AiPracticeException.malformed,
      'Expected $kAiPracticeQuestionCount questions, got ${questions.length}.',
    );
  }
  return AiQuiz(questions: questions.take(kAiPracticeQuestionCount).toList());
}

Object? _decodeJson(String raw) {
  final trimmed = raw.trim();
  try {
    return jsonDecode(trimmed);
  } on FormatException {
    final start = trimmed.indexOf('[');
    final brace = trimmed.indexOf('{');
    final begin = start >= 0 && (brace < 0 || start < brace) ? start : brace;
    if (begin < 0) {
      rethrow;
    }
    final closer = trimmed[begin] == '[' ? ']' : '}';
    final end = trimmed.lastIndexOf(closer);
    if (end <= begin) {
      rethrow;
    }
    return jsonDecode(trimmed.substring(begin, end + 1));
  }
}

DateTime? _dateFrom(dynamic value) {
  if (value is Timestamp) {
    return value.toDate();
  }
  if (value is DateTime) {
    return value;
  }
  if (value is String) {
    return DateTime.tryParse(value);
  }
  return null;
}
