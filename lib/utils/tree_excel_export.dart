import 'dart:typed_data';
import 'package:excel/excel.dart';
import '../models/tree_data.dart';
import 'excel_report_layout.dart';

/// Template laporan dibangun otomatis pada setiap ekspor; tanpa aset tambahan.
/// Semua teks pengguna ditulis sebagai teks, bukan formula Excel.
Uint8List buildTreeExcelBytes(
  List<TreeData> trees, {
  String scope = 'Data yang dipilih untuk ekspor',
  String preparedBy = 'Admin',
  DateTime? exportedAt,
}) {
  final workbook = Excel.createExcel();
  workbook.rename(workbook.getDefaultSheet()!, 'Inventaris Pohon');
  final sheet = workbook['Inventaris Pohon'];
  final navy = ExcelColor.fromHexString('FF173C36');
  final muted = ExcelColor.fromHexString('FF52645F');
  CellStyle style({
    bool bold = false,
    int size = 11,
    ExcelColor? background,
    ExcelColor? foreground,
    NumFormat? format,
  }) => CellStyle(
    fontFamily: 'Calibri',
    fontSize: size,
    bold: bold,
    fontColorHex: foreground ?? navy,
    backgroundColorHex: background ?? ExcelColor.white,
    verticalAlign: VerticalAlign.Center,
    textWrapping: TextWrapping.WrapText,
    numberFormat: format ?? NumFormat.standard_0,
  );
  void cell(int row, int col, CellValue value, CellStyle cellStyle) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      ..value = value
      ..cellStyle = cellStyle;
  }

  void banner(int row, String value, CellStyle cellStyle, double height) {
    sheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: row),
      CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: row),
    );
    for (var col = 0; col < 13; col++) {
      sheet
              .cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
              .cellStyle =
          cellStyle;
    }
    cell(row, 0, TextCellValue(value), cellStyle);
    sheet.setRowHeight(row, height);
  }

  final now = (exportedAt ?? DateTime.now()).toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  banner(
    0,
    'LAPORAN INVENTARIS POHON',
    style(bold: true, size: 22, background: navy, foreground: ExcelColor.white),
    42,
  );
  banner(
    1,
    'PEMETAAN POHON • KOTA CIREBON',
    style(bold: true, foreground: muted),
    25,
  );
  banner(
    2,
    'Diekspor: ${two(now.day)}/${two(now.month)}/${now.year} '
    '${two(now.hour)}:${two(now.minute)} (waktu lokal perangkat) • Oleh: $preparedBy',
    style(foreground: muted),
    28,
  );
  banner(3, 'Cakupan: $scope', style(), 44);
  banner(
    4,
    'Total: ${trees.length} pohon  •  Sehat: ${trees.where((t) => t.condition == TreeCondition.sehat).length}'
    '  •  Sakit: ${trees.where((t) => t.condition == TreeCondition.sakit).length}'
    '  •  Rawan tumbang: ${trees.where((t) => t.condition == TreeCondition.rawanTumbang).length}',
    style(bold: true, background: ExcelColor.fromHexString('FFE8F1EC')),
    30,
  );
  banner(
    5,
    'Ringkasan mengikuti data ekspor. Tanggal input memakai waktu lokal perangkat. '
    'Status verifikasi tersedia pada setiap baris.',
    style(foreground: muted, size: 10),
    26,
  );
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
  const widths = <double>[24, 25, 20, 42, 25, 22, 22, 42, 16, 16, 21, 28, 23];
  for (var c = 0; c < headers.length; c++) {
    sheet.setColumnWidth(c, widths[c]);
    cell(
      7,
      c,
      TextCellValue(headers[c]),
      style(bold: true, background: navy, foreground: ExcelColor.white),
    );
  }
  sheet.setRowHeight(7, 32);
  for (var i = 0; i < trees.length; i++) {
    final t = trees[i];
    final values = <CellValue>[
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
      DateTimeCellValue.fromDateTime(t.timestamp.toLocal()),
    ];
    final background = i.isEven
        ? ExcelColor.white
        : ExcelColor.fromHexString('FFF3F7F4');
    for (var c = 0; c < values.length; c++) {
      cell(
        i + 8,
        c,
        values[c],
        style(
          background: background,
          format: c == 12
              ? NumFormat.custom(formatCode: 'dd/mm/yyyy hh:mm')
              : c == 8 || c == 9
              ? NumFormat.custom(formatCode: '0.000000')
              : null,
        ),
      );
    }
    final colors = switch (t.condition) {
      TreeCondition.sehat => ('FFE3F2E7', 'FF176333'),
      TreeCondition.sakit => ('FFFFF3CD', 'FF785900'),
      TreeCondition.rawanTumbang => ('FFFCE4E4', 'FFA62828'),
    };
    cell(
      i + 8,
      2,
      values[2],
      style(
        bold: true,
        background: ExcelColor.fromHexString(colors.$1),
        foreground: ExcelColor.fromHexString(colors.$2),
      ),
    );
    // Do not fix data-row heights: users can AutoFit long field notes in Excel.
  }
  if (trees.isEmpty) {
    banner(
      8,
      'Tidak ada data dalam cakupan ekspor ini.',
      style(foreground: muted),
      30,
    );
  }
  final bytes = workbook.encode();
  if (bytes == null) throw StateError('Laporan Excel gagal dibuat.');
  return applyExcelReportLayout(bytes, trees.length);
}