import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:pemetaan_pohon/utils/pruning_photo_compressor.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> rejects(Uint8List bytes) async {
  try {
    await compressPruningPhoto(bytes);
  } on FormatException {
    return;
  }
  throw StateError('Input invalid should be rejected');
}

Future<void> main() async {
  final small = img.encodePng(img.Image(width: 8, height: 8));
  check(
    identical(await compressPruningPhoto(small), small),
    'Small photo changed',
  );
  Uint8List paddedPng(int length) {
    final result = Uint8List(length);
    result.setRange(0, small.length, small);
    return result;
  }

  final atLimit = paddedPng(pruningPhotoMaxBytes);
  check(
    identical(await compressPruningPhoto(atLimit), atLimit),
    'Boundary changed',
  );
  await rejects(Uint8List(0));
  await rejects(Uint8List.fromList([1, 2, 3]));
  await rejects(Uint8List.fromList(small.take(20).toList()));
  await rejects(Uint8List(pruningPhotoMaxBytes + 1));
  await rejects(Uint8List(pruningPhotoMaxInputBytes + 1));

  final source = img.Image(width: 1280, height: 960);
  final random = Random(42);
  for (final pixel in source) {
    pixel.setRgb(random.nextInt(256), random.nextInt(256), random.nextInt(256));
  }
  final png = img.encodePng(source);
  check(png.length > pruningPhotoMaxBytes, 'Fixture must require compression');
  final treeBoundary = paddedPng(treePhotoMaxBytes);
  check(
    identical(await compressTreePhoto(treeBoundary), treeBoundary),
    'Tree boundary changed',
  );
  final treeCompressed = await compressTreePhoto(png);
  check(
    base64Encode(treeCompressed).length <= 700000,
    'Tree Base64 exceeds rules',
  );
  check(img.decodeJpg(treeCompressed) != null, 'Tree JPEG invalid');
  final compressed = await compressPruningPhoto(png);
  check(base64Encode(compressed).length <= 350000, 'Base64 exceeds rules');
  final restored = img.decodeJpg(compressed)!;
  check(restored.width * 3 == restored.height * 4, 'Aspect ratio changed');
  check(restored.width >= 900, 'Photo was reduced too far');

  source.exif.imageIfd.orientation = 6;
  final rotated = await compressPruningPhoto(
    img.encodeJpg(source, quality: 100),
  );
  final portrait = img.decodeJpg(rotated)!;
  check(portrait.height > portrait.width, 'EXIF rotation was lost');
  check(portrait.exif.imageIfd.orientation == null, 'EXIF was retained');
  check(rotated.length <= pruningPhotoMaxBytes, 'Portrait too large');

  final transparent = img.Image(width: 600, height: 500, numChannels: 4);
  final rgbaPng = img.encodePng(transparent, level: 0);
  check(rgbaPng.length > pruningPhotoMaxBytes, 'Alpha fixture too small');
  final flattened = img.decodeJpg(await compressPruningPhoto(rgbaPng))!;
  check(flattened.getPixel(0, 0).r > 245, 'Transparent pixel should be white');
  stdout.writeln(
    'PASS: tree/public budgets, unchanged small/boundary, invalid/oversize input, PNG compression, Base64 budget, ratio, EXIF orientation, white transparency.',
  );
}