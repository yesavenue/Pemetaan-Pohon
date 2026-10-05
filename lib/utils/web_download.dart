// Khusus Flutter Web — memicu browser mengunduh file dari bytes di memori.
// Admin Dashboard ini memang ditujukan untuk web, jadi pakai dart:html
// langsung di sini. Kalau suatu saat Admin juga perlu jalan di
// Android/iOS, fungsi ini perlu diganti pendekatan lain (mis. path_provider).
//
// CATATAN: dart:html sudah deprecated, Flutter mengarahkan ke package:web +
// dart:js_interop. Migrasi itu sengaja BELUM dilakukan di sini karena bukan
// sekadar ganti import — cara bikin Blob & trigger download-nya beda (perlu
// JS interop), dan fitur download ini sudah terbukti jalan (Excel, Word,
// foto). Daripada pertaruhkan fitur yang sudah stabil demi lint info-level,
// warning-nya sengaja dibungkam di sini sampai ada waktu migrasi + testing
// yang layak.
// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

void downloadBytesAsFile(Uint8List bytes, String filename, {String? mimeType}) {
  final blob = html.Blob(
    [bytes],
    mimeType ?? 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  );
  final url = html.Url.createObjectUrlFromBlob(blob);
  html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..click();
  html.Url.revokeObjectUrl(url);
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
  if (bytes.length >= 3 && bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) {
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