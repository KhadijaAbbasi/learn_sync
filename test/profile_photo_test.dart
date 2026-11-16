import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:learnsync/services/profile_photo.dart';

void main() {
  test('accepts JPEG and PNG files', () {
    final jpeg = Uint8List.fromList([0xFF, 0xD8, 0xFF, 0x00]);
    final png = Uint8List.fromList([
      0x89,
      0x50,
      0x4E,
      0x47,
      0x0D,
      0x0A,
      0x1A,
      0x0A,
    ]);
    expect(ProfilePhoto.validate('avatar.jpg', jpeg), isNull);
    expect(ProfilePhoto.validate('avatar.jpeg', jpeg), isNull);
    expect(ProfilePhoto.validate('avatar.png', png), isNull);
  });

  test('rejects other image formats', () {
    final gif = Uint8List.fromList([0x47, 0x49, 0x46, 0x38, 0x39, 0x61]);
    expect(ProfilePhoto.validate('avatar.gif', gif), 'invalid_type');
    expect(ProfilePhoto.validate('avatar.webp', gif), 'invalid_type');
    expect(ProfilePhoto.validate('notes.pdf', gif), 'invalid_type');
  });
}
