import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/tree_pruning_request.dart';

class PruningReceipt {
  final String requestNumber;
  final String accessCode;
  const PruningReceipt(this.requestNumber, this.accessCode);
  String get text => 'BUKTI PENGAJUAN PERAPIHAN POHON KOTA CIREBON\n'
      'Nomor permohonan: $requestNumber\nKode akses rahasia: $accessCode\n\n'
      'Buka menu Lacak Permohonan dan masukkan kode akses di atas.\n'
      'Simpan bukti ini secara pribadi. Kode memberi akses ke status permohonan.\n'
      'Bukti pengajuan bukan persetujuan pelaksanaan perapihan.';
}

class PruningRequestService {
  final FirebaseFirestore _firestore;
  PruningReceipt? lastReceipt;
  PruningRequestService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  static bool validAccessCode(String code) => RegExp(r'^([a-z2-7]{16}|[a-f0-9]{64})$').hasMatch(code);

  Future<String> createRequest(TreePruningRequest request) async {
    lastReceipt = null;
    final random = Random.secure();
    const alphabet = 'abcdefghijklmnopqrstuvwxyz234567';
    final code = List.generate(16, (_) => alphabet[random.nextInt(alphabet.length)]).join();
    final counter = _firestore.collection('counters').doc('tree_pruning_requests');
    final privateRef = _firestore.collection('tree_pruning_requests').doc(code);
    final trackingRef = _firestore.collection('pruning_tracking').doc(code);
    final number = await _firestore.runTransaction<String>((tx) async {
      final snapshot = await tx.get(counter);
      final next = ((snapshot.data()?['value'] as num?)?.toInt() ?? 0) + 1;
      final number = 'REQ-${next.toString().padLeft(6, '0')}';
      final time = FieldValue.serverTimestamp();
      tx.set(counter, {'value': next});
      tx.set(privateRef, {...request.toMap(), 'requestNumber': number,
        'status': 'menunggu', 'alasanPenolakan': '', 'createdAt': time, 'updatedAt': time});
      tx.set(trackingRef, {'requestNumber': number, 'status': 'menunggu', 'createdAt': time, 'updatedAt': time});
      tx.set(trackingRef.collection('events').doc('submitted'), {'status': 'menunggu', 'at': time});
      return number;
    });
    lastReceipt = PruningReceipt(number, code);
    return number;
  }

  Future<Map<String, dynamic>?> lookup(String code) async {
    if (!validAccessCode(code)) throw const FormatException('Gunakan kode akses 16 karakter atau kode lama 64 karakter.');
    final snapshot = await _firestore.collection('pruning_tracking').doc(code).get();
    return snapshot.data();
  }

  Future<List<Map<String, dynamic>>> history(String code) async {
    if (!validAccessCode(code)) throw const FormatException('Kode akses tidak valid.');
    final snapshot = await _firestore.collection('pruning_tracking').doc(code)
        .collection('events').orderBy('at', descending: true).limit(100).get();
    return snapshot.docs.map((d) => d.data()).toList();
  }

  Stream<List<TreePruningRequest>> streamRequests() => _firestore
      .collection('tree_pruning_requests').orderBy('createdAt', descending: true)
      .snapshots().map((s) => s.docs.map((d) => TreePruningRequest.fromMap(d.id, d.data())).toList());

  Future<String?> updateStatus(String id, PruningStatus status, {String alasanPenolakan = ''}) async {
    if (status == PruningStatus.ditolak && alasanPenolakan.trim().isEmpty) return 'Tuliskan alasan penolakan.';
    try {
      final privateRef = _firestore.collection('tree_pruning_requests').doc(id);
      final trackingRef = _firestore.collection('pruning_tracking').doc(id);
      final eventRef = trackingRef.collection('events').doc();
      await _firestore.runTransaction((tx) async {
        final old = await tx.get(privateRef);
        final tracking = await tx.get(trackingRef);
        if (!old.exists) throw StateError('Permohonan sudah tidak tersedia.');
        final time = FieldValue.serverTimestamp();
        tx.update(privateRef, {'status': status.name,
          'alasanPenolakan': status == PruningStatus.ditolak ? alasanPenolakan.trim() : '', 'updatedAt': time});
        // Permohonan lama tetap dapat dikelola, tanpa membuat riwayat fiktif.
        if (tracking.exists) {
          tx.update(trackingRef, {'status': status.name, 'updatedAt': time});
          if (old.data()?['status'] != status.name) {
            tx.set(eventRef, {'status': status.name, 'at': time});
          }
        }
      });
      return null;
    } catch (_) {
      return 'Status belum tersimpan. Periksa koneksi dan izin akun, lalu coba lagi.';
    }
  }
}