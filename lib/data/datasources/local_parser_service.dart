import 'dart:convert';
import 'dart:math';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import '../../domain/entities/parsed_dataset.dart';
import '../../core/utils/app_utils.dart';

class LocalParserService {

  // ─── Main entry: file bytes ────────────────────────────────────────────────
  Future<ParseResult> parseFile({
    required String fileName,
    required List<int> bytes,
  }) async {
    final ext = fileName.split('.').last.toLowerCase();
    try {
      switch (ext) {
        case 'xlsx':
        case 'xls':
          return _parseExcel(bytes, fileName);
        case 'csv':
          return _parseCsvBytes(bytes, fileName);
        case 'txt':
          final text = utf8.decode(bytes, allowMalformed: true);
          return parseText(text, fileName);
        case 'json':
          final text = utf8.decode(bytes, allowMalformed: true);
          return _parseJson(text, fileName);
        default:
          return ParseResult.failure('Unsupported format: .$ext');
      }
    } catch (e) {
      return ParseResult.failure('File parse error: $e');
    }
  }

  // ─── Excel ────────────────────────────────────────────────────────────────
  ParseResult _parseExcel(List<int> bytes, String fileName) {
    final excel = Excel.decodeBytes(bytes);
    final allSheets = <ParsedDataset>[];

    for (final sheetName in excel.tables.keys) {
      final sheet = excel.tables[sheetName]!;
      if (sheet.rows.isEmpty) continue;

      final rawRows = sheet.rows.map((row) {
        return row.map((cell) {
          final v = cell?.value;
          return v == null ? '' : v.toString().trim();
        }).toList();
      }).toList();

      final ds = _buildDataset(rawRows, '$fileName ($sheetName)', 'file');
      if (ds.rowCount > 0) allSheets.add(ds);
    }

    if (allSheets.isEmpty) return ParseResult.failure('Excel file is empty');
    return ParseResult.success(allSheets.first,
        extraSheets: allSheets.length > 1 ? allSheets.skip(1).toList() : null);
  }

  // ─── CSV ──────────────────────────────────────────────────────────────────
  ParseResult _parseCsvBytes(List<int> bytes, String fileName) {
    final text = utf8.decode(bytes, allowMalformed: true);
    try {
      final rows = const CsvToListConverter(eol: '\n', shouldParseNumbers: false)
          .convert(text);
      final strRows = rows
          .map((r) => r.map((c) => AppUtils.cleanCell(c.toString())).toList())
          .where((r) => r.any((c) => c.isNotEmpty))
          .toList();
      if (strRows.isEmpty) return ParseResult.failure('CSV is empty');
      final ds = _buildDataset(strRows, fileName, 'file');
      return ParseResult.success(ds);
    } catch (_) {
      return parseText(text, fileName);
    }
  }

  // ─── JSON ─────────────────────────────────────────────────────────────────
  ParseResult _parseJson(String text, String fileName) {
    try {
      final decoded = jsonDecode(text);
      List<Map<String, dynamic>> records = [];
      if (decoded is List) {
        records = decoded.whereType<Map<String, dynamic>>().toList();
      } else if (decoded is Map<String, dynamic>) {
        for (final k in decoded.keys) {
          if (decoded[k] is List) {
            records = (decoded[k] as List)
                .whereType<Map<String, dynamic>>()
                .toList();
            break;
          }
        }
        if (records.isEmpty) records = [decoded];
      }
      if (records.isEmpty) return ParseResult.failure('No records in JSON');

      final keys = <String>{};
      for (final r in records) keys.addAll(r.keys);
      final headers = keys.toList();
      final rowList = records
          .map((r) => headers.map((h) => (r[h] ?? '').toString()).toList())
          .toList();

      final ds = _buildDataset([headers, ...rowList], fileName, 'file');
      return ParseResult.success(ds);
    } catch (e) {
      return ParseResult.failure('Invalid JSON: $e');
    }
  }

  // ─── Text / Paste ─────────────────────────────────────────────────────────
  ParseResult parseText(String text, String fileName) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return ParseResult.failure('Input is empty');

    final lines = trimmed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    if (lines.isEmpty) return ParseResult.failure('No content to parse');

    // Detect separator on sample lines
    final sep = AppUtils.detectSeparator(trimmed);

    // Check if lines have sub key-value pairs (e.g. CheckIn|01-03-2026)
    final rawRows = lines.map((line) => _parseComplexLine(line, sep)).toList();

    // Normalize column count
    final normalized = _normalizeColumnCount(rawRows);
    if (normalized.isEmpty) return ParseResult.failure('Could not parse data');

