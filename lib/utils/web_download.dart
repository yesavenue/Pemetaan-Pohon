import 'dart:typed_data';
import 'web_download_stub.dart'
    if (dart.library.html) 'web_download_browser.dart'
    as platform;

/// Keep the same API for admin exports; only web builds import dart:html.
void downloadBytesAsFile(Uint8List bytes, String filename, {String? mimeType}) {
  platform.downloadBytesAsFile(bytes, filename, mimeType: mimeType);
}

/// Menebak ekstensi & mime type gambar dari beberapa byte pertamanya
/// (magic number), supaya file yang diunduh punya ekstensi yang benar
/// walau kita tidak tahu format asli dari sumbernya.
({String extension, String mimeType}) guessImageFormat(Uint8List bytes) {
  if (bytes.length >= 8 &&
      bytes[0] == 0x89 &&
      bytes[1] == 0x50 &&
      bytes[2] == 0x4E &&
      bytes[3] == 0x47) {
    return (extension: 'png', mimeType: 'image/png');
  }
  if (bytes.length >= 3 &&
      bytes[0] == 0xFF &&
      bytes[1] == 0xD8 &&
      bytes[2] == 0xFF) {
    return (extension: 'jpg', mimeType: 'image/jpeg');
  }
  if (bytes.length >= 6 &&
      bytes[0] == 0x47 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46) {
    return (extension: 'gif', mimeType: 'image/gif');
  }
  if (bytes.length >= 12 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x45 &&
      bytes[10] == 0x42 &&
      bytes[11] == 0x50) {
    return (extension: 'webp', mimeType: 'image/webp');
  }
  return (extension: 'jpg', mimeType: 'image/jpeg'); // fallback wajar
}