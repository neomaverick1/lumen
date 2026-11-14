import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

/// ML Kit reads images from a file path, so edits are written to the app's temp folder.
Future<String> writeTemp(String name, Uint8List bytes) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$name');
  await f.writeAsBytes(bytes, flush: true);
  return f.path;
}
