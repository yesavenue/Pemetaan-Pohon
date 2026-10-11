import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/view_models/public_map_state.dart';

void main() {
  test('Pencarian ID tetap menghormati verifikasi dan filter kondisi', () {
    final state = PublicMapState();
    addTearDown(state.dispose);
    TreeData row(String id, TreeStatus status, TreeCondition condition) =>
        TreeData(
          id: id,
          species: 'Mahoni',
          latitude: -6.7,
          longitude: 108.5,
          photoBase64: '',
          surveyorId: 's',
          surveyorName: 'Surveyor Uji',
          timestamp: DateTime(2026),
          status: status,
          condition: condition,
        );
    state.setTrees([
      row('CRB-001', TreeStatus.verified, TreeCondition.sehat),
      row('CRB-002', TreeStatus.verified, TreeCondition.sakit),
      row('CRB-003', TreeStatus.pending, TreeCondition.sehat),
    ]);
    state.setQuery(' crb-001 ');
    expect(state.visibleTrees.map((t) => t.id), ['CRB-001']);
    state.setFilters(const PublicMapFilters(conditions: {TreeCondition.sakit}));
    expect(state.visibleTrees, isEmpty);
    state.resetFilters();
    state.setQuery('CRB-003');
    expect(state.visibleTrees, isEmpty);
  });

  test('Menutup pilihan dan mengganti filter mempertahankan posisi peta', () {
    final state = PublicMapState();
    addTearDown(state.dispose);
    state.setTrees([
      TreeData(
        id: '1',
        species: 'Mahoni',
        latitude: -6.7,
        longitude: 108.5,
        photoBase64: '',
        surveyorId: 's',
        surveyorName: 'Surveyor Uji',
        timestamp: DateTime(2026),
        status: TreeStatus.verified,
      ),
    ]);
    state.select('1');
    state.center = const LatLng(-6.72, 108.56);
    state.zoom = 15;
    state.clearSelection();
    state.setQuery('tidak ditemukan');
    state.resetFilters();
    expect(state.selectedId, isNull);
    expect(state.center.latitude, -6.72);
    expect(state.center.longitude, 108.56);
    expect(state.zoom, 15);
  });
  test(
    'State peta public tidak menyimpan identitas surveyor untuk tampilan',
    () {
      final state = PublicMapState();
      addTearDown(state.dispose);
      final original = TreeData(
        id: 'pohon-privasi',
        latitude: -6.7,
        longitude: 108.5,
        photoBase64: '',
        surveyorId: 'uid-rahasia',
        surveyorName: 'Nama Privat',
        species: 'Mahoni',
        timestamp: DateTime(2026),
        status: TreeStatus.verified,
      );
      state.setTrees([original]);
      state.select(original.id);
      expect(state.selectedTree!.surveyorId, isEmpty);
      expect(state.selectedTree!.surveyorName, isEmpty);
      expect(state.selectedTree!.id, original.id);
      expect(original.surveyorName, 'Nama Privat');
      state.setQuery('Nama Privat');
      expect(state.visibleTrees, isEmpty);
    },
  );
}