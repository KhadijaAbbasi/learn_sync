import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

import 'picked_local_file.dart';

Future<List<PickedLocalFile>> pickLocalCourseFiles({
  required List<String> extensions,
  bool anyImage = false,
}) async {
  final input = HTMLInputElement()
    ..type = 'file'
    ..multiple = true
    ..accept = anyImage
        ? 'image/*'
        : extensions.map((ext) => '.$ext').join(',');

  final completer = Completer<List<PickedLocalFile>>();

  void finish(List<PickedLocalFile> files) {
    if (!completer.isCompleted) {
      completer.complete(files);
    }
  }

  input.addEventListener(
    'change',
    (Event _) {
      final files = input.files;
      if (files == null || files.length == 0) {
        finish(const []);
        return;
      }
      _readAll(files).then(finish).catchError((Object _) => finish(const []));
    }.toJS,
  );
  input.addEventListener(
    'cancel',
    (Event _) {
      finish(const []);
    }.toJS,
  );

  document.body?.append(input);
  input.click();
  try {
    return await completer.future;
  } finally {
    input.remove();
  }
}

Future<List<PickedLocalFile>> _readAll(FileList files) async {
  final picked = <PickedLocalFile>[];
  for (var i = 0; i < files.length; i++) {
    final file = files.item(i);
    if (file == null) {
      continue;
    }
    final bytes = await _readBytes(file);
    if (bytes == null || bytes.isEmpty) {
      continue;
    }
    picked.add(PickedLocalFile(name: file.name, bytes: bytes));
  }
  return picked;
}

Future<Uint8List?> _readBytes(File file) async {
  try {
    final JSArrayBuffer buffer = await file.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return _readBytesWithFileReader(file);
  }
}

Future<Uint8List?> _readBytesWithFileReader(File file) {
  final completer = Completer<Uint8List?>();
  final reader = FileReader();
  reader.addEventListener(
    'loadend',
    (Event _) {
      if (completer.isCompleted) {
        return;
      }
      try {
        final result = reader.result;
        if (result == null) {
          completer.complete(null);
          return;
        }
        final buffer = (result as JSArrayBuffer).toDart;
        completer.complete(buffer.asUint8List());
      } catch (_) {
        completer.complete(null);
      }
    }.toJS,
  );
  reader.addEventListener(
    'error',
    (Event _) {
      if (!completer.isCompleted) {
        completer.complete(null);
      }
    }.toJS,
  );
  reader.readAsArrayBuffer(file);
  return completer.future;
}
