import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/constants/app_constants.dart';
import '../../domain/entities/parsed_dataset.dart';

class AiParserService {
  static const _system = '''
You are a data extraction assistant. Parse messy or semi-structured text into structured JSON.

Rules:
- Return ONLY valid JSON. No markdown, no explanation, no backticks.
- For multiple records: return a JSON array of objects.
- For one record: return a JSON object.
- Infer field names from context: name, city, phone, email, date, check_in, check_out, guests, amount, status, booking_id, order_id, address, etc.
- Normalize dates to dd-MM-yyyy where possible.
- Extract amounts as numbers (not strings).
- If a field is absent use null.
- Handle separators: ~ | , ; tab = : automatically.
- Handle sub-fields like "CheckIn|01-03-2026" → key: check_in, value: "01-03-2026"

Examples:
Input: "Rahul from Delhi arriving 1 March, 2 guests, paid 4500, confirmed"
Output: {"name":"Rahul","city":"Delhi","arrival_date":"01-03-2025","guests":2,"amount":4500,"status":"Confirmed"}

Input: "B001~Rahul Sharma~Delhi~CheckIn|01-03-2026~CheckOut|03-03-2026~Guests|2~4500~Confirmed"
Output: {"booking_id":"B001","name":"Rahul Sharma","city":"Delhi","check_in":"01-03-2026","check_out":"03-03-2026","guests":2,"amount":4500,"status":"Confirmed"}
''';

  final String? _customKey;
  AiParserService({String? customKey}) : _customKey = customKey;

  String get _apiKey =>
      (_customKey != null && _customKey!.isNotEmpty)
          ? _customKey!
          : AppConstants.defaultOpenAiKey;

  Future<AiParseResult> parseRows(List<String> rawRows) async {
    final input = rawRows.take(60).join('\n');
    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.openAiBaseUrl),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $_apiKey',
            },
            body: jsonEncode({
              'model': AppConstants.openAiModel,
              'messages': [
                {'role': 'system', 'content': _system},
                {
                  'role': 'user',
                  'content': 'Parse this data:\n\n$input'
                },
              ],
              'max_tokens': 2000,
              'temperature': 0.1,
            }),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 401) {
        return AiParseResult.failure('Invalid API key. Please check your key in Settings.');
      }
      if (response.statusCode == 429) {
        return AiParseResult.failure('Rate limit reached. Try again shortly.');
      }
      if (response.statusCode != 200) {
        return AiParseResult.failure('API error ${response.statusCode}');
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final content = json['choices'][0]['message']['content'] as String;
      return _parseAiContent(content);
    } on Exception catch (e) {
      return AiParseResult.failure('Network error: $e');
    }
  }

  AiParseResult _parseAiContent(String content) {
    try {
      final cleaned = content
          .replaceAll(RegExp(r'```json|```'), '')
          .trim();
      final decoded = jsonDecode(cleaned);

      List<Map<String, dynamic>> records;
      if (decoded is List) {
        records = decoded.whereType<Map<String, dynamic>>().toList();
      } else if (decoded is Map<String, dynamic>) {
        records = [decoded];
      } else {
        return AiParseResult.failure('Unexpected AI response format');
      }

      if (records.isEmpty) return AiParseResult.failure('AI returned no data');

      final allKeys = <String>{};
      for (final r in records) allKeys.addAll(r.keys);
      final rawKeys = allKeys.toList();
      final headers = rawKeys.map(_formatKey).toList();

      final rows = records.map((r) =>
          rawKeys.map((k) => (r[k] ?? '').toString()).toList()).toList();

      return AiParseResult.success(headers: headers, rows: rows);
    } catch (e) {
      return AiParseResult.failure('Failed to parse AI response: $e');
    }
  }

  String _formatKey(String k) => k
      .replaceAll('_', ' ')
      .split(' ')
      .map((w) => w.isEmpty
          ? ''
          : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
      .join(' ');

  Future<ParsedDataset?> buildDataset({
    required List<String> rawRows,
    required String fileName,
    required String sourceType,
  }) async {
    final result = await parseRows(rawRows);
    if (!result.success || result.headers == null) return null;
    return ParsedDataset(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      fileName: fileName,
      sourceType: sourceType,
      headers: result.headers!,
      rows: result.rows!,
      columnTypes: List.filled(result.headers!.length, 'Text'),
      confidence: 0.9,
      wasAiParsed: true,
      createdAt: DateTime.now(),
    );
  }
}

class AiParseResult {
  final List<String>? headers;
  final List<List<String>>? rows;
  final String? error;
  final bool success;

  const AiParseResult._({this.headers, this.rows, this.error, required this.success});

  factory AiParseResult.success({required List<String> headers, required List<List<String>> rows}) =>
      AiParseResult._(headers: headers, rows: rows, success: true);

  factory AiParseResult.failure(String error) =>
      AiParseResult._(error: error, success: false);
}
