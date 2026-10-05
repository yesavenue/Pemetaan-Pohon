import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import '../models/tree_pruning_request.dart';

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');

const _rFonts = '<w:rFonts w:ascii="Times New Roman" w:hAnsi="Times New Roman" w:cs="Times New Roman"/>';
const _fontSize = '<w:sz w:val="24"/><w:szCs w:val="24"/>'; // 24 half-points = 12pt

String _pPr({String? align}) {
  final jc = align != null ? '<w:jc w:val="$align"/>' : '';
  // line="360" + lineRule="auto" = spasi baris 1,5 (240 = single spacing)
  // before/after = 0 -> tidak ada spasi tambahan sebelum/sesudah paragraf
  return '<w:pPr>$jc<w:spacing w:before="0" w:after="0" w:line="360" w:lineRule="auto"/></w:pPr>';
}

String _p(String text, {String? align, bool bold = false}) {
  final boldTag = bold ? '<w:b/><w:bCs/>' : '';
  final rPr = '<w:rPr>$_rFonts$_fontSize$boldTag</w:rPr>';
  return '<w:p>${_pPr(align: align)}<w:r>$rPr<w:t xml:space="preserve">${_esc(text)}</w:t></w:r></w:p>';
}

String get _emptyP => '<w:p>${_pPr()}</w:p>';

String _formatDateLong(DateTime date) {
  const bulan = [
    'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
    'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember',
  ];
  return '${date.day} ${bulan[date.month - 1]} ${date.year}';
}

/// Membangun surat permohonan perapihan/pemangkasan pohon (.docx) sesuai
/// format resmi DPRKP, diisi dari data permohonan yang dipilih.
/// Dibangun manual dari XML OOXML minimal (3 file) yang sudah divalidasi
/// terbuka benar di Word/LibreOffice — tidak pakai package templating
/// eksternal supaya tidak bergantung format template yang rapuh.
Uint8List buildSuratPermohonanDocx(TreePruningRequest request) {
  final lokasiParts = <String>[request.alamatPohon];
  if (request.kelurahan.isNotEmpty) lokasiParts.add('Kelurahan ${request.kelurahan}');
  if (request.kecamatan.isNotEmpty) lokasiParts.add('Kecamatan ${request.kecamatan}');
  final lokasiLengkap = lokasiParts.join(', ');

  final bodyParagraphs = [
    _p('Cirebon, ${_formatDateLong(DateTime.now())}', align: 'right'),
    _emptyP,
    _p('Kepada Yth.'),
    _p('Kepala Dinas Perumahan Rakyat'),
    _p('dan Kawasan Permukiman Kota Cirebon'),
    _emptyP,
    _p('Perihal\t: Permohonan Perapihan/Pemangkasan Pohon'),
    _p('Lampiran\t: 2 Berkas'),
    _emptyP,
    _p('Yang bertandatangan di bawah ini,'),
    _p('Nama\t: ${request.namaPemohon}'),
    _p('Alamat\t: ${request.alamatPemohon}'),
    _p('No HP\t: ${request.nomorHp}'),
    _p('No KTP\t: ${request.nik}'),
    _emptyP,
    _p(
      'Berkenaan dengan keamanan penataan kawasan permukiman khususnya bagi '
      'warga/pengguna jalan di wilayah $lokasiLengkap. Dengan ini kami sampaikan '
      'bahwa pohon yang berada di lokasi tersebut mengkhawatirkan menjadi salah '
      'satu faktor rawan keamanan, dengan alasan: ${request.alasan}',
      align: 'both',
    ),
    _emptyP,
    _p('Terkait dengan hal tersebut kami mohon agar dilakukan pemangkasan sebagaimana semestinya.',
        align: 'both'),
    _emptyP,
    _p('Demikian atas perhatiannya dan terima kasih.', align: 'both'),
    _emptyP,
    _p('NOTE: LAMPIRAN FOTO POHON', bold: true),
    _p('Dan fotocopy identitas', bold: true),
    _emptyP,
    _emptyP,
    _p('TANDA TANGAN PEMOHON', align: 'right'),
    _emptyP,
    _emptyP,
    _p('( ${request.namaPemohon} )', align: 'right'),
  ].join();

  final documentXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
<w:body>
$bodyParagraphs
<w:sectPr><w:pgSz w:w="11906" w:h="16838"/><w:pgMar w:top="1440" w:right="1440" w:bottom="1440" w:left="1440"/></w:sectPr>
</w:body>
</w:document>''';

  const contentTypesXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>
<Default Extension="xml" ContentType="application/xml"/>
<Override PartName="/word/document.xml" ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>
</Types>''';

  const relsXml = '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="word/document.xml"/>
</Relationships>''';

  final archive = Archive();

  void addTextFile(String path, String content) {
    final bytes = utf8.encode(content);
    archive.addFile(ArchiveFile(path, bytes.length, bytes));
  }

  addTextFile('[Content_Types].xml', contentTypesXml);
  addTextFile('_rels/.rels', relsXml);
  addTextFile('word/document.xml', documentXml);

  final zipBytes = ZipEncoder().encode(archive);
  return Uint8List.fromList(zipBytes!);
}