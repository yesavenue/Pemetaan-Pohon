import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Apply OOXML features not exposed by excel 4.x to our one-sheet report.
/// Keep cells, styles and relationships from the original workbook unchanged.
Uint8List applyExcelReportLayout(List<int> bytes, int dataRows) {
  final source = ZipDecoder().decodeBytes(bytes);
  final output = Archive();
  final lastRow = dataRows == 0 ? 9 : dataRows + 8;
  for (final file in source) {
    if (!file.isFile) {
      output.addFile(file);
      continue;
    }
    if (file.name.startsWith('xl/worksheets/') && file.name.endsWith('.xml')) {
      final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));
      final root = doc.rootElement;
      final properties = _ensure(root, 'sheetPr');
      final fit = _ensure(properties, 'pageSetUpPr');
      fit.setAttribute('fitToPage', '1');
      final views = _ensure(root, 'sheetViews');
      final view =
          views.findElements('sheetView').firstOrNull ??
          (XmlElement(XmlName('sheetView'))
            ..setAttribute('workbookViewId', '0'));
      if (view.parent == null) {
        views.children.add(view);
      }
      view.setAttribute('showGridLines', '0');
      view.children.removeWhere(
        (n) => n is XmlElement && ['pane', 'selection'].contains(n.name.local),
      );
      _ensure(root, 'autoFilter').setAttribute('ref', 'A8:M${dataRows + 8}');
      final margins = _ensure(root, 'pageMargins');
      for (final entry in {
        'left': '0.3',
        'right': '0.3',
        'top': '0.5',
        'bottom': '0.5',
        'header': '0.2',
        'footer': '0.2',
      }.entries) {
        margins.setAttribute(entry.key, entry.value);
      }
      final setup = _ensure(root, 'pageSetup');
      for (final entry in {
        'paperSize': '8',
        'orientation': 'landscape',
        'fitToWidth': '1',
        'fitToHeight': '0',
      }.entries) {
        setup.setAttribute(entry.key, entry.value);
      }
      final footer = _ensure(_ensure(root, 'headerFooter'), 'oddFooter');
      footer.innerText = '&LInventaris Pohon Kota Cirebon&RHalaman &P dari &N';
      final encoded = utf8.encode(doc.toXmlString());
      output.addFile(ArchiveFile(file.name, encoded.length, encoded));
    } else if (file.name == 'xl/workbook.xml') {
      final doc = XmlDocument.parse(utf8.decode(file.content as List<int>));
      final root = doc.rootElement;
      final names = _ensure(root, 'definedNames');
      names.children.removeWhere(
        (n) =>
            n is XmlElement &&
            [
              '_xlnm.Print_Titles',
              '_xlnm.Print_Area',
            ].contains(n.getAttribute('name')) &&
            n.getAttribute('localSheetId') == '0',
      );
      for (final entry in {
        '_xlnm.Print_Titles': "'Inventaris Pohon'!\$8:\$8",
        '_xlnm.Print_Area': "'Inventaris Pohon'!\$A\$1:\$M\$$lastRow",
      }.entries) {
        names.children.add(
          _element('definedName', {'name': entry.key, 'localSheetId': '0'})
            ..innerText = entry.value,
        );
      }
      final encoded = utf8.encode(doc.toXmlString());
      output.addFile(ArchiveFile(file.name, encoded.length, encoded));
    } else {
      output.addFile(file);
    }
  }
  final result = ZipEncoder().encode(output);
  if (result == null) {
    throw StateError('Pengaturan laporan Excel gagal disimpan.');
  }
  return Uint8List.fromList(result);
}

XmlElement _element(String name, Map<String, String> attributes) => XmlElement(
  XmlName(name),
  attributes.entries.map((e) => XmlAttribute(XmlName(e.key), e.value)),
);

XmlElement _ensure(XmlElement parent, String name) {
  final existing = parent.findElements(name).firstOrNull;
  if (existing != null) {
    return existing;
  }
  final element = XmlElement(XmlName(name));
  // OOXML worksheet/workbook children have a required sequence.
  const sheet = [
    'sheetPr',
    'dimension',
    'sheetViews',
    'sheetFormatPr',
    'cols',
    'sheetData',
    'sheetCalcPr',
    'sheetProtection',
    'protectedRanges',
    'scenarios',
    'autoFilter',
    'sortState',
    'dataConsolidate',
    'customSheetViews',
    'mergeCells',
    'phoneticPr',
    'conditionalFormatting',
    'dataValidations',
    'hyperlinks',
    'printOptions',
    'pageMargins',
    'pageSetup',
    'headerFooter',
    'rowBreaks',
    'colBreaks',
    'customProperties',
    'cellWatches',
    'ignoredErrors',
    'smartTags',
    'drawing',
    'legacyDrawing',
    'legacyDrawingHF',
    'picture',
    'oleObjects',
    'controls',
    'webPublishItems',
    'tableParts',
    'extLst',
  ];
  const book = [
    'fileVersion',
    'fileSharing',
    'workbookPr',
    'workbookProtection',
    'bookViews',
    'sheets',
    'functionGroups',
    'externalReferences',
    'definedNames',
    'calcPr',
    'oleSize',
    'customWorkbookViews',
    'pivotCaches',
    'smartTagPr',
    'smartTagTypes',
    'webPublishing',
    'fileRecoveryPr',
    'webPublishObjects',
    'extLst',
  ];
  final order = parent.name.local == 'worksheet'
      ? sheet
      : parent.name.local == 'workbook'
      ? book
      : <String>[];
  final rank = order.indexOf(name);
  final index = rank < 0
      ? -1
      : parent.children.indexWhere(
          (n) => n is XmlElement && order.indexOf(n.name.local) > rank,
        );
  if (index < 0) {
    parent.children.add(element);
  } else {
    parent.children.insert(index, element);
  }
  return element;
}