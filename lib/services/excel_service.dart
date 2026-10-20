import 'dart:convert';
import 'dart:typed_data';

import 'package:csv/csv.dart';
import 'package:excel/excel.dart';

import '../models/vocabulary.dart';
import '../utils/pinyin_zhuyin.dart';

class VocabularyImportData {
  const VocabularyImportData({
    required this.vocabs,
    required this.skippedCount,
  });

  final List<Vocabulary> vocabs;
  final int skippedCount;
}

class ExcelService {
  static const headers = [
    'hanzi',
    'traditionalHanzi',
    'pinyin',
    'zhuyin',
    'meaning',
    'category',
  ];

  static Uint8List exportXlsx(List<Vocabulary> vocabs) {
    final excel = Excel.createExcel();
    final sheet = excel['Vocabulary'];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    for (final vocab in vocabs) {
      sheet.appendRow(
        [
          vocab.hanzi,
          vocab.traditionalHanzi ?? '',
          vocab.pinyin,
          vocab.zhuyin ?? '',
          vocab.meaning,
          vocab.category,
        ].map(TextCellValue.new).toList(),
      );
    }
    return Uint8List.fromList(excel.encode()!);
  }

  static Uint8List createTemplate() {
    final excel = Excel.createExcel();
    final sheet = excel['Vocabulary'];
    sheet.appendRow(headers.map(TextCellValue.new).toList());
    sheet.appendRow(
      [
        '你好',
        '你好',
        'nǐ hǎo',
        'ㄋㄧˇ ㄏㄠˇ',
        'hello',
        'TOCFL A1',
      ].map(TextCellValue.new).toList(),
    );
    sheet.appendRow(
      [
        '谢谢',
        '謝謝',
        'xiè xie',
        'ㄒㄧㄝˋ ˙ㄒㄧㄝ',
        'thank you',
        'TOCFL A1',
      ].map(TextCellValue.new).toList(),
    );
    sheet.appendRow(
      [
        '再見',
        '再見',
        'zài jiàn',
        'ㄗㄞˋ ㄐㄧㄢˋ',
        'goodbye',
        'TOCFL A1',
      ].map(TextCellValue.new).toList(),
    );
    return Uint8List.fromList(excel.encode()!);
  }

  static Uint8List exportCsv(List<Vocabulary> vocabs) => Uint8List.fromList(
    utf8.encode(
      const ListToCsvConverter().convert([
        headers,
        ...vocabs.map(
          (vocab) => [
            vocab.hanzi,
            vocab.traditionalHanzi ?? '',
            vocab.pinyin,
            vocab.zhuyin ?? '',
            vocab.meaning,
            vocab.category,
          ],
        ),
      ]),
    ),
  );

  static VocabularyImportData importXlsx(List<int> bytes) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) {
      throw const FormatException('Excel file has no worksheet.');
    }
    final sheet = excel.tables['Vocabulary'] ?? excel.tables.values.first;
    final rows = sheet.rows
        .map(
          (row) => row.map((cell) {
            final value = cell?.value;
            return value is TextCellValue
                ? value.value.text ?? ''
                : value?.toString() ?? '';
          }).toList(),
        )
        .toList();
    return parseRows(rows);
  }

  static VocabularyImportData importCsv(List<int> bytes) {
    String decoded;
    try {
      decoded = utf8.decode(bytes);
    } catch (_) {
      decoded = String.fromCharCodes(bytes);
    }
    try {
      final rows = const CsvToListConverter().convert(decoded);
      return parseRows(
        rows.map((row) => row.map((cell) => cell.toString()).toList()).toList(),
      );
    } on FormatException catch (error) {
      if (!error.message.contains('Required headers')) rethrow;
      return parseRows(_parseSimpleCsv(decoded));
    }
  }

  static List<List<String>> _parseSimpleCsv(String text) => const LineSplitter()
      .convert(text)
      .where((line) => line.trim().isNotEmpty)
      .map((line) => line.split(',').map((cell) => cell.trim()).toList())
      .toList();

  static VocabularyImportData parseRows(List<List<String>> rows) {
    if (rows.isEmpty) {
      return const VocabularyImportData(vocabs: [], skippedCount: 0);
    }
    final columnIndexes = <String, int>{};
    for (var index = 0; index < rows.first.length; index++) {
      final header = _normalizeHeader(rows.first[index]);
      if (header.isNotEmpty && columnIndexes.containsKey(header)) {
        throw FormatException('Duplicate header: ${rows.first[index]}.');
      }
      if (header.isNotEmpty) columnIndexes[header] = index;
    }
    final hanziIndex = _columnIndex(columnIndexes, const [
      'hanzi',
      'simplified',
      'traditional',
    ]);
    final pinyinIndex = _columnIndex(columnIndexes, const ['pinyin']);
    final meaningIndex = _columnIndex(columnIndexes, const ['meaning']);

    if (hanziIndex == null || pinyinIndex == null || meaningIndex == null) {
      throw const FormatException(
        'Required headers: hanzi, pinyin, meaning (or compatible aliases).',
      );
    }

    final traditionalIndex = _columnIndex(columnIndexes, const [
      'traditionalhanzi',
      'traditional',
    ]);
    final zhuyinIndex = _columnIndex(columnIndexes, const ['zhuyin']);
    final categoryIndex = _columnIndex(columnIndexes, const ['category']);
    final subcategoryIndex = _columnIndex(columnIndexes, const ['subcategory']);
    final idIndex = _columnIndex(columnIndexes, const ['id']);

    final vocabs = <Vocabulary>[];
    var skippedCount = 0;
    for (final row in rows.skip(1)) {
      String valueAt(int? index) {
        return index == null || index >= row.length ? '' : row[index].trim();
      }

      if (row.every((cell) => cell.trim().isEmpty)) continue;
      final hanzi = valueAt(hanziIndex);
      final pinyin = valueAt(pinyinIndex);
      final meaning = valueAt(meaningIndex);
      if (hanzi.isEmpty || pinyin.isEmpty || meaning.isEmpty) {
        skippedCount++;
        continue;
      }
      final traditionalHanzi = valueAt(traditionalIndex);
      final zhuyin = valueAt(zhuyinIndex);
      final category = valueAt(categoryIndex);
      final subcategory = valueAt(subcategoryIndex);
      final rowId = valueAt(idIndex);
      final generatedZhuyin = zhuyin.isEmpty ? pinyinToZhuyin(pinyin) : zhuyin;
      vocabs.add(
        Vocabulary(
          hanzi: hanzi,
          traditionalHanzi: traditionalHanzi.isEmpty ? null : traditionalHanzi,
          pinyin: pinyin,
          zhuyin: generatedZhuyin.isEmpty ? null : generatedZhuyin,
          meaning: meaning,
          category: _normalizedCategory(category, subcategory, rowId),
        ),
      );
    }
    return VocabularyImportData(vocabs: vocabs, skippedCount: skippedCount);
  }

  static int? _columnIndex(
    Map<String, int> columnIndexes,
    List<String> headers,
  ) {
    for (final header in headers) {
      final index = columnIndexes[_normalizeHeader(header)];
      if (index != null) return index;
    }
    return null;
  }

  static String _normalizedCategory(
    String category,
    String subcategory,
    String rowId,
  ) {
    final inferred = _inferTocflCategory(rowId);
    if (inferred != null) return inferred;

    final normalizedCategory = Vocabulary.normalizeCategory(category);
    if (Vocabulary.tocflCategories.contains(normalizedCategory)) {
      return normalizedCategory;
    }

    // Try to map common category names to TOCFL bands
    final tocflMapped = _mapToTocflCategory(normalizedCategory, subcategory);
    if (tocflMapped != null) return tocflMapped;

    if (category.isNotEmpty && subcategory.isNotEmpty) {
      return '$category/$subcategory';
    }
    if (category.isNotEmpty) return category;
    return Vocabulary.tocflCategories.first;
  }

  static String? _mapToTocflCategory(String category, String subcategory) {
    final cat = category.toLowerCase();
    final sub = subcategory.toLowerCase();

    // HSK mapping
    if (cat.contains('hsk')) {
      if (cat.contains('1') || cat.contains('2') || cat.contains('3')) {
        return 'TOCFL A1';
      }
      if (cat.contains('4') || cat.contains('5')) return 'TOCFL A2';
      if (cat.contains('6')) return 'TOCFL B1';
    }

    // Common Chinese category names from the CSV
    const tocflA1Categories = {
      'figures',
      'people',
      'person',
      'family',
      'body parts',
      'body actions',
      'hand actions',
      'foot actions',
      'eye actions',
      'mouth actions',
      'psychological activities',
      'personality traits',
      'occupations',
      'numbers',
      'quantities',
      'money',
      'degree',
      'time',
      'date/weekday',
      'colors',
      'sizes',
      'shapes',
      'clothing',
      'accessories',
      'home items',
      'home activities',
      'food',
      'drinks',
      'eating',
      'school',
      'leisure',
      'health',
      'transport',
      'vehicles',
      'nature',
      'phenomena',
      'seasons',
      'weather',
      'plants',
      'animals',
      'directions',
      'locations',
      'countries',
      'languages',
      'common phrases',
      'blessings',
      'function words',
    };

    if (tocflA1Categories.contains(cat) || tocflA1Categories.contains(sub)) {
      return 'TOCFL A1';
    }

    return null;
  }

  static String? _inferTocflCategory(String id) {
    final match = RegExp(r'^L(\d+)').firstMatch(id.trim().toUpperCase());
    if (match == null) return null;
    return switch (int.tryParse(match.group(1) ?? '')) {
      1 => 'TOCFL A1',
      2 => 'TOCFL A2',
      3 => 'TOCFL B1',
      4 => 'TOCFL B2',
      5 => 'TOCFL C1',
      6 => 'TOCFL C2',
      _ => null,
    };
  }

  static String _normalizeHeader(String value) =>
      value.replaceFirst('\uFEFF', '').trim().toLowerCase();
}
