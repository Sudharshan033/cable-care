import 'dart:typed_data';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

void downloadBytes(List<int> bytes, String filename) {
  final blob = html.Blob([Uint8List.fromList(bytes)]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  (html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click());
  html.Url.revokeObjectUrl(url);
}
