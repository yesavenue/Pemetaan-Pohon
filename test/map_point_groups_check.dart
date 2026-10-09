import 'dart:io';
import 'package:pemetaan_pohon/utils/map_point_groups.dart';

void check(bool condition, String message) {
  if (!condition) {
    throw StateError(message);
  }
}

void main() {
  final points = [
    (latitude: -6.7183, longitude: 108.5522),
    (latitude: -6.7183, longitude: 108.5522),
    (latitude: -6.7, longitude: 108.6),
    (latitude: -6.9, longitude: 108.2),
  ];
  check(groupMapPoints([], 13).isEmpty, 'Empty input');
  final far = groupMapPoints(points, 3);
  final near = groupMapPoints(points, 19);
  check(far.length < near.length, 'Zoom must expose separated positions');
  check(
    near.any((g) => g.contains(0) && g.contains(1)),
    'Identical positions remain accessible as a group',
  );
  final dense = List.generate(
    1000,
    (i) => (
      latitude: -6.72 + (i ~/ 40) * .0001,
      longitude: 108.55 + (i % 40) * .0001,
    ),
  );
  for (final zoom in [3.0, 13.0, 17.0, 19.0]) {
    final groups = groupMapPoints(dense, zoom);
    final indices = groups.expand((g) => g).toList();
    check(
      indices.length == dense.length && indices.toSet().length == dense.length,
      'No lost or duplicate trees at zoom $zoom',
    );
  }
  final invalid = groupMapPoints([
    (latitude: double.nan, longitude: 0.0),
    (latitude: 91.0, longitude: 0.0),
    (latitude: 0.0, longitude: double.infinity),
    points[0],
  ], 13);
  check(
    invalid.length == 1 && invalid.single.single == 3,
    'Invalid coordinates must be skipped',
  );
  check(
    groupMapPoints([(latitude: 90.0, longitude: 180.0)], 19).length == 1,
    'Mercator latitude clamp',
  );
  var rejected = false;
  try {
    groupMapPoints(points, 13, cellSize: 0);
  } on ArgumentError {
    rejected = true;
  }
  check(rejected, 'Invalid cell size');
  stdout.writeln(
    'PASS: empty, dense1000, zoom, identical, invalid, poles, cell size.',
  );
}
