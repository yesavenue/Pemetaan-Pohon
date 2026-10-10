import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xml/xml.dart';

import 'package:pemetaan_pohon/models/tree_data.dart';
import 'package:pemetaan_pohon/utils/tree_excel_export.dart';

void main() {
  test(
    'Excel tanpa freeze tetap menyimpan filter, print titles, area dan landscape',
    () {
      final archive = ZipDecoder().decodeBytes(buildTreeExcelBytes([]));

      final worksheet = archive.files.firstWhere(
        (f) => f.name.startsWith('xl/worksheets/') && f.name.endsWith('.xml'),
      );

      final sheet = XmlDocument.parse(
        utf8.decode(worksheet.content as List<int>),
      );

      // Seluruh baris dan kolom dapat digulir.
      expect(sheet.findAllElements('pane'), isEmpty);

      expect(
        sheet.findAllElements('autoFilter').single.getAttribute('ref'),
        'A8:M8',
      );

      final setup = sheet.findAllElements('pageSetup').single;
      expect(setup.getAttribute('orientation'), 'landscape');
      expect(setup.getAttribute('fitToWidth'), '1');
      expect(setup.getAttribute('fitToHeight'), '0');

      final file = archive.files.firstWhere(
        (f) => f.name == 'xl/workbook.xml',
      );

      final book = XmlDocument.parse(
        utf8.decode(file.content as List<int>),
      );

      final names = {
        for (final e in book.findAllElements('definedName'))
          e.getAttribute('name'): e.innerText,
      };

      // Header tabel tetap berulang saat dicetak.
      expect(
        names['_xlnm.Print_Titles'],
        "'Inventaris Pohon'!\$8:\$8",
      );
      expect(
        names['_xlnm.Print_Area'],
        "'Inventaris Pohon'!\$A\$1:\$M\$9",
      );
    },
  );

  test(
    'Laporan mempertahankan data, tipe koordinat, tanggal dan teks literal',
    () {
      final trees = List.generate(
        60,
        (i) => TreeData(
          id: 'id-$i',
          latitude: -6.7183,
          longitude: 108.5522,
          photoBase64: '',
          surveyorId: 's',
          surveyorName: 'Surveyor',
          species: i == 0 ? '=1+1' : 'Mahoni',
          condition: TreeCondition.values[i % 3],
          keteranganKondisi: 'Catatan & pemeriksaan',
          timestamp: DateTime(2026, 10, 9, 8, 30),
          status: TreeStatus.verified,
        ),
      );

      final bytes = buildTreeExcelBytes(
        trees,
        scope: 'Hasil filter • Kesambi',
        preparedBy: 'Admin Uji',
        exportedAt: DateTime(2026, 10, 9, 9),
      );

      final workbook = Excel.decodeBytes(bytes);
      final sheet = workbook['Inventaris Pohon'];

      expect(sheet.maxRows, 68);

      expect(
        sheet.cell(CellIndex.indexByString('A1')).value,
        TextCellValue('LAPORAN INVENTARIS POHON'),
      );
      expect(
        sheet.cell(CellIndex.indexByString('A4')).value.toString(),
        contains('Kesambi'),
      );
      expect(
        sheet.cell(CellIndex.indexByString('A5')).value.toString(),
        contains('Sehat: 20'),
      );

      // Teks berawalan "=" harus tetap berupa teks, bukan formula.
      expect(
        sheet.cell(CellIndex.indexByString('B9')).value,
        TextCellValue('=1+1'),
      );

      expect(
        sheet.cell(CellIndex.indexByString('I9')).value,
        DoubleCellValue(-6.7183),
      );
      expect(
        sheet.cell(CellIndex.indexByString('J9')).value,
        DoubleCellValue(108.5522),
      );
      expect(
        sheet.cell(CellIndex.indexByString('M9')).value,
        isA<DateTimeCellValue>(),
      );
      expect(
        sheet.cell(CellIndex.indexByString('A68')).value,
        TextCellValue('id-59'),
      );

      // Warna kondisi berbeda tetap dipertahankan.
      expect(
        sheet.cell(CellIndex.indexByString('C9')).cellStyle?.backgroundColor,
        isNot(
          sheet.cell(CellIndex.indexByString('C10')).cellStyle?.backgroundColor,
        ),
      );
    },
  );

  test('Ekspor kosong tetap menghasilkan laporan yang bisa dibuka', () {
    final sheet = Excel.decodeBytes(
      buildTreeExcelBytes([]),
    )['Inventaris Pohon'];

    expect(
      sheet.cell(CellIndex.indexByString('A9')).value.toString(),
      contains('Tidak ada data'),
    );
  });
}