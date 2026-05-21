import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/entities/parsed_dataset.dart';
import '../../core/constants/app_constants.dart';

class HistoryProvider extends ChangeNotifier {
  List<HistoryRecord> _records = [];
  List<HistoryRecord> get records => List.unmodifiable(_records);

  Future<void> init() async => _load();

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getStringList(AppConstants.keyHistory) ?? [];
      _records = raw
          .map((s) {
            try {
              return HistoryRecord.fromJson(
                  jsonDecode(s) as Map<String, dynamic>);
            } catch (_) {
              return null;
            }
          })
          .whereType<HistoryRecord>()
          .toList()
        ..sort((a, b) => b.processedAt.compareTo(a.processedAt));
      notifyListeners();
    } catch (_) {
      _records = [];
    }
  }

  Future<void> addRecord(ParsedDataset ds) async {
    final record = HistoryRecord(
      id: ds.id,
      fileName: ds.fileName,
      sourceType: ds.sourceType,
      rowCount: ds.rowCount,
      columnCount: ds.columnCount,
      wasAiParsed: ds.wasAiParsed,
      processedAt: DateTime.now(),
      datasetJson: ds.toJsonString(),
    );
    _records.insert(0, record);
    if (_records.length > 50) _records = _records.take(50).toList();
    await _save();
    notifyListeners();
  }

  Future<void> deleteRecord(String id) async {
    _records.removeWhere((r) => r.id == id);
    await _save();
    notifyListeners();
  }

  Future<void> clearAll() async {
    _records.clear();
    await _save();
    notifyListeners();
  }

  ParsedDataset? getDataset(String id) {
    try {
      final r = _records.firstWhere((r) => r.id == id);
      return ParsedDataset.fromJson(
          jsonDecode(r.datasetJson) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
        AppConstants.keyHistory,
        _records.map((r) => jsonEncode(r.toJson())).toList());
  }
}
