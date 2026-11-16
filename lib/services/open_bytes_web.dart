import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart';

Future<void> openBytes(Uint8List bytes, String name, String mime) async {
  final blob = Blob(
    [bytes.toJS].toJS,
    BlobPropertyBag(type: mime.isEmpty ? 'application/octet-stream' : mime),
  );
  final url = URL.createObjectURL(blob);
  window.open(url, '_blank');
}
