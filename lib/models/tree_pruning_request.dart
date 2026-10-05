import 'package:cloud_firestore/cloud_firestore.dart';

enum PruningStatus {
  menunggu,
  diverifikasi,
  diproses,
  selesai,
  ditolak;

  static PruningStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'diverifikasi':
        return PruningStatus.diverifikasi;
      case 'diproses':
        return PruningStatus.diproses;
      case 'selesai':
        return PruningStatus.selesai;
      case 'ditolak':
        return PruningStatus.ditolak;
      default:
        return PruningStatus.menunggu;
    }
  }

  String toMapString() => name;

  String get label {
    switch (this) {
      case PruningStatus.menunggu:
        return 'Menunggu';
      case PruningStatus.diverifikasi:
        return 'Diverifikasi';
      case PruningStatus.diproses:
        return 'Diproses';
      case PruningStatus.selesai:
        return 'Selesai';
      case PruningStatus.ditolak:
        return 'Ditolak';
    }
  }
}

class TreePruningRequest {
  final String id;
  final String requestNumber; // mis. REQ-000001

  // Data pemohon
  final String namaPemohon;
  final String alamatPemohon;
  final String nomorHp;
  final String emailPemohon;
  final String nik;

  // Data pohon yang dilaporkan
  final String alamatPohon;
  final String kecamatan;
  final String kelurahan;
  final String alasan;
  final double? latitude;
  final double? longitude;

  // Foto (base64, konsisten dengan pola penyimpanan data pohon surveyor)
  final String fotoPohonBase64;
  final String fotoKtpBase64;

  final PruningStatus status;
  final String alasanPenolakan;

  final DateTime createdAt;
  final DateTime updatedAt;

  TreePruningRequest({
    required this.id,
    required this.requestNumber,
    required this.namaPemohon,
    required this.alamatPemohon,
    required this.nomorHp,
    required this.emailPemohon,
    required this.nik,
    required this.alamatPohon,
    this.kecamatan = '',
    this.kelurahan = '',
    required this.alasan,
    this.latitude,
    this.longitude,
    required this.fotoPohonBase64,
    required this.fotoKtpBase64,
    this.status = PruningStatus.menunggu,
    this.alasanPenolakan = '',
    required this.createdAt,
    required this.updatedAt,
  });

  bool get hasLocation => latitude != null && longitude != null;

  factory TreePruningRequest.fromMap(String id, Map<String, dynamic> data) {
    return TreePruningRequest(
      id: id,
      requestNumber: data['requestNumber'] ?? '-',
      namaPemohon: data['namaPemohon'] ?? '',
      alamatPemohon: data['alamatPemohon'] ?? '',
      nomorHp: data['nomorHp'] ?? '',
      emailPemohon: data['emailPemohon'] ?? '',
      nik: data['nik'] ?? '',
      alamatPohon: data['alamatPohon'] ?? '',
      kecamatan: data['kecamatan'] ?? '',
      kelurahan: data['kelurahan'] ?? '',
      alasan: data['alasan'] ?? '',
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      fotoPohonBase64: data['fotoPohonBase64'] ?? '',
      fotoKtpBase64: data['fotoKtpBase64'] ?? '',
      status: PruningStatus.fromString(data['status'] ?? ''),
      alasanPenolakan: data['alasanPenolakan'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'requestNumber': requestNumber,
      'namaPemohon': namaPemohon,
      'alamatPemohon': alamatPemohon,
      'nomorHp': nomorHp,
      'emailPemohon': emailPemohon,
      'nik': nik,
      'alamatPohon': alamatPohon,
      'kecamatan': kecamatan,
      'kelurahan': kelurahan,
      'alasan': alasan,
      'latitude': latitude,
      'longitude': longitude,
      'fotoPohonBase64': fotoPohonBase64,
      'fotoKtpBase64': fotoKtpBase64,
      'status': status.toMapString(),
      'alasanPenolakan': alasanPenolakan,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}