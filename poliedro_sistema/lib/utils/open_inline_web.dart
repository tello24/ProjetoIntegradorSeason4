// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:typed_data';
import 'dart:html' as html;

Future<void> openInlineBytes(Uint8List bytes, String contentType, {String? fileName}) async {
  final blob = html.Blob([bytes], contentType);
  final url = html.Url.createObjectUrlFromBlob(blob);

  final a = html.AnchorElement(href: url)..target = '_blank';
  if (fileName != null && fileName.isNotEmpty) a.download = fileName;
  a.click();

  html.Url.revokeObjectUrl(url);
}
