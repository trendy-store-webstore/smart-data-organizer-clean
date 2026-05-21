import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import '../../data/datasources/local_parser_service.dart';
import '../../data/datasources/ai_parser_service.dart';
import '../../domain/entities/parsed_dataset.dart';
import '../../core/constants/app_constants.dart';

enum ParseState { idle, parsing, success, error }

class AppProvider extends ChangeNotifier {
  ParseState _state = ParseState.idle;
  ParsedDataset? _dataset;
  String? _errorMessage;
  String _statusMessage = '';
  double _progress = 0.0;

  ParseState get state => _state;
  ParsedDataset? get dataset => _dataset;
  String? get errorMessage => _errorMessage;
  String get statusMessage => _statusMessage;
  double get progress => _progress;

  final _localParser = LocalParserService();

  // ─── Parse File ────────────────────────────────────────────────────────────
  Future<void> parseFile({
    required String filePath,
    required String fileName,
    required bool aiEnabled,
    required String apiKey,
  }) async {
    _begin();
    _update('Reading file...', 0.1);

    try {
      final file = File(filePath);
      if (!await file.exists()) { _fail('File not found'); return; }
      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) { _fail('File is empty'); return; }
      if (bytes.length > AppConstants.maxFileSizeMB * 1024 * 1024) {
        _fail('File too large (max ${AppConstants.maxFileSizeMB}MB)');
        return;
      }

      _update('Parsing data...', 0.35);
      final result = await _localParser.parseFile(fileName: fileName, bytes: bytes);

      _update('Analyzing columns...', 0.6);

      if (!result.success || result.dataset == null) {
        if (aiEnabled) {
          final lines = _bytesToLines(bytes);
          await _runAiFallback(lines: lines, fileName: fileName, sourceType: 'file', apiKey: apiKey);
        } else {
          _fail(result.error ?? 'Parse failed');
        }
        return;
      }

      final ds = result.dataset!;

      if (aiEnabled && ds.confidence < AppConstants.aiConfidenceThreshold && ds.rowCount < 5) {
        _update('Low confidence — using AI...', 0.75);
        final lines = _bytesToLines(bytes);
        final ok = await _runAiFallback(
            lines: lines, fileName: fileName, sourceType: 'file',
            apiKey: apiKey, fallback: ds);
        if (ok) return;
      }

      _succeed(ds);
    } catch (e) {
      _fail('Error: $e');
    }
  }

  // ─── Parse Pasted Text ──────────────────────────────────────────────────────
  Future<void> parsePastedText({
    required String text,
    required bool aiEnabled,
    required String apiKey,
  }) async {
    if (text.trim().isEmpty) { _fail('Please enter some text'); return; }
    _begin();
    _update('Analyzing text...', 0.25);

    try {
      final result = _localParser.parseText(text, 'Pasted Data');
      _update('Building table...', 0.55);

      if (!result.success || result.dataset == null || result.dataset!.rowCount == 0) {
        if (aiEnabled) {
          final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
          await _runAiFallback(lines: lines, fileName: 'Pasted Data', sourceType: 'paste', apiKey: apiKey);
        } else {
          _fail(result.error ?? 'Could not parse text');
        }
        return;
      }

      final ds = result.dataset!;

      if (aiEnabled && ds.confidence < AppConstants.aiConfidenceThreshold) {
        _update('Low confidence — using AI...', 0.75);
        final lines = text.split('\n').where((l) => l.trim().isNotEmpty).toList();
        final ok = await _runAiFallback(
            lines: lines, fileName: 'Pasted Data', sourceType: 'paste',
            apiKey: apiKey, fallback: ds);
        if (ok) return;
      }

      _succeed(ds);
    } catch (e) {
      _fail('Error: $e');
    }
  }

  // ─── AI fallback ────────────────────────────────────────────────────────────
  Future<bool> _runAiFallback({
    required List<String> lines,
    required String fileName,
    required String sourceType,
    required String apiKey,
    ParsedDataset? fallback,
  }) async {
    try {
      _update('Using AI parser...', 0.85);
      final ai = AiParserService(customKey: apiKey);
      final ds = await ai.buildDataset(rawRows: lines, fileName: fileName, sourceType: sourceType);
      if (ds != null && ds.rowCount > 0) {
        _succeed(ds);
        return true;
      }
    } catch (_) {}
    if (fallback != null) { _succeed(fallback); return true; }
    _fail('Parsing failed. Try enabling AI or check your data.');
    return false;
  }

  // ─── Editing ──────────────────────────────────────────────────────────────
  void updateDataset(ParsedDataset ds) { _dataset = ds; notifyListeners(); }

  void updateCell(int row, int col, String val) {
    if (_dataset == null) return;
    final rows = _dataset!.rows.map((r) => List<String>.from(r)).toList();
    if (row < rows.length && col < rows[row].length) {
      rows[row][col] = val;
      _dataset = _dataset!.copyWith(rows: rows);
      notifyListeners();
    }
  }

  void addRow() {
    if (_dataset == null) return;
    final rows = _dataset!.rows.map((r) => List<String>.from(r)).toList();
    rows.add(List.filled(_dataset!.columnCount, ''));
    _dataset = _dataset!.copyWith(rows: rows);
    notifyListeners();
  }

  void deleteRow(int i) {
    if (_dataset == null || i >= _dataset!.rows.length) return;
    final rows = _dataset!.rows.map((r) => List<String>.from(r)).toList();
    rows.removeAt(i);
    _dataset = _dataset!.copyWith(rows: rows);
    notifyListeners();
  }

  void duplicateRow(int i) {
    if (_dataset == null || i >= _dataset!.rows.length) return;
    final rows = _dataset!.rows.map((r) => List<String>.from(r)).toList();
    rows.insert(i + 1, List<String>.from(rows[i]));
    _dataset = _dataset!.copyWith(rows: rows);
    notifyListeners();
  }

  void renameColumn(int i, String name) {
    if (_dataset == null || i >= _dataset!.headers.length) return;
    final h = List<String>.from(_dataset!.headers);
    h[i] = name;
    _dataset = _dataset!.copyWith(headers: h);
    notifyListeners();
  }

  void deleteColumn(int i) {
    if (_dataset == null) return;
    final h = List<String>.from(_dataset!.headers);
    final t = List<String>.from(_dataset!.columnTypes);
    if (i < h.length) h.removeAt(i);
    if (i < t.length) t.removeAt(i);
    final rows = _dataset!.rows.map((r) {
      final row = List<String>.from(r);
      if (i < row.length) row.removeAt(i);
      return row;
    }).toList();
    _dataset = _dataset!.copyWith(headers: h, columnTypes: t, rows: rows);
    notifyListeners();
  }

  void addColumn(String name) {
    if (_dataset == null) return;
    final h = List<String>.from(_dataset!.headers)..add(name);
    final t = List<String>.from(_dataset!.columnTypes)..add('Text');
    final rows = _dataset!.rows.map((r) => List<String>.from(r)..add('')).toList();
    _dataset = _dataset!.copyWith(headers: h, columnTypes: t, rows: rows);
    notifyListeners();
  }

  void sortByColumn(int col, bool asc) {
    if (_dataset == null) return;
    final rows = _dataset!.rows.map((r) => List<String>.from(r)).toList();
    rows.sort((a, b) {
      final va = col < a.length ? a[col] : '';
      final vb = col < b.length ? b[col] : '';
      final na = double.tryParse(va.replaceAll(RegExp(r'[,₹\$€]'), ''));
      final nb = double.tryParse(vb.replaceAll(RegExp(r'[,₹\$€]'), ''));
      int cmp = (na != null && nb != null) ? na.compareTo(nb) : va.toLowerCase().compareTo(vb.toLowerCase());
      return asc ? cmp : -cmp;
    });
    _dataset = _dataset!.copyWith(rows: rows);
    notifyListeners();
  }

  void loadDataset(ParsedDataset ds) {
    _dataset = ds;
    _state = ParseState.success;
    notifyListeners();
  }

  void reset() {
    _dataset = null;
    _errorMessage = null;
    _statusMessage = '';
    _progress = 0.0;
    _state = ParseState.idle;
    notifyListeners();
  }

  // ─── Helpers ──────────────────────────────────────────────────────────────
  void _begin() { _state = ParseState.parsing; _errorMessage = null; _dataset = null; notifyListeners(); }
  void _update(String msg, double p) { _statusMessage = msg; _progress = p; notifyListeners(); }
  void _succeed(ParsedDataset ds) { _dataset = ds; _state = ParseState.success; _progress = 1.0; _statusMessage = 'Done!'; notifyListeners(); }
  void _fail(String msg) { _errorMessage = msg; _state = ParseState.error; notifyListeners(); }

  List<String> _bytesToLines(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: true)
          .split('\n')
          .where((l) => l.trim().isNotEmpty)
          .toList();
    } catch (_) { return []; }
  }
}
