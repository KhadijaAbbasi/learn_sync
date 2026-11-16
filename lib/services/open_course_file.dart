import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';

import 'open_bytes.dart';

Future<void> openCourseFile(String url) async {
  final value = url.trim();
  if (value.isEmpty) {
    return;
  }
  if (value.startsWith('firestore://')) {
    final loaded = await _loadFirestoreFile(value);
    await openBytes(loaded.bytes, loaded.name, loaded.mime);
    return;
  }
  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    return;
  }
  final uri = parsed.hasScheme ? parsed : Uri.parse('https://$value');
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

class _LoadedFile {
  const _LoadedFile({
    required this.bytes,
    required this.name,
    required this.mime,
  });

  final Uint8List bytes;
  final String name;
  final String mime;
}

Future<_LoadedFile> _loadFirestoreFile(String url) async {
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
  return _LoadedFile(
    bytes: builder.takeBytes(),
    name: data['name'] as String? ?? 'file',
    mime: data['contentType'] as String? ?? 'application/octet-stream',
  );
}
