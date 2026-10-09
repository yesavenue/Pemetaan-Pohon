import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/app_user.dart';
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
    final refs = [
      for (final item in samples) _db.collection('trees').doc(item.id),
    ];
    return _db.runTransaction<int>((transaction) async {
      final existing = await Future.wait([
        for (final ref in refs) transaction.get(ref),
      ]);
      var count = 0;
      for (var i = 0; i < samples.length; i++) {
        if (existing[i].exists) {
          continue;
        }
        final payload = Map<String, Object>.from(samples[i].data);
        payload['timestamp'] = Timestamp.fromDate(
          payload['timestamp'] as DateTime,
        );
        transaction.set(refs[i], payload);
        count++;
      }
      return count;
    });
  }

  Future<int> remove(AppUser admin) async {
    _checkAdmin(admin);
    final refs = [
      for (var i = 0; i < demoTreeCount; i++)
        _db.collection('trees').doc(demoTreeId(admin.uid, i)),
    ];
    return _db.runTransaction<int>((transaction) async {
      final existing = await Future.wait([
        for (final ref in refs) transaction.get(ref),
      ]);
      var count = 0;
      for (var i = 0; i < existing.length; i++) {
        if (!isOwnedDemoTree(existing[i].data(), admin.uid)) {
          continue;
        }
        transaction.delete(refs[i]);
        count++;
      }
      return count;
    });
  }
}