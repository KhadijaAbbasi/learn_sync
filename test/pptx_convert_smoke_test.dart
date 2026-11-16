
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnsync/services/presentation_to_pdf.dart';

void main() {
  test('pptx converts to pdf bytes', () async {
    final input = File(r'C:\Users\HP\AppData\Local\Temp\tiny.pptx').readAsBytesSync();
    final out = await presentationToPdfBytes(input, fileName: 'tiny.pptx');
    expect(out.length, greaterThan(100));
    // PDF magic
    expect(String.fromCharCodes(out.take(4)), '%PDF');
  });
}
