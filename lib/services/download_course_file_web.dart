import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'load_course_file.dart';

Future<String> downloadCourseFile({
  required String url,
  required String fileName,
}) async {
  final bytes = await loadCourseFileBytes(url);
  final name = fileName.trim().replaceAll(RegExp(r'[/\\\x00-\x1f]'), '_');
  final safeName = name.isEmpty ? 'learnsync_file' : name;
  final blob = web.Blob(
    [bytes.toJS].toJS,
    web.BlobPropertyBag(type: courseFileContentType(safeName)),
  );
  final objectUrl = web.URL.createObjectURL(blob);
  final anchor = web.HTMLAnchorElement()
    ..href = objectUrl
    ..download = safeName
    ..style.display = 'none';
  web.document.body!.append(anchor);
  anchor.click();
  anchor.remove();
  Timer(const Duration(minutes: 1), () => web.URL.revokeObjectURL(objectUrl));
  return safeName;
}
