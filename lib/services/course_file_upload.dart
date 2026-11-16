import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import 'course_file_pick.dart';
import 'picked_local_file.dart';

class CourseFileException implements Exception {
  const CourseFileException(this.code);

  final String code;

  @override
  String toString() => code;
}

class UploadedCourseFile {
  const UploadedCourseFile({required this.name, required this.url});

  final String name;
  final String url;
}

abstract final class CourseFileUpload {
  static const lectureExtensions = ['pdf', 'doc', 'docx', 'ppt', 'pptx'];
  static const documentExtensions = ['pdf', 'doc', 'docx'];
  static const syllabusExtensions = [
    'pdf',
    'doc',
    'docx',
    'ppt',
    'pptx',
    'png',
    'jpg',
    'jpeg',
    'gif',
    'webp',
    'bmp',
  ];
  static const maxBytes = 20 * 1024 * 1024;
  static const _chunkBytes = 700 * 1024;

  /// Opens the system picker only (no network). Empty list = cancel / no files.
  static Future<List<PickedLocalFile>> pickFiles({
    required List<String> extensions,
  }) async {
    final List<PickedLocalFile> picked;
    if (kIsWeb) {
      picked = await pickLocalCourseFiles(extensions: extensions).timeout(
        const Duration(minutes: 2),
        onTimeout: () => const <PickedLocalFile>[],
      );
    } else {
      picked = await _pickWithFilePicker(extensions);
    }
    return picked;
  }

  /// Uploads already-picked files. Uses Firestore chunks because this Firebase
  /// project does not have Storage set up (Storage put hangs on web).
  static Future<List<UploadedCourseFile>> uploadFiles({
    required String courseId,
    required String folder,
    required List<PickedLocalFile> files,
  }) async {
    if (courseId.trim().isEmpty) {
      throw const CourseFileException('storage_denied');
    }
    if (files.isEmpty) {
      return const [];
    }

    final uploaded = <UploadedCourseFile>[];
    for (final file in files) {
      if (file.bytes.isEmpty) {
        throw const CourseFileException('file_unreadable');
      }
      if (file.bytes.length > maxBytes) {
        throw const CourseFileException('file_too_large');
      }
      try {
        uploaded.add(
          await _saveToFirestore(
            courseId: courseId,
            folder: folder,
            file: file,
          ).timeout(const Duration(seconds: 90)),
        );
      } on TimeoutException {
        throw const CourseFileException('file_upload_failed');
      } on CourseFileException {
        rethrow;
      } on FirebaseException catch (error) {
        debugPrint('CourseFileUpload firestore failed: $error');
        if (error.code == 'permission-denied' ||
            error.code == 'unauthenticated') {
          throw const CourseFileException('storage_denied');
        }
        throw const CourseFileException('file_upload_failed');
      } catch (error, stack) {
        debugPrint('CourseFileUpload failed: $error');
        debugPrint('$stack');
        throw const CourseFileException('file_upload_failed');
      }
    }
    return uploaded;
  }

  /// Convenience: pick then upload. Prefer [pickFiles] + [uploadFiles] in UI
  /// so the loading spinner only covers the network step.
  static Future<List<UploadedCourseFile>> pickAndUpload({
    required String courseId,
    required String folder,
    required List<String> extensions,
  }) async {
    final picked = await pickFiles(extensions: extensions);
    if (picked.isEmpty) {
      return const [];
    }
    return uploadFiles(courseId: courseId, folder: folder, files: picked);
  }

  static Future<List<PickedLocalFile>> _pickWithFilePicker(
    List<String> extensions,
  ) async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
    );
    if (files.isEmpty) {
      return const [];
    }
    final picked = <PickedLocalFile>[];
    for (final file in files) {
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        continue;
      }
      picked.add(PickedLocalFile(name: file.name, bytes: bytes));
    }
    return picked;
  }

  static Future<UploadedCourseFile> _saveToFirestore({
    required String courseId,
    required String folder,
    required PickedLocalFile file,
  }) async {
    final files = FirebaseFirestore.instance
        .collection('courses')
        .doc(courseId)
        .collection('files');
    final doc = files.doc();
    final chunkCount = (file.bytes.length / _chunkBytes).ceil().clamp(1, 40);
    await doc.set({
      'name': file.name,
      'folder': folder,
      'contentType': _mimeFor(_extensionOf(file.name)),
      'size': file.bytes.length,
      'chunkCount': chunkCount,
      'createdAt': FieldValue.serverTimestamp(),
    });
    for (var i = 0; i < chunkCount; i++) {
      final start = i * _chunkBytes;
      final end = (start + _chunkBytes).clamp(0, file.bytes.length);
      await doc.collection('chunks').doc('$i').set({
        'data': Blob(file.bytes.sublist(start, end)),
      });
    }
    return UploadedCourseFile(
      name: file.name,
      url: 'firestore://courses/$courseId/files/${doc.id}',
    );
  }

  static String _extensionOf(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1);
  }

  static String _mimeFor(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'gif':
        return 'image/gif';
      case 'webp':
        return 'image/webp';
      case 'bmp':
        return 'image/bmp';
      default:
        return 'application/octet-stream';
    }
  }
}
