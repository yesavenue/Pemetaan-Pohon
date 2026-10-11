import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
import '../models/tree_data.dart';
import '../utils/demo_tree_seed.dart';

/// Uses the signed-in client and existing rules, never Admin SDK credentials.
class DemoTreeService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  void _checkAdmin(AppUser admin) {
    if (admin.role != UserRole.admin || !admin.isActive) {
      throw StateError('Hanya admin aktif yang dapat mengelola data contoh.');
    }
  }

  Future<int> create(AppUser admin, Map<String, String> photos) async {
    _checkAdmin(admin);
    final samples = buildDemoTreeSeed(
      uid: admin.uid,
      adminName: admin.name,
      now: DateTime.now(),
      photos: photos,
    );
    var count = 0;
    // One tree and its projection per transaction: stays below rules access limits.
    for (final sample in samples) {
      final ref = _db.collection('trees').doc(sample.id);
      count += await _db.runTransaction<int>((transaction) async {
        final existing = await transaction.get(ref);
        final legacy = await transaction.get(
          _db
              .collection('trees')
              .doc(legacyDemoTreeId(admin.uid, samples.indexOf(sample))),
        );
        if (existing.exists || legacy.exists) {
          return 0;
        }
        final payload = Map<String, dynamic>.from(sample.data);
        payload['timestamp'] = Timestamp.fromDate(
          payload['timestamp'] as DateTime,
        );
        final tree = TreeData.fromMap(sample.id, payload);
        transaction.set(ref, tree.toMap());
        transaction.set(
          _db.collection('public_trees').doc(sample.id),
          tree.toPublicMap(),
        );
        return 1;
      });
    }
    return count;
  }

  Future<int> remove(AppUser admin) async {
    _checkAdmin(admin);
    var count = 0;
    final ids = [
      for (var i = 0; i < demoTreeCount; i++) ...[
        demoTreeId(admin.uid, i),
        legacyDemoTreeId(admin.uid, i),
      ],
    ];
    for (final id in ids) {
      final ref = _db.collection('trees').doc(id);
      count += await _db.runTransaction<int>((transaction) async {
        final existing = await transaction.get(ref);
        if (!isOwnedDemoTree(existing.data(), admin.uid)) {
          return 0;
        }
        transaction.delete(ref);
        transaction.delete(_db.collection('public_trees').doc(ref.id));
        return 1;
      });
    }
    return count;
  }
}