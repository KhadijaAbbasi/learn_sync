import 'dart:io';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

Future<String> downloadCourseFile({
  required String url,
  required String fileName,
}) async {
  final value = url.trim();
  if (value.isEmpty) {
    throw StateError('empty_url');
  }

  late final Uint8List bytes;
  if (value.startsWith('firestore://')) {
    bytes = await _loadFirestoreBytes(value);
  } else {
    final parsed = Uri.tryParse(value);
    if (parsed == null) {
      throw StateError('bad_url');
    }
    final uri = parsed.hasScheme ? parsed : Uri.parse('https://$value');
    final response = await http.get(uri);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError('http_${response.statusCode}');
    }
    bytes = response.bodyBytes;
  }

  final safeName = _safeFileName(fileName);
  final dir = await _downloadDirectory();
  var target = File('${dir.path}${Platform.pathSeparator}$safeName');
  if (await target.exists()) {
    final stem = safeName.contains('.')
        ? safeName.substring(0, safeName.lastIndexOf('.'))
        : safeName;
    final ext = safeName.contains('.')
        ? safeName.substring(safeName.lastIndexOf('.'))
        : '';
    target = File(
      '${dir.path}${Platform.pathSeparator}${stem}_${DateTime.now().millisecondsSinceEpoch}$ext',
    );
  }
  await target.writeAsBytes(bytes, flush: true);
  return target.path;
}

String _safeFileName(String name) {
  final cleaned = name.trim().replaceAll(RegExp(r'[^\w.\- ]+'), '_');
  if (cleaned.isEmpty) {
    return 'learnsync_file';
  }
  return cleaned;
}

Future<Directory> _downloadDirectory() async {
  if (Platform.isAndroid) {
    final public = Directory('/storage/emulated/0/Download');
    try {
      if (await public.exists()) {
        final probe = File(
          '${public.path}${Platform.pathSeparator}.learnsync_write_probe',
        );
        await probe.writeAsString('ok', flush: true);
        await probe.delete();
        return public;
      }
    } catch (_) {}
  }
  final downloads = await getDownloadsDirectory();
  if (downloads != null) {
    return downloads;
  }
  return getApplicationDocumentsDirectory();
}

Future<Uint8List> _loadFirestoreBytes(String url) async {
  final path = url.replaceFirst('firestore://', '');
  final doc = await FirebaseFirestore.instance.doc(path).get();
  final data = doc.data();
  if (!doc.exists || data == null) {
    throw StateError('missing_file');
  }
  final chunkCount = (data['chunkCount'] as num?)?.toInt() ?? 1;
  final builder = BytesBuilder(copy: false);
  for (var i = 0; i < chunkCount; i++) {
    final chunk = await doc.reference.collection('chunks').doc('$i').get();
    final blob = chunk.data()?['data'];
    if (blob is Blob) {
      builder.add(blob.bytes);
    }
  }
  return builder.takeBytes();
}
