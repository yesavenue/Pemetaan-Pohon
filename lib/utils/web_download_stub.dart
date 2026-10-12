import 'dart:typed_data';

/// Admin exports are supported in the browser, not the surveyor application.
void downloadBytesAsFile(Uint8List bytes, String filename, {String? mimeType}) {
  throw UnsupportedError('Unduh file admin tersedia melalui website.');
}