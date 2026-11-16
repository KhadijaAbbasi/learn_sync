import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:xml/xml.dart';

import '../models/course_content.dart';
import 'load_course_file.dart';

class SlideTextChunk {
  const SlideTextChunk({
    required this.fileIndex,
    required this.slidePage,
    required this.fileName,
    required this.text,
  });

  final int fileIndex;

  /// 1-based page/slide index inside [fileName].
  final int slidePage;
  final String fileName;
  final String text;
}

class DocumentQuizSource {
  const DocumentQuizSource({required this.combinedText, required this.slides});

  final String combinedText;
  final List<SlideTextChunk> slides;

  bool get isEmpty => combinedText.trim().isEmpty;
}

/// Text for the slides in [targetKeys] (`fileIndex:slidePage`).
///
/// When [allowFullFallback] is true and none of those slides have extracted
/// text, returns [fallbackNotes]. When false (weak-slide quizzes), never
/// expands back to the full lecture — only target-slide text or stubs.
String textForSlideTargets({
  required List<SlideTextChunk> slides,
  required Set<String> targetKeys,
  required String fallbackNotes,
  bool allowFullFallback = true,
}) {
  if (targetKeys.isEmpty) {
    return fallbackNotes;
  }
  if (slides.isEmpty) {
    if (allowFullFallback) {
      return fallbackNotes;
    }
    return _stubTargets(targetKeys);
  }
  final buffer = StringBuffer();
  for (final slide in slides) {
    final key = '${slide.fileIndex}:${slide.slidePage}';
    if (!targetKeys.contains(key)) {
      continue;
    }
    final name = slide.fileName.trim();
    final label = name.isEmpty
        ? 'File ${slide.fileIndex + 1} Slide ${slide.slidePage}'
        : 'File ${slide.fileIndex + 1} Slide ${slide.slidePage} ($name)';
    buffer.writeln('--- $label ---');
    buffer.writeln(slide.text.trim());
    buffer.writeln();
  }
  final focused = buffer.toString().trim();
  if (focused.isEmpty) {
    if (allowFullFallback) {
      return fallbackNotes;
    }
    return _stubTargets(targetKeys);
  }
  return focused;
}

String _stubTargets(Set<String> targetKeys) {
  final buffer = StringBuffer();
  final keys = targetKeys.toList()..sort();
  for (final key in keys) {
    final parts = key.split(':');
    final file = int.tryParse(parts.isNotEmpty ? parts[0] : '') ?? 0;
    final page = int.tryParse(parts.length > 1 ? parts[1] : '') ?? 1;
    buffer.writeln('--- File ${file + 1} Slide $page ---');
    buffer.writeln(
      '(Student marked this slide as weak. Use only concepts from this slide '
      'if they appear elsewhere in the conversation context; do not invent '
      'content from other slides.)',
    );
    buffer.writeln();
  }
  return buffer.toString().trim();
}

/// Pulls plain text from topic attachments (pptx / docx / pdf-ish names).
/// PPTX is split per slide so AI Practice can focus on weak-understanding slides.
Future<DocumentQuizSource> extractDocumentQuizSource(
  List<CourseAttachment> attachments,
) async {
  if (attachments.isEmpty) {
    return const DocumentQuizSource(combinedText: '', slides: []);
  }

  final slides = <SlideTextChunk>[];
  final buffer = StringBuffer();

  for (var fileIndex = 0; fileIndex < attachments.length; fileIndex++) {
    final file = attachments[fileIndex];
    final name = file.name.isNotEmpty ? file.name : file.url;
    final key = name.toLowerCase().split('?').first;
    try {
      final bytes = await loadCourseFileBytes(file.url);
      if (bytes.isEmpty) {
        continue;
      }
      if (key.endsWith('.pptx')) {
        final parts = _extractPptxSlides(bytes);
        for (var i = 0; i < parts.length; i++) {
          final text = parts[i].trim();
          if (text.isEmpty) {
            continue;
          }
          final page = i + 1;
          slides.add(
            SlideTextChunk(
              fileIndex: fileIndex,
              slidePage: page,
              fileName: name,
              text: text,
            ),
          );
          buffer.writeln('--- File ${fileIndex + 1} Slide $page ($name) ---');
          buffer.writeln(text);
          buffer.writeln();
        }
      } else if (key.endsWith('.docx')) {
        final text = _extractDocxText(bytes).trim();
        if (text.isNotEmpty) {
          slides.add(
            SlideTextChunk(
              fileIndex: fileIndex,
              slidePage: 1,
              fileName: name,
              text: text,
            ),
          );
          buffer.writeln('--- File ${fileIndex + 1} ($name) ---');
          buffer.writeln(text);
          buffer.writeln();
        }
      } else if (key.endsWith('.pdf')) {
        // No reliable client-side PDF text extractor in this app; keep a marker
        // so the model still knows a PDF was taught (prefer pptx for quizzes).
        buffer.writeln(
          '--- File ${fileIndex + 1} ($name) ---\n'
          '(PDF attached; extractible slide text unavailable in-app. '
          'Prefer PPTX for AI Practice.)\n',
        );
      } else {
        debugPrint('extractDocumentQuizSource: skip unsupported $name');
      }
    } catch (error, stack) {
      debugPrint('extractDocumentQuizSource failed for $name: $error');
      debugPrint('$stack');
    }
  }

  return DocumentQuizSource(
    combinedText: buffer.toString().trim(),
    slides: slides,
  );
}

List<String> _extractPptxSlides(Uint8List input) {
  final archive = ZipDecoder().decodeBytes(input, verify: false);
  final files = <String, Uint8List>{};
  for (final entry in archive) {
    if (!entry.isFile) {
      continue;
    }
    final name = entry.name.replaceAll('\\', '/');
    final bytes = entry.content;
    if (bytes.isEmpty) {
      continue;
    }
    files[name] = bytes;
  }

  final slidePattern = RegExp(
    r'^ppt/slides/slide\d+\.xml$',
    caseSensitive: false,
  );
  final slidePaths = files.keys.where(slidePattern.hasMatch).toList()
    ..sort((a, b) {
      final na = int.parse(
        RegExp(r'slide(\d+)', caseSensitive: false).firstMatch(a)!.group(1)!,
      );
      final nb = int.parse(
        RegExp(r'slide(\d+)', caseSensitive: false).firstMatch(b)!.group(1)!,
      );
      return na.compareTo(nb);
    });

  final out = <String>[];
  for (final path in slidePaths) {
    final bytes = files[path];
    if (bytes == null) {
      out.add('');
      continue;
    }
    try {
      final xml = XmlDocument.parse(utf8.decode(bytes));
      final parts = <String>[];
      for (final node in xml.descendants.whereType<XmlElement>()) {
        if (node.name.local != 't') {
          continue;
        }
        final value = node.innerText.trim();
        if (value.isNotEmpty) {
          parts.add(value);
        }
      }
      out.add(parts.join('\n'));
    } catch (_) {
      out.add('');
    }
  }
  return out;
}

String _extractDocxText(Uint8List input) {
  final archive = ZipDecoder().decodeBytes(input, verify: false);
  for (final entry in archive) {
    if (!entry.isFile) {
      continue;
    }
    final name = entry.name.replaceAll('\\', '/');
    if (name.toLowerCase() != 'word/document.xml') {
      continue;
    }
    final bytes = entry.content;
    if (bytes.isEmpty) {
      return '';
    }
    try {
      final xml = XmlDocument.parse(utf8.decode(bytes));
      final parts = <String>[];
      for (final node in xml.descendants.whereType<XmlElement>()) {
        if (node.name.local != 't') {
          continue;
        }
        final value = node.innerText.trim();
        if (value.isNotEmpty) {
          parts.add(value);
        }
      }
      return parts.join(' ');
    } catch (_) {
      return '';
    }
  }
  return '';
}
