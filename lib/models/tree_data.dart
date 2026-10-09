import 'package:cloud_firestore/cloud_firestore.dart';

enum TreeStatus {
  pending,
  verified;

  static TreeStatus fromString(String value) {
    switch (value.toLowerCase()) {
      case 'verified':
        return TreeStatus.verified;
      default:
        return TreeStatus.pending;
    }
  }

  String toMapString() => this == TreeStatus.verified ? 'verified' : 'pending';
}

enum TreeCondition {
  sehat,
  sakit,
  rawanTumbang;

  static TreeCondition fromString(String value) {
    switch (value.toLowerCase()) {
      case 'sakit':
        return TreeCondition.sakit;
      case 'rawantumbang':
      case 'rawan_tumbang':
      case 'rawan tumbang':
        return TreeCondition.rawanTumbang;
      default:
        return TreeCondition.sehat;
    }
  }

  String toMapString() => name;

  String get label {
    switch (this) {
      case TreeCondition.sehat:
        return 'Sehat';
      case TreeCondition.sakit:
        return 'Sakit';
      case TreeCondition.rawanTumbang:
        return 'Rawan Tumbang';
    }
  }
}

class TreeData {
  final String id;
  final double latitude;
  final double longitude;
  final String photoBase64;
  final String surveyorId;
  final String surveyorName;
  final String species;
  final String kecamatan;
  final String kelurahan;
  final String namaJalan;
  final String ranahKewenangan;
  final TreeCondition condition;
  final String keteranganKondisi;
  final DateTime timestamp;
  final TreeStatus status;
  final bool qrGenerated;

  TreeData({
    required this.id,
    required this.latitude,
    required this.longitude,
    required this.photoBase64,
    required this.surveyorId,
    required this.surveyorName,
    required this.species,
    this.kecamatan = '',
    this.kelurahan = '',
    this.namaJalan = '',
    this.ranahKewenangan = '',
    this.condition = TreeCondition.sehat,
    this.keteranganKondisi = '',
    required this.timestamp,
    this.status = TreeStatus.pending,
    this.qrGenerated = false,
  });

  factory TreeData.fromMap(String id, Map<String, dynamic> data) {
    return TreeData(
      id: id,
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      photoBase64: data['photoBase64'] ?? '',
      surveyorId: data['surveyorId'] ?? '',
      surveyorName: data['surveyorName'] ?? '',
      species: (data['species'] as String?)?.trim().isNotEmpty == true
          ? data['species']
          : 'Tidak diketahui',
      kecamatan: data['kecamatan'] ?? '',
      kelurahan: data['kelurahan'] ?? '',
      namaJalan: data['namaJalan'] ?? '',
      ranahKewenangan: (data['ranahKewenangan'] as String?) ?? '',
      condition: TreeCondition.fromString(data['condition'] ?? ''),
      keteranganKondisi: data['keteranganKondisi'] ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: TreeStatus.fromString(data['status'] ?? ''),
      qrGenerated: data['qrGenerated'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      'photoBase64': photoBase64,
      'surveyorId': surveyorId,
      'surveyorName': surveyorName,
      'species': species,
      'kecamatan': kecamatan,
      'kelurahan': kelurahan,
      'namaJalan': namaJalan,
      'ranahKewenangan': ranahKewenangan,
      'condition': condition.toMapString(),
      'keteranganKondisi': keteranganKondisi,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status.toMapString(),
      'qrGenerated': qrGenerated,
    };
  }

  TreeData copyWith({
    double? latitude,
    double? longitude,
    String? photoBase64,
    String? species,
    String? kecamatan,
    String? kelurahan,
    String? namaJalan,
    String? ranahKewenangan,
    TreeCondition? condition,
    String? keteranganKondisi,
    TreeStatus? status,
  }) {
    return TreeData(
      id: id,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      photoBase64: photoBase64 ?? this.photoBase64,
      surveyorId: surveyorId,
      surveyorName: surveyorName,
      species: species ?? this.species,
      kecamatan: kecamatan ?? this.kecamatan,
      kelurahan: kelurahan ?? this.kelurahan,
      namaJalan: namaJalan ?? this.namaJalan,
      ranahKewenangan: ranahKewenangan ?? this.ranahKewenangan,
      condition: condition ?? this.condition,
      keteranganKondisi: keteranganKondisi ?? this.keteranganKondisi,
      timestamp: timestamp,
      status: status ?? this.status,
      qrGenerated: qrGenerated,
    );
  }
}