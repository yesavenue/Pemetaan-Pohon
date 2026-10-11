import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Matches the existing 350000-character Base64 rule, without changing storage.
const pruningPhotoMaxBytes = 262500;
const pruningPhotoMaxInputBytes = 20 * 1024 * 1024;

/// Small photos retain their original bytes. Oversized photos become JPEGs.
/// A successful result always fits the existing Firestore field limit.
/// This function is suitable for compute() on native platforms; on the web,
/// processing runs on the main thread and yields between encoding attempts.
Future<Uint8List> compressPruningPhoto(Uint8List bytes) =>
    _compressPhoto(bytes, pruningPhotoMaxBytes);

const treePhotoMaxBytes = 525000;
Future<Uint8List> compressTreePhoto(Uint8List bytes) =>
    _compressPhoto(bytes, treePhotoMaxBytes);

Future<Uint8List> _compressPhoto(Uint8List bytes, int maxBytes) async {
  try {
    return await _decodeAndCompress(bytes, maxBytes);
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException(
      'Foto rusak atau tidak dapat dibaca. Gunakan foto JPG atau PNG lain.',
    );
  }
}

Future<Uint8List> _decodeAndCompress(Uint8List bytes, int maxBytes) async {
  if (bytes.isEmpty) {
    throw const FormatException('Foto kosong. Pilih foto lain.');
  }
  if (bytes.length > pruningPhotoMaxInputBytes) {
    throw const FormatException(
      'Foto terlalu besar untuk diproses. Pilih versi dengan resolusi lebih rendah.',
    );
  }

  final decoder = img.findDecoderForData(bytes);
  final info = decoder?.startDecode(bytes);
  if (info == null || info.width <= 0 || info.height <= 0) {
    throw const FormatException(
      'Format foto tidak dapat diproses. Gunakan foto JPG atau PNG.',
    );
  }
  // Bound decoded memory before allocating a full raster.
  if (info.width * info.height > 40000000) {
    throw const FormatException(
      'Resolusi foto terlalu tinggi untuk diproses. Pilih foto beresolusi lebih rendah.',
    );
  }
  final decoded = decoder!.decodeFrame(0);
  if (decoded == null) {
    throw const FormatException('Foto tidak dapat dibaca. Pilih foto lain.');
  }
  // Decode validates content, but small valid photos keep their exact bytes.
  if (bytes.length <= maxBytes) return bytes;

  final source = img.bakeOrientation(decoded);
  final longest = source.width > source.height ? source.width : source.height;
  int? previousEdge;
  for (final targetEdge in [1600, 1280, 1024, 900]) {
    final edge = longest < targetEdge ? longest : targetEdge;
    if (edge == previousEdge) continue;
    previousEdge = edge;
    await Future<void>.delayed(const Duration(milliseconds: 1));
    final resized = edge == longest
        ? source
        : img.copyResize(
            source,
            width: source.width >= source.height ? edge : null,
            height: source.height > source.width ? edge : null,
            interpolation: img.Interpolation.average,
          );
    // Flatten transparency onto white; fresh RGB image also omits EXIF/GPS.
    final opaque = img.Image(width: resized.width, height: resized.height);
    img.fill(opaque, color: img.ColorRgb8(255, 255, 255));
    img.compositeImage(opaque, resized);
    for (final quality in [88, 78, 68, 58]) {
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final result = img.encodeJpg(
        opaque,
        quality: quality,
        chroma: img.JpegChroma.yuv420,
      );
      if (result.length <= maxBytes) return result;
    }
  }
  // Do not keep reducing resolution/quality indefinitely, especially for KTP.
  throw const FormatException(
    'Foto belum bisa disiapkan dengan kualitas yang cukup. '
    'Ambil ulang lebih dekat dengan objek dan pencahayaan yang baik.',
  );
} 