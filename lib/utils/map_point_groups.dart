import 'dart:math' as math;

/// Grid in Web Mercator pixels. Indices refer to the caller's filtered list.
/// Fixed cells keep regrouping independent of map panning.
List<List<int>> groupMapPoints(
  List<({double latitude, double longitude})> points,
  double zoom, {
  double cellSize = 56,
}) {
  if (!zoom.isFinite || !cellSize.isFinite || cellSize <= 0) {
    throw ArgumentError(
      'Zoom and cell size must be finite; cell size positive.',
    );
  }
  final scale = 256 * math.pow(2, zoom.clamp(0, 22).floor());
  final cells = <String, List<int>>{};
  for (var i = 0; i < points.length; i++) {
    final p = points[i];
    if (!p.latitude.isFinite ||
        !p.longitude.isFinite ||
        p.latitude.abs() > 90 ||
        p.longitude.abs() > 180) {
      continue;
    }
    final lat = p.latitude.clamp(-85.05112878, 85.05112878) * math.pi / 180;
    final x = (p.longitude + 180) / 360 * scale;
    final y =
        (1 - math.log(math.tan(lat) + 1 / math.cos(lat)) / math.pi) / 2 * scale;
    final key = '${(x / cellSize).floor()}:${(y / cellSize).floor()}';
    (cells[key] ??= []).add(i);
  }
  return cells.values.toList(growable: false);
}
