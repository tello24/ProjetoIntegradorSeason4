import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

Future<void> openInlineBytes(Uint8List bytes, String contentType, {String? fileName}) async {
  final dir = await getTemporaryDirectory();
  final name = (fileName != null && fileName.isNotEmpty)
      ? fileName
      : _defaultNameFor(contentType);
  final file = File('${dir.path}/$name');
  await file.writeAsBytes(bytes, flush: true);
  await OpenFilex.open(file.path);
}

String _defaultNameFor(String contentType) {
  final ct = contentType.toLowerCase();
  if (ct.contains('pdf')) return 'material.pdf';
  if (ct.contains('png')) return 'material.png';
  if (ct.contains('jpeg') || ct.contains('jpg')) return 'material.jpg';
  return 'material.bin';
}
