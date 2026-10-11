import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/tree_data.dart';
import '../utils/geo_utils.dart';

class TreeService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const double duplicateRadiusMeters = 7;

  Stream<List<TreeData>> _watch(Query<Map<String, dynamic>> query) => query
      .snapshots()
      .map((s) => s.docs.map((d) => TreeData.fromMap(d.id, d.data())).toList());

  // Admin only. Surveyors must use the owner-constrained query below.
  Stream<List<TreeData>> streamTrees() =>
      _watch(_firestore.collection('trees'));
  Stream<List<TreeData>> streamPublicTrees() =>
      _watch(_firestore.collection('public_trees'));
  Stream<List<TreeData>> streamOwnTrees(String uid) => _watch(
    _firestore.collection('trees').where('surveyorId', isEqualTo: uid),
  );
  Stream<List<TreeData>> streamTree(String id) => _firestore
      .collection('trees')
      .doc(id)
      .snapshots()
      .map(
        (d) => d.exists ? [TreeData.fromMap(d.id, d.data()!)] : <TreeData>[],
      );

  Future<List<TreeData>> findNearbyTrees(
    double lat,
    double lng, {
    double radiusMeters = duplicateRadiusMeters,
  }) async {
    // Public verified trees plus own private submissions. No other surveyor's
    // private records are downloaded. Still a client-side distance scan.
    final public = await _firestore.collection('public_trees').get();
    final rows = {
      for (final d in public.docs) d.id: TreeData.fromMap(d.id, d.data()),
    };
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final own = await _firestore
          .collection('trees')
          .where('surveyorId', isEqualTo: uid)
          .get();
      for (final d in own.docs) {
        rows[d.id] = TreeData.fromMap(d.id, d.data());
      }
    }
    return rows.values
        .where(
          (t) =>
              distanceInMeters(lat, lng, t.latitude, t.longitude) <=
              radiusMeters,
        )
        .toList();
  }

  void _project(Transaction tx, String id, Map<String, dynamic> data) {
    final ref = _firestore.collection('public_trees').doc(id);
    if (data['status'] == 'verified' && !id.startsWith('dummy_tree_v1_')) {
      tx.set(ref, TreeData.fromMap(id, data).toPublicMap());
    } else {
      tx.delete(ref);
    }
  }

  Future<String?> createTree(TreeData tree) async {
    try {
      final ref = _firestore.collection('trees').doc();
      await _firestore.runTransaction((tx) async {
        final data = tree.toMap();
        tx.set(ref, data);
        _project(tx, ref.id, data);
      });
      return null;
    } catch (_) {
      return 'Gagal menyimpan pohon. Periksa koneksi dan izin akun.';
    }
  }

  // Compatibility entry point; the actual admin UI passes its reviewed snapshot
  // to reviewTree so a concurrent edit cannot silently overwrite the decision.
  Future<String?> setTreeStatus(String id, TreeStatus status) async {
    final doc = await _firestore.collection('trees').doc(id).get();
    if (!doc.exists) {
      return 'Pohon sudah tidak tersedia.';
    }
    return reviewTree(TreeData.fromMap(id, doc.data()!), status, '');
  }

  Future<String?> reviewTree(
    TreeData expected,
    TreeStatus status,
    String reason,
  ) async {
    if (status == TreeStatus.rejected && reason.trim().isEmpty) {
      return 'Tuliskan alasan perbaikan untuk surveyor.';
    }
    try {
      final ref = _firestore.collection('trees').doc(expected.id);
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists ||
            (doc.data()!['revision'] ?? 0) != expected.revision) {
          throw StateError('changed');
        }
        final data = {
          ...doc.data()!,
          'status': status.name,
          'rejectionReason': status == TreeStatus.rejected ? reason.trim() : '',
          'reviewedAt': FieldValue.serverTimestamp(),
          'reviewReadAt': null,
          'revision': expected.revision + 1,
        };
        tx.update(ref, data);
        // Projection only contains stable public fields, not server transforms.
        if (status == TreeStatus.verified &&
            !expected.id.startsWith('dummy_tree_v1_')) {
          tx.set(
            _firestore.collection('public_trees').doc(expected.id),
            TreeData.fromMap(
              expected.id,
              doc.data()!,
            ).copyWith(status: status).toPublicMap(),
          );
        } else {
          tx.delete(_firestore.collection('public_trees').doc(expected.id));
        }
      });
      return null;
    } on StateError {
      return 'Data berubah atau sudah dihapus. Tinjau ulang data terbaru.';
    } catch (_) {
      return 'Keputusan belum tersimpan. Periksa koneksi dan izin akun.';
    }
  }

  Future<String?> updateTree(TreeData tree) => _update(tree, resubmit: false);
  Future<String?> resubmitTree(TreeData tree) => _update(tree, resubmit: true);

  Future<String?> _update(TreeData tree, {required bool resubmit}) async {
    try {
      final ref = _firestore.collection('trees').doc(tree.id);
      await _firestore.runTransaction((tx) async {
        final doc = await tx.get(ref);
        if (!doc.exists || (doc.data()!['revision'] ?? 0) != tree.revision) {
          throw StateError('changed');
        }
        final data = {
          ...tree.toMap(),
          // Preserve acknowledgement from another screen/device.
          'reviewReadAt': doc.data()!['reviewReadAt'],
          'reviewedAt': doc.data()!['reviewedAt'],
          'rejectionReason': doc.data()!['rejectionReason'] ?? '',
          'revision': tree.revision + 1,
          if (resubmit) 'status': 'pending',
        };
        tx.update(ref, data);
        _project(tx, tree.id, data);
      });
      return null;
    } on StateError {
      return 'Data telah berubah. Buka ulang formulir sebelum menyimpan.';
    } catch (_) {
      return 'Gagal memperbarui pohon. Periksa koneksi dan izin akun.';
    }
  }

  Future<String?> markReviewRead(TreeData expected) async {
    try {
      await _firestore.runTransaction((tx) async {
        final ref = _firestore.collection('trees').doc(expected.id);
        final doc = await tx.get(ref);
        if (!doc.exists) {
          return;
        }
        final current = TreeData.fromMap(doc.id, doc.data()!);
        if (current.reviewedAt != expected.reviewedAt ||
            !current.hasUnreadReview) {
          return;
        }
        tx.update(ref, {'reviewReadAt': FieldValue.serverTimestamp()});
      });
      return null;
    } catch (_) {
      return 'Gagal menandai pesan dibaca. Silakan coba lagi.';
    }
  }

  Future<String?> deleteTree(String id) async {
    try {
      final batch = _firestore.batch();
      batch.delete(_firestore.collection('trees').doc(id));
      batch.delete(_firestore.collection('public_trees').doc(id));
      await batch.commit();
      return null;
    } catch (_) {
      return 'Gagal menghapus pohon. Periksa koneksi dan izin akun.';
    }
  }

  /// Admin-only, resumable backfill. Each tree is re-read transactionally to
  /// avoid publishing a record rejected/edited during migration.
  Future<int> rebuildPublicTrees() async {
    DocumentSnapshot<Map<String, dynamic>>? cursor;
    var count = 0;
    while (true) {
      Query<Map<String, dynamic>> query = _firestore
          .collection('trees')
          .orderBy(FieldPath.documentId)
          .limit(50);
      if (cursor != null) {
        query = query.startAfterDocument(cursor);
      }
      final page = await query.get();
      if (page.docs.isEmpty) {
        break;
      }
      for (final row in page.docs) {
        await _firestore.runTransaction((tx) async {
          final current = await tx.get(row.reference);
          if (current.exists) {
            _project(tx, row.id, current.data()!);
          } else {
            tx.delete(_firestore.collection('public_trees').doc(row.id));
          }
        });
        count++;
      }
      cursor = page.docs.last;
    }
    return count;
  }
}