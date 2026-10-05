import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/tree_pruning_request.dart';

class PruningRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Nomor permohonan berurutan (REQ-000001, dst) dibuat lewat transaksi
  // atomik pada dokumen counter, supaya tidak ada nomor yang bentrok
  // walau ada beberapa pengajuan bersamaan.
  Future<String> _getNextRequestNumber() async {
    final counterRef = _firestore.collection('counters').doc('tree_pruning_requests');
    return _firestore.runTransaction<String>((transaction) async {
      final snapshot = await transaction.get(counterRef);
      final current = (snapshot.data()?['value'] as num?)?.toInt() ?? 0;
      final next = current + 1;
      transaction.set(counterRef, {'value': next});
      return 'REQ-${next.toString().padLeft(6, '0')}';
    });
  }

  /// Membuat permohonan baru. Mengembalikan nomor permohonan (mis.
  /// "REQ-000001") jika berhasil, atau melempar exception jika gagal
  /// (ditangkap oleh pemanggil).
  Future<String> createRequest(TreePruningRequest request) async {
    final requestNumber = await _getNextRequestNumber();
    final withNumber = TreePruningRequest(
      id: '',
      requestNumber: requestNumber,
      namaPemohon: request.namaPemohon,
      alamatPemohon: request.alamatPemohon,
      nomorHp: request.nomorHp,
      emailPemohon: request.emailPemohon,
      nik: request.nik,
      alamatPohon: request.alamatPohon,
      kecamatan: request.kecamatan,
      kelurahan: request.kelurahan,
      alasan: request.alasan,
      latitude: request.latitude,
      longitude: request.longitude,
      fotoPohonBase64: request.fotoPohonBase64,
      fotoKtpBase64: request.fotoKtpBase64,
      status: PruningStatus.menunggu,
      createdAt: request.createdAt,
      updatedAt: request.updatedAt,
    );
    await _firestore.collection('tree_pruning_requests').add(withNumber.toMap());
    return requestNumber;
  }

  Stream<List<TreePruningRequest>> streamRequests() {
    return _firestore
        .collection('tree_pruning_requests')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((d) => TreePruningRequest.fromMap(d.id, d.data())).toList());
  }

  Future<String?> updateStatus(String id, PruningStatus status, {String alasanPenolakan = ''}) async {
    try {
      await _firestore.collection('tree_pruning_requests').doc(id).update({
        'status': status.toMapString(),
        'alasanPenolakan': alasanPenolakan,
        'updatedAt': Timestamp.fromDate(DateTime.now()),
      });
      return null;
    } catch (e) {
      return 'Gagal mengubah status: ${e.toString()}';
    }
  }
}