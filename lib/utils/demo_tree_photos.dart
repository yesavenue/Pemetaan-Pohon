import 'dart:convert';
import 'dart:ui' as ui;

/// Clearly labelled synthetic illustrations, not photos of surveyed trees.
Future<Map<String, String>> buildDemoTreePhotos() async {
  final photos = <String, String>{};
  for (final entry in const <String, int>{
    'sehat': 0xFF2E9B68,
    'sakit': 0xFFE1B919,
    'rawanTumbang': 0xFFE05252,
  }.entries) {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawPaint(ui.Paint()..color = const ui.Color(0xFFE9F3ED));
    canvas.drawOval(
      const ui.Rect.fromLTWH(90, 230, 240, 30),
      ui.Paint()..color = const ui.Color(0xFFCADDD1),
    );
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(
        const ui.Rect.fromLTWH(194, 140, 28, 100),
        const ui.Radius.circular(6),
      ),
      ui.Paint()..color = const ui.Color(0xFF765947),
    );
    final foliage = ui.Paint()..color = ui.Color(entry.value);
    canvas.drawCircle(const ui.Offset(165, 126), 58, foliage);
    canvas.drawCircle(const ui.Offset(247, 126), 58, foliage);
    canvas.drawCircle(const ui.Offset(206, 81), 59, foliage);
    final text =
        (ui.ParagraphBuilder(ui.ParagraphStyle(textAlign: ui.TextAlign.center))
              ..pushStyle(
                ui.TextStyle(color: const ui.Color(0xFF0B3554), fontSize: 19),
              )
              ..addText('DATA CONTOH • BUKAN FOTO SURVEI'))
            .build()
          ..layout(const ui.ParagraphConstraints(width: 420));
    canvas.drawParagraph(text, const ui.Offset(0, 272));
    final picture = recorder.endRecording();
    ui.Image? image;
    try {
      image = await picture.toImage(420, 320);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) {
        throw StateError('Ilustrasi contoh belum berhasil dibuat.');
      }
      photos[entry.key] = base64Encode(
        bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
      );
    } finally {
      image?.dispose();
      picture.dispose();
      text.dispose();
    }
  }
  return photos;
}