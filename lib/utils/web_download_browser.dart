// Browser-only implementation selected by conditional import.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytesAsFile(Uint8List bytes, String filename, {String? mimeType}) {
  final blob = html.Blob(
    [bytes],
    mimeType ??
        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
}