import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tree_data.dart';
import '../utils/geo_utils.dart';

class TreeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Ambang batas jarak (meter) untuk dianggap "kemungkinan pohon yang sama".
  // Disesuaikan dengan akurasi GPS HP yang umumnya 3-10 meter.
  static const double duplicateRadiusMeters = 7;

  // Cek apakah ada pohon lain yang sudah tercatat dalam radius dekat.
  // CATATAN SKALABILITAS: ini menarik seluruh koleksi 'trees' lalu
  // menghitung jarak di sisi aplikasi, karena Firestore tidak punya query
  // radius geospasial bawaan tanpa geohashing. Aman untuk skala ratusan-
  // ribuan data; kalau data sudah puluhan ribu, ganti dengan pendekatan
  // geohash supaya tidak boros pembacaan data.
  Future<List<TreeData>> findNearbyTrees(double lat, double lng,
      {double radiusMeters = duplicateRadiusMeters}) async {
    final snapshot = await _firestore.collection('trees').get();
    final trees = snapshot.docs.map((d) => TreeData.fromMap(d.id, d.data())).toList();
    return trees
        .where((t) => distanceInMeters(lat, lng, t.latitude, t.longitude) <= radiusMeters)
        .toList();
  }

  Future<String?> createTree(TreeData tree) async {
    try {
      await _firestore.collection('trees').add(tree.toMap());
      return null;
    } catch (e) {
      return 'Gagal menyimpan data pohon: ${e.toString()}';
    }
  }

  Stream<List<TreeData>> streamTrees() {
    return _firestore.collection('trees').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => TreeData.fromMap(doc.id, doc.data())).toList();
    });
  }

  Future<String?> setTreeStatus(String id, TreeStatus status) async {
    try {
      await _firestore.collection('trees').doc(id).update({
        'status': status.toMapString(),
      });
      return null;
    } catch (e) {
      return 'Gagal mengubah status verifikasi: ${e.toString()}';
    }
  }

  Future<String?> updateTree(TreeData tree) async {
    try {
      await _firestore.collection('trees').doc(tree.id).update(tree.toMap());
      return null;
    } catch (e) {
      return 'Gagal memperbarui data pohon: ${e.toString()}';
    }
  }

  Future<String?> deleteTree(String id) async {
    try {
      await _firestore.collection('trees').doc(id).delete();
      return null;
    } catch (e) {
      return 'Gagal menghapus data pohon: ${e.toString()}';
    }
  }
}