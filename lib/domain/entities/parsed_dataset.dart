import 'dart:convert';

class ParsedDataset {
  final String id;
  final String fileName;
  final String sourceType;   // 'file' | 'paste'
  final List<String> headers;
  final List<List<String>> rows;
  final List<String> columnTypes;
  final double confidence;
  final bool wasAiParsed;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const ParsedDataset({
    required this.id,
    required this.fileName,
    required this.sourceType,
    required this.headers,
    required this.rows,
    required this.columnTypes,
    required this.confidence,
    this.wasAiParsed = false,
    required this.createdAt,
    this.updatedAt,
  });

  int get rowCount => rows.length;
  int get columnCount => headers.length;

  ParsedDataset copyWith({
    String? id,
    String? fileName,
    String? sourceType,
    List<String>? headers,
    List<List<String>>? rows,
    List<String>? columnTypes,
    double? confidence,
    bool? wasAiParsed,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) =>
      ParsedDataset(
        id: id ?? this.id,
        fileName: fileName ?? this.fileName,
        sourceType: sourceType ?? this.sourceType,
        headers: headers ?? this.headers,
        rows: rows ?? this.rows,
        columnTypes: columnTypes ?? this.columnTypes,
        confidence: confidence ?? this.confidence,
        wasAiParsed: wasAiParsed ?? this.wasAiParsed,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? DateTime.now(),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'sourceType': sourceType,
        'headers': headers,
        'rows': rows,
        'columnTypes': columnTypes,
        'confidence': confidence,
        'wasAiParsed': wasAiParsed,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  factory ParsedDataset.fromJson(Map<String, dynamic> j) => ParsedDataset(
        id: j['id'] as String,
        fileName: j['fileName'] as String,
        sourceType: j['sourceType'] as String,
        headers: List<String>.from(j['headers'] as List),
        rows: (j['rows'] as List)
            .map((r) => List<String>.from(r as List))
            .toList(),
        columnTypes: List<String>.from(j['columnTypes'] as List),
        confidence: (j['confidence'] as num).toDouble(),
        wasAiParsed: j['wasAiParsed'] as bool? ?? false,
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: j['updatedAt'] != null
            ? DateTime.parse(j['updatedAt'] as String)
            : null,
      );

  String toJsonString() => jsonEncode(toJson());
}

class HistoryRecord {
  final String id;
  final String fileName;
  final String sourceType;
  final int rowCount;
  final int columnCount;
  final bool wasAiParsed;
  final DateTime processedAt;
  final String datasetJson;

  const HistoryRecord({
    required this.id,
    required this.fileName,
    required this.sourceType,
    required this.rowCount,
    required this.columnCount,
    required this.wasAiParsed,
    required this.processedAt,
    required this.datasetJson,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'fileName': fileName,
        'sourceType': sourceType,
        'rowCount': rowCount,
        'columnCount': columnCount,
        'wasAiParsed': wasAiParsed,
        'processedAt': processedAt.toIso8601String(),
        'datasetJson': datasetJson,
      };

  factory HistoryRecord.fromJson(Map<String, dynamic> j) => HistoryRecord(
        id: j['id'] as String,
        fileName: j['fileName'] as String,
        sourceType: j['sourceType'] as String,
        rowCount: j['rowCount'] as int,
        columnCount: j['columnCount'] as int,
        wasAiParsed: j['wasAiParsed'] as bool? ?? false,
        processedAt: DateTime.parse(j['processedAt'] as String),
        datasetJson: j['datasetJson'] as String,
      );
}
