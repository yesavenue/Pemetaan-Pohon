import 'dart:typed_data';

import 'package:excel/excel.dart';

import '../models/tree_data.dart';

String _formatDate(DateTime date) {
  const bulan = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'Mei',
    'Jun',
    'Jul',
    'Agu',
    'Sep',
    'Okt',
    'Nov',
    'Des',
  ];
  return '${date.day} ${bulan[date.month - 1]} ${date.year}';
}

/// Membangun file .xlsx dari daftar data pohon, mengembalikan byte-nya
/// (siap dipakai untuk trigger download atau disimpan).
Uint8List buildTreeExcelBytes(List<TreeData> trees) {
  final workbook = Excel.createExcel();
  final sheetName = workbook.getDefaultSheet()!;
  final sheet = workbook[sheetName];

  const headers = [
    'ID',
    'Jenis Pohon',
    'Kondisi',
    'Keterangan Kondisi',
    'Ranah Kewenangan',
    'Kecamatan',
    'Kelurahan',
    'Nama Jalan',
    'Latitude',
    'Longitude',
    'Status Verifikasi',
    'Surveyor',
    'Tanggal Input',
  ];
  sheet.appendRow(headers.map((h) => TextCellValue(h)).toList());

  for (final t in trees) {
    sheet.appendRow([
      TextCellValue(t.id),
      TextCellValue(t.species),
      TextCellValue(t.condition.label),
      TextCellValue(t.keteranganKondisi),
      TextCellValue(t.ranahKewenangan),
      TextCellValue(t.kecamatan),
      TextCellValue(t.kelurahan),
      TextCellValue(t.namaJalan),
      DoubleCellValue(t.latitude),
      DoubleCellValue(t.longitude),
      TextCellValue(
        t.status == TreeStatus.verified ? 'Terverifikasi' : 'Menunggu',
      ),
      TextCellValue(t.surveyorName),
      TextCellValue(_formatDate(t.timestamp)),
    ]);
  }

  final bytes = workbook.encode();
  return Uint8List.fromList(bytes!);
}