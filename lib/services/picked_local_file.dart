import 'dart:typed_data';

class PickedLocalFile {
  const PickedLocalFile({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}
