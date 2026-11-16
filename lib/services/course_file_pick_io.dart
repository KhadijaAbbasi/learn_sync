import 'package:file_picker/file_picker.dart';

import 'picked_local_file.dart';

Future<List<PickedLocalFile>> pickLocalCourseFiles({
  required List<String> extensions,
  bool anyImage = false,
}) async {
  final files = await FilePicker.pickFiles(
    type: anyImage ? FileType.image : FileType.custom,
    allowedExtensions: anyImage ? null : extensions,
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