    final ds = _buildDataset(normalized, fileName, 'paste');
    return ParseResult.success(ds, separator: sep);
  }

  // ─── Complex Line Parser ──────────────────────────────────────────────────
  /// Handles lines like: B001~Rahul~Delhi~CheckIn|01-03-2026~CheckOut|03-03-2026
  List<String> _parseComplexLine(String line, String sep) {
    // First split by primary separator
    final tokens = line.split(sep).map(AppUtils.cleanCell).toList();

    // Now check each token for key=value or key|value patterns
    final expanded = <String>[];
    for (final token in tokens) {
      if (token.isEmpty) {
        expanded.add('');
        continue;
      }
      // Check for sub-separator embedded in token (e.g. CheckIn|01-03-2026)
      final kv = AppUtils.parseKeyValuePair(token);
      if (kv != null) {
        // Just store the value part (we'll collect keys separately)
        expanded.add(kv.value);
      } else {
        expanded.add(token);
      }
    }
    return expanded;
  }

  /// Extract key names from complex line for header generation
  List<String>? _extractKeys(String line, String sep) {
    final tokens = line.split(sep).map(AppUtils.cleanCell).toList();
    final keys = <String>[];
    bool hasAnyKey = false;
    for (final token in tokens) {
      final kv = AppUtils.parseKeyValuePair(token);
      if (kv != null) {
        keys.add(kv.key);
        hasAnyKey = true;
      } else {
        keys.add(''); // placeholder
      }
    }
    return hasAnyKey ? keys : null;
  }

  // ─── Normalize Column Count ────────────────────────────────────────────────
  List<List<String>> _normalizeColumnCount(List<List<String>> rows) {
    if (rows.isEmpty) return [];
    final maxCols = rows.map((r) => r.length).reduce(max);
    // Remove fully empty rows, dedup
    final seen = <String>{};
    final result = <List<String>>[];
    for (final row in rows) {
      if (row.every((c) => c.isEmpty)) continue;
      final padded = List<String>.from(row);
      while (padded.length < maxCols) padded.add('');
      final key = padded.join('\x00');
      if (!seen.contains(key)) {
        seen.add(key);
        result.add(padded);
      }
    }
    return result;
  }

  // ─── Core Dataset Builder ─────────────────────────────────────────────────
  ParsedDataset _buildDataset(
    List<List<String>> rawRows,
    String fileName,
    String sourceType,
  ) {
    if (rawRows.isEmpty) {
      return ParsedDataset(
        id: _newId(),
        fileName: fileName,
        sourceType: sourceType,
        headers: [],
        rows: [],
        columnTypes: [],
        confidence: 0,
        createdAt: DateTime.now(),
      );
    }

    final normalized = _normalizeColumnCount(rawRows);
    final colCount = normalized.isNotEmpty ? normalized.first.length : 0;

    List<String> headers;
    List<List<String>> dataRows;

    if (AppUtils.looksLikeHeader(normalized.first)) {
      headers = normalized.first
          .map((h) => AppUtils.cleanCell(h).isEmpty ? 'Column' : AppUtils.cleanCell(h))
          .toList();
      dataRows = normalized.skip(1).toList();
    } else {
      dataRows = normalized;
      // Generate headers from column type inference
      final samples = List.generate(colCount, (i) =>
          dataRows.take(30).map((r) => i < r.length ? r[i] : '').toList());
      final types = samples.map(AppUtils.inferColumnType).toList();
      headers = types
          .asMap()
          .entries
          .map((e) => AppUtils.columnTypeToDefaultLabel(e.value, e.key))
          .toList();
    }

    // Infer types from data rows
    final colSamples = List.generate(headers.length, (i) =>
        dataRows.take(50).map((r) => i < r.length ? r[i] : '').toList());
    final columnTypes = colSamples.map(AppUtils.inferColumnType).toList();

    // Clean all cells
    final cleanedRows = dataRows.map((row) {
      return List.generate(headers.length, (i) {
        var val = i < row.length ? AppUtils.cleanCell(row[i]) : '';
        if (i < columnTypes.length) {
          val = AppUtils.standardizeCapitalization(val, columnTypes[i]);
          if (columnTypes[i] == 'Amount' && AppUtils.isAmount(val)) {
            val = AppUtils.normalizeAmount(val);
          }
        }
        return val;
      });
    }).toList();

    final confidence = AppUtils.calculateConfidence(cleanedRows, columnTypes);

    return ParsedDataset(
      id: _newId(),
      fileName: fileName,
      sourceType: sourceType,
      headers: headers,
      rows: cleanedRows,
      columnTypes: columnTypes,
      confidence: confidence,
      wasAiParsed: false,
      createdAt: DateTime.now(),
    );
  }

  String _newId() => DateTime.now().millisecondsSinceEpoch.toString();
}

// ─── Result ───────────────────────────────────────────────────────────────────
class ParseResult {
  final ParsedDataset? dataset;
  final List<ParsedDataset>? extraSheets;
  final String? error;
  final bool success;
  final String? separator;

  const ParseResult._({
    this.dataset,
    this.extraSheets,
    this.error,
    required this.success,
    this.separator,
  });

  factory ParseResult.success(ParsedDataset dataset,
      {String? separator, List<ParsedDataset>? extraSheets}) =>
      ParseResult._(
          dataset: dataset,
          success: true,
          separator: separator,
          extraSheets: extraSheets);

  factory ParseResult.failure(String error) =>
      ParseResult._(error: error, success: false);
}
