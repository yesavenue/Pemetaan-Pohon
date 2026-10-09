import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import '../models/tree_data.dart';

class PublicMapFilters {
  final String? kecamatan;
  final String? kelurahan;
  final String species;
  final Set<TreeCondition> conditions;
  final bool newestFirst;
  const PublicMapFilters({
    this.kecamatan,
    this.kelurahan,
    this.species = 'Semua',
    this.conditions = const {},
    this.newestFirst = true,
  });
  int get activeCount =>
      (kecamatan == null ? 0 : 1) +
      (kelurahan == null ? 0 : 1) +
      (species == 'Semua' ? 0 : 1) +
      (conditions.isEmpty ? 0 : 1);
  PublicMapFilters copyWith({
    String? kecamatan,
    bool clearKecamatan = false,
    String? kelurahan,
    bool clearKelurahan = false,
    String? species,
    Set<TreeCondition>? conditions,
    bool? newestFirst,
  }) => PublicMapFilters(
    kecamatan: clearKecamatan ? null : kecamatan ?? this.kecamatan,
    kelurahan: clearKelurahan ? null : kelurahan ?? this.kelurahan,
    species: species ?? this.species,
    conditions: Set.unmodifiable(conditions ?? this.conditions),
    newestFirst: newestFirst ?? this.newestFirst,
  );
}

bool hasPublicMapCoordinates(TreeData t) =>
    t.latitude.isFinite &&
    t.longitude.isFinite &&
    t.latitude >= -90 &&
    t.latitude <= 90 &&
    t.longitude >= -180 &&
    t.longitude <= 180;

/// UI session state only; never writes to Firestore.
class PublicMapState extends ChangeNotifier {
  static const defaultCenter = LatLng(-6.7183, 108.5522);
  List<TreeData> _trees = [];
  List<TreeData>? _visibleCache;
  String _query = '';
  PublicMapFilters _filters = const PublicMapFilters();
  String? _selectedId;
  LatLng center = defaultCenter;
  double zoom = 13;
  String get query => _query;
  PublicMapFilters get filters => _filters;
  String? get selectedId => _selectedId;
  List<TreeData> get verifiedTrees => List.unmodifiable(_trees);
  List<TreeData> get visibleTrees {
    if (_visibleCache != null) return _visibleCache!;
    String norm(String s) => s.trim().toLowerCase();
    final q = norm(_query);
    final result = _trees
        .where(
          (t) =>
              (_filters.kecamatan == null ||
                  norm(t.kecamatan) == norm(_filters.kecamatan!)) &&
              (_filters.kelurahan == null ||
                  norm(t.kelurahan) == norm(_filters.kelurahan!)) &&
              (_filters.species == 'Semua' ||
                  norm(t.species) == norm(_filters.species)) &&
              (_filters.conditions.isEmpty ||
                  _filters.conditions.contains(t.condition)) &&
              (q.isEmpty ||
                  [
                    t.species,
                    t.namaJalan,
                    t.kecamatan,
                    t.kelurahan,
                    t.condition.label,
                  ].any((s) => norm(s).contains(q))),
        )
        .toList();
    result.sort((a, b) {
      final byTime = _filters.newestFirst
          ? b.timestamp.compareTo(a.timestamp)
          : a.timestamp.compareTo(b.timestamp);
      return byTime == 0 ? a.id.compareTo(b.id) : byTime;
    });
    return _visibleCache = List.unmodifiable(result);
  }

  List<TreeData> get mappedTrees =>
      visibleTrees.where(hasPublicMapCoordinates).toList();
  TreeData? get selectedTree {
    for (final t in visibleTrees) {
      if (t.id == _selectedId) return t;
    }
    return null;
  }

  void _reconcileSelection() {
    if (_selectedId != null && !visibleTrees.any((t) => t.id == _selectedId)) {
      _selectedId = null;
    }
  }

  void setTrees(List<TreeData> trees) {
    _trees = trees.where((t) => t.status == TreeStatus.verified).toList();
    _visibleCache = null;
    _reconcileSelection();
    notifyListeners();
  }

  void setQuery(String value) {
    _query = value;
    _visibleCache = null;
    _reconcileSelection();
    notifyListeners();
  }

  void setFilters(PublicMapFilters value) {
    _filters = value.copyWith();
    _visibleCache = null;
    _reconcileSelection();
    notifyListeners();
  }

  void toggleCondition(TreeCondition value) {
    final conditions = {..._filters.conditions};
    if (!conditions.remove(value)) conditions.add(value);
    setFilters(_filters.copyWith(conditions: conditions));
  }

  void resetFilters() {
    _query = '';
    _filters = const PublicMapFilters();
    _visibleCache = null;
    _reconcileSelection();
    notifyListeners();
  }

  void select(String id) {
    if (!visibleTrees.any((t) => t.id == id)) return;
    _selectedId = id;
    notifyListeners();
  }

  void clearSelection() {
    _selectedId = null;
    notifyListeners();
  }
}