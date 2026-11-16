import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:xml/xml.dart';

/// Converts a `.pptx` (OOXML) presentation into a simple multi-page PDF so the
/// existing live-lecture PDF viewer can show slides and sync page changes.
///
/// Old binary `.ppt` is not supported.

String _pdfSafeText(String input) {
  // Helvetica (default) is Latin-1 only; keep slides rendering for any locale.
  final buffer = StringBuffer();
  for (final unit in input.runes) {
    if (unit == 0x09 || unit == 0x0A || unit == 0x0D || (unit >= 0x20 && unit <= 0x7E)) {
      buffer.writeCharCode(unit);
    } else if (unit <= 0xFF) {
      buffer.writeCharCode(unit);
    } else {
      buffer.write('?');
    }
  }
  return buffer.toString();
}

Future<Uint8List> presentationToPdfBytes(
  Uint8List input, {
  required String fileName,
}) async {
  final lower = fileName.toLowerCase().split('?').first;
  if (!lower.endsWith('.pptx')) {
    throw StateError('unsupported_presentation');
  }

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

  if (slidePaths.isEmpty) {
    debugPrint(
      'presentationToPdfBytes: no slides in archive; keys='
      '${files.keys.where((k) => k.contains('slide')).toList()}',
    );
    throw StateError('no_slides');
  }

  final doc = pw.Document();
  // 16:9 landscape — matches typical deck aspect.
  const pageFormat = PdfPageFormat(960, 540);

  for (var i = 0; i < slidePaths.length; i++) {
    final slidePath = slidePaths[i];
    final slideBytes = files[slidePath];
    if (slideBytes == null) {
      continue;
    }

    final texts = <String>[];
    try {
      final slideXml = XmlDocument.parse(utf8.decode(slideBytes));
      for (final node in slideXml.descendants.whereType<XmlElement>()) {
        if (node.name.local != 't') {
          continue;
        }
        final value = node.innerText.trim();
        if (value.isNotEmpty) {
          texts.add(_pdfSafeText(value));
        }
      }
    } catch (error) {
      debugPrint('presentationToPdfBytes: slide XML parse failed: $error');
    }

    final images = <pw.MemoryImage>[];
    final relsPath = 'ppt/slides/_rels/${slidePath.split('/').last}.rels';
    final relsBytes = files[relsPath];
    if (relsBytes != null) {
      try {
        final relsXml = XmlDocument.parse(utf8.decode(relsBytes));
        for (final rel in relsXml.descendants.whereType<XmlElement>()) {
          if (rel.name.local != 'Relationship') {
            continue;
          }
          final type = rel.getAttribute('Type') ?? '';
          if (!type.toLowerCase().contains('image')) {
            continue;
          }
          var target = (rel.getAttribute('Target') ?? '').replaceAll('\\', '/');
          if (target.isEmpty) {
            continue;
          }
          late final String mediaPath;
          if (target.startsWith('/')) {
            mediaPath = target.substring(1);
          } else if (target.startsWith('../')) {
            mediaPath = 'ppt/${target.substring(3)}';
          } else {
            mediaPath = 'ppt/slides/$target';
          }
          final media = files[mediaPath];
          if (media == null || media.isEmpty) {
            continue;
          }
          try {
            images.add(pw.MemoryImage(media));
          } catch (_) {
            // Skip unsupported image codecs.
          }
        }
      } catch (_) {
        // Ignore broken relationships.
      }
    }

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: const pw.EdgeInsets.all(28),
        build: (context) {
          final children = <pw.Widget>[];
          if (images.isNotEmpty) {
            final tall = texts.isEmpty;
            for (final image in images.take(tall ? 1 : 2)) {
              children.add(
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 10),
                  child: pw.Center(
                    child: pw.Image(
                      image,
                      height: tall ? 460 : 200,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                ),
              );
            }
          }
          for (final line in texts) {
            children.add(
              pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 6),
                child: pw.Text(
                  line,
                  style: pw.TextStyle(
                    fontSize: texts.length <= 4 ? 22 : 14,
                    lineSpacing: 1.2,
                  ),
                ),
              ),
            );
          }
          if (children.isEmpty) {
            children.add(
              pw.Center(
                child: pw.Text(
                  _pdfSafeText('Slide ${i + 1}'),
                  style: pw.TextStyle(fontSize: 28),
                ),
              ),
            );
          }
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: children,
          );
        },
      ),
    );
  }

  return Uint8List.fromList(await doc.save());
}
