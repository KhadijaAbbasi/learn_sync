import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> openBytes(Uint8List bytes, String name, String mime) async {
  final safeName = name.replaceAll(RegExp(r'[^\w.\-]+'), '_');
  final file = File('${Directory.systemTemp.path}/$safeName');
  await file.writeAsBytes(bytes, flush: true);
  final result = await OpenFilex.open(file.path);
  if (result.type == ResultType.done) {
    return;
  }
  final uri = Uri.file(file.path);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
    return;
  }
  throw StateError('open_failed:${result.message}');
}
