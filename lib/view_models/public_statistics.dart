import '../models/tree_data.dart';
import '../utils/cirebon_regions.dart';

class PublicStatistics {
  final int total;
  final Map<TreeCondition, int> conditions;
  final Map<String, int> species;
  final Map<String, int> districts;
  PublicStatistics._(this.total, this.conditions, this.species, this.districts);
  factory PublicStatistics.fromTrees(
    Iterable<TreeData> data, {
    String? kecamatan,
  }) {
    String norm(String s) => s.trim().toLowerCase();
    final trees = data
        .where(
          (t) =>
              t.status == TreeStatus.verified &&
              (kecamatan == null || norm(t.kecamatan) == norm(kecamatan)),
        )
        .toList();
    final conditions = {for (final c in TreeCondition.values) c: 0};
    final species = <String, int>{};
    final speciesNames = <String, String>{};
    final districts = {for (final k in cirebonKecamatanList) k: 0};
    for (final t in trees) {
      conditions[t.condition] = conditions[t.condition]! + 1;
      final name = t.species.trim().isEmpty
          ? 'Tidak diketahui'
          : t.species.trim();
      final canonical = speciesNames.putIfAbsent(norm(name), () => name);
      species[canonical] = (species[canonical] ?? 0) + 1;
      final region = cirebonKecamatanList.where(
        (k) => norm(k) == norm(t.kecamatan),
      );
      final key = region.isEmpty
          ? 'Belum diisi / wilayah lainnya'
          : region.first;
      districts[key] = (districts[key] ?? 0) + 1;
    }
    Map<String, int> sorted(Map<String, int> map) {
      final entries = map.entries.toList()
        ..sort((a, b) {
          final count = b.value.compareTo(a.value);
          return count == 0
              ? a.key.toLowerCase().compareTo(b.key.toLowerCase())
              : count;
        });
      return Map.unmodifiable(Map.fromEntries(entries));
    }

    return PublicStatistics._(
      trees.length,
      Map.unmodifiable(conditions),
      sorted(species),
      sorted(districts),
    );
  }
  List<MapEntry<String, int>> topSpecies([int limit = 5]) {
    final entries = species.entries.toList();
    if (entries.length <= limit) return entries;
    final rest = entries.skip(limit).toList();
    return [
      ...entries.take(limit),
      MapEntry(
        'Jenis lainnya (${rest.length} jenis)',
        rest.fold<int>(0, (sum, e) => sum + e.value),
      ),
    ];
  }
}