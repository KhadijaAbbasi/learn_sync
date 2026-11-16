import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:http/http.dart' as http;

import '../models/course_content.dart';

/// Loads course attachment bytes from Firebase Storage HTTPS URLs or
/// Firestore chunked `firestore://` URLs.
Future<Uint8List> loadCourseFileBytes(String url) async {
  final value = url.trim();
  if (value.isEmpty) {
    throw StateError('empty_url');
  }
  if (value.startsWith('firestore://')) {
    return _loadFirestoreBytes(value);
  }
  final parsed = Uri.tryParse(value);
  if (parsed == null) {
    throw StateError('bad_url');
  }
  final uri = parsed.hasScheme ? parsed : Uri.parse('https://$value');
  final response = await http.get(uri);
  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw StateError('download_failed');
  }
  return response.bodyBytes;
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

String courseFileExtension(String nameOrUrl) {
  final cleaned = nameOrUrl.trim().split('?').first;
  final dot = cleaned.lastIndexOf('.');
  if (dot < 0 || dot == cleaned.length - 1) {
    return '';
  }
  return cleaned.substring(dot + 1).toLowerCase();
}

bool isCoursePdf(String nameOrUrl) => courseFileExtension(nameOrUrl) == 'pdf';

bool isCourseImage(String nameOrUrl) {
  return const {
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
  }.contains(courseFileExtension(nameOrUrl));
}

bool isCoursePpt(String nameOrUrl) {
  return const {'ppt', 'pptx'}.contains(courseFileExtension(nameOrUrl));
}

bool isCourseOfficeDoc(String nameOrUrl) {
  return const {
    'ppt',
    'pptx',
    'doc',
    'docx',
    'xls',
    'xlsx',
  }.contains(courseFileExtension(nameOrUrl));
}

String courseFileContentType(String nameOrUrl) {
  switch (courseFileExtension(nameOrUrl)) {
    case 'pdf':
      return 'application/pdf';
    case 'ppt':
      return 'application/vnd.ms-powerpoint';
    case 'pptx':
      return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
    case 'doc':
      return 'application/msword';
    case 'docx':
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    case 'xls':
      return 'application/vnd.ms-excel';
    case 'xlsx':
      return 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    case 'png':
      return 'image/png';
    case 'jpg':
    case 'jpeg':
      return 'image/jpeg';
    default:
      return 'application/octet-stream';
  }
}

/// HTTPS URL suitable for Office Online / Google viewers.
/// Firestore-backed files are mirrored once under `courses/{id}/view_cache/`.
/// Returns null when Storage is unavailable (this project often has Storage unset
/// and `putData` hangs on web).
Future<String?> resolvePublicCourseFileUrl({
  required String courseId,
  required CourseAttachment file,
  Uint8List? bytes,
}) async {
  final raw = file.url.trim();
  if (raw.isEmpty) {
    return null;
  }
  if (!raw.startsWith('firestore://')) {
    return raw;
  }
  if (courseId.trim().isEmpty) {
    return null;
  }
  final keyName = file.name.isNotEmpty ? file.name : raw;
  final ext = courseFileExtension(keyName);
  final safeExt = ext.isEmpty ? 'bin' : ext;
  final digest = base64Url
      .encode(utf8.encode(raw))
      .replaceAll('=', '');
  final ref = FirebaseStorage.instance.ref(
    'courses/$courseId/view_cache/$digest.$safeExt',
  );
  try {
    return await ref.getDownloadURL().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Fall through to upload attempt.
  }
  try {
    final payload = bytes ?? await loadCourseFileBytes(raw);
    await ref
        .putData(
          payload,
          SettableMetadata(contentType: courseFileContentType(keyName)),
        )
        .timeout(const Duration(seconds: 8));
    return await ref.getDownloadURL().timeout(const Duration(seconds: 4));
  } catch (_) {
    // Storage not configured / hung / denied — caller shows open-externally UI.
    return null;
  }
}

/// Microsoft Office Online embed URL for in-app WebView.
String officeEmbedUrl(String publicFileUrl) {
  return 'https://view.officeapps.live.com/op/embed.aspx?src=${Uri.encodeComponent(publicFileUrl)}';
}
