import 'dart:typed_data';

import 'course_file_pick.dart';

class ProfilePhotoException implements Exception {
  const ProfilePhotoException(this.code);

  final String code;
}

abstract final class ProfilePhoto {
  static const extensions = ['jpg', 'jpeg', 'png'];
  static const maxBytes = 800 * 1024;

  static Future<({String name, Uint8List bytes})?> pick() async {
    final files = await pickLocalCourseFiles(
      extensions: extensions,
      anyImage: true,
    );
    if (files.isEmpty) {
      return null;
    }
    final file = files.first;
    final error = validate(file.name, file.bytes);
    if (error != null) {
      throw ProfilePhotoException(error);
    }
    return (name: file.name, bytes: file.bytes);
  }

  static String? validate(String name, Uint8List bytes) {
    final ext = _extension(name);
    if (!extensions.contains(ext)) {
      return 'invalid_type';
    }
    if (bytes.isEmpty || bytes.length > maxBytes) {
      return 'too_large';
    }
    final isJpeg = bytes.length >= 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF;
    final isPng = bytes.length >= 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47;
    if (ext == 'png' && !isPng) {
      return 'invalid_type';
    }
    if ((ext == 'jpg' || ext == 'jpeg') && !isJpeg) {
      return 'invalid_type';
    }
    if (!isJpeg && !isPng) {
      return 'invalid_type';
    }
    return null;
  }

  static String _extension(String name) {
    final index = name.lastIndexOf('.');
    if (index < 0 || index == name.length - 1) {
      return '';
    }
    return name.substring(index + 1).toLowerCase();
  }
}
