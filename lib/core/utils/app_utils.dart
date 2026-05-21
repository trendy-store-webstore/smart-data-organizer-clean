import 'dart:math';
import 'package:intl/intl.dart';

class AppUtils {

  // ─── Separator Detection ──────────────────────────────────────────────────
  /// Returns the best separator for the given text block
  static String detectSeparator(String text) {
    final lines = text.split('\n').where((l) => l.trim().isNotEmpty).take(10).toList();
    if (lines.isEmpty) return ',';

    // Score each candidate separator
    final candidates = ['\t', '|', '~', ';', ','];
    final scores = <String, double>{};

    for (final sep in candidates) {
      final counts = lines.map((l) => sep.allMatches(l).length).toList();
      if (counts.every((c) => c == 0)) {
        scores[sep] = 0;
        continue;
      }
      final avg = counts.reduce((a, b) => a + b) / counts.length;
      final nonZero = counts.where((c) => c > 0).length;
      // Prefer separators that appear consistently across lines
      scores[sep] = avg * (nonZero / counts.length);
    }

    final best = scores.entries
        .where((e) => e.value > 0)
        .toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    if (best.isEmpty) {
      // Try space as last resort only if multiple words
      final spaceCount = lines.first.trim().split(RegExp(r'\s+')).length;
      return spaceCount > 2 ? ' ' : ',';
    }
    return best.first.key;
  }

  // ─── Smart Row Splitter ───────────────────────────────────────────────────
  /// Splits a single line by detected separator, handling nested key=value pairs
  static List<String> splitRow(String line, String sep) {
    if (sep == ',') {
      return _splitRespectingQuotes(line, ',');
    }
    return line.split(sep).map((c) => cleanCell(c)).toList();
  }

  static List<String> _splitRespectingQuotes(String line, String sep) {
    final result = <String>[];
    var current = StringBuffer();
    var inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if ((ch == '"' || ch == "'") && !inQuotes) {
        inQuotes = true;
      } else if ((ch == '"' || ch == "'") && inQuotes) {
        inQuotes = false;
      } else if (ch == sep && !inQuotes) {
        result.add(cleanCell(current.toString()));
        current = StringBuffer();
      } else {
        current.write(ch);
      }
    }
    result.add(cleanCell(current.toString()));
    return result;
  }

  // ─── Sub-field Parser (handles key|value pairs within a cell) ─────────────
  /// Parses "CheckIn|01-03-2026" style sub-fields
  static MapEntry<String, String>? parseKeyValuePair(String token) {
    // Format: "Key|Value" or "Key=Value" or "Key:Value"
    final kvPattern = RegExp(r'^([A-Za-z][A-Za-z\s]{0,15})[|=:](.+)$');
    final match = kvPattern.firstMatch(token.trim());
    if (match != null) {
      return MapEntry(match.group(1)!.trim(), match.group(2)!.trim());
    }
    return null;
  }

  // ─── Pattern Detectors ───────────────────────────────────────────────────
  static bool isPhoneNumber(String v) {
    final c = v.replaceAll(RegExp(r'[\s\-\(\)\+]'), '');
    return RegExp(r'^\d{7,15}$').hasMatch(c);
  }

  static bool isEmail(String v) =>
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
          .hasMatch(v.trim());

  static bool isDate(String v) {
    final patterns = [
      RegExp(r'^\d{1,2}[-/]\d{1,2}[-/]\d{2,4}$'),
      RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}$'),
      RegExp(
          r'\d{1,2}\s+(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+\d{4}',
          caseSensitive: false),
      RegExp(
          r'(Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec)\w*\s+\d{1,2},?\s+\d{4}',
          caseSensitive: false),
    ];
    return patterns.any((p) => p.hasMatch(v.trim()));
  }

  static bool isAmount(String v) {
    final c = v.replaceAll(RegExp(r'[₹\$€£¥,\s]'), '').trim();
    return RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(c) &&
        double.tryParse(c) != null;
  }

  static bool isId(String v) {
    final t = v.trim();
    return RegExp(r'^[A-Z]{1,4}\d{2,8}$').hasMatch(t) ||
        RegExp(r'^\d{4,10}$').hasMatch(t);
  }

  static bool isStatus(String v) {
    const s = {
      'confirmed', 'pending', 'cancelled', 'canceled', 'completed',
      'active', 'inactive', 'paid', 'unpaid', 'processing', 'shipped',
      'delivered', 'failed', 'success', 'rejected', 'approved', 'booked',
    };
    return s.contains(v.trim().toLowerCase());
  }

  static bool isName(String v) {
    final parts = v.trim().split(' ');
    if (parts.length < 1 || parts.length > 4) return false;
    return parts.every((p) => RegExp(r'^[A-Za-z\.]+$').hasMatch(p) && p.length >= 2);
  }

  // ─── Column Type Inference ────────────────────────────────────────────────
  static String inferColumnType(List<String> values) {
    final nonEmpty = values.where((v) => v.isNotEmpty).toList();
    if (nonEmpty.isEmpty) return 'Text';
    final total = nonEmpty.length.toDouble();
    int phone = 0, email = 0, date = 0, amount = 0, id = 0, status = 0, name = 0;
    for (final v in nonEmpty) {
      if (isEmail(v)) email++;
      else if (isPhoneNumber(v)) phone++;
      else if (isDate(v)) date++;
      else if (isAmount(v)) amount++;
      else if (isId(v)) id++;
      else if (isStatus(v)) status++;
      else if (isName(v)) name++;
    }
    if (email / total > 0.5) return 'Email';
    if (phone / total > 0.5) return 'Phone';
    if (date  / total > 0.5) return 'Date';
    if (amount/ total > 0.5) return 'Amount';
    if (id    / total > 0.4) return 'ID';
    if (status/ total > 0.4) return 'Status';
    if (name  / total > 0.35) return 'Name';
    return 'Text';
  }

  static String columnTypeToDefaultLabel(String type, int index) {
    const labels = {
      'Email': 'Email', 'Phone': 'Phone', 'Date': 'Date',
      'Amount': 'Amount', 'ID': 'ID', 'Status': 'Status', 'Name': 'Name',
    };
    return labels[type] ?? 'Column ${index + 1}';
  }

  // ─── Data Cleaning ────────────────────────────────────────────────────────
  static String cleanCell(String v) {
    return v
        .trim()
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r"""^['"]+|['"]+$"""), '');
  }

  static String normalizeAmount(String v) {
    final c = v.replaceAll(RegExp(r'[₹\$€£¥,\s]'), '').trim();
    final n = double.tryParse(c);
    if (n == null) return v;
    return n == n.roundToDouble() ? n.toInt().toString() : n.toStringAsFixed(2);
  }

  static String standardizeCapitalization(String v, String type) {
    if (v.isEmpty) return v;
    switch (type) {
      case 'Name':
      case 'City':
        return v.split(' ').map((w) => w.isEmpty
            ? ''
            : '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}').join(' ');
      case 'Email':
        return v.toLowerCase();
      case 'Status':
        return '${v[0].toUpperCase()}${v.substring(1).toLowerCase()}';
      default:
        return v;
    }
  }

  // ─── Confidence Score ─────────────────────────────────────────────────────
  static double calculateConfidence(List<List<String>> rows, List<String> types) {
    if (rows.isEmpty || types.isEmpty) return 0.0;
    int correct = 0, total = 0;
    for (final row in rows.take(30)) {
      for (int i = 0; i < min(row.length, types.length); i++) {
        final v = row[i].trim();
        if (v.isEmpty) continue;
        total++;
        switch (types[i]) {
          case 'Email':  if (isEmail(v))  correct++; break;
          case 'Phone':  if (isPhoneNumber(v)) correct++; break;
          case 'Date':   if (isDate(v))   correct++; break;
          case 'Amount': if (isAmount(v)) correct++; break;
          default:       correct++; // text always counts
        }
      }
    }
    return total == 0 ? 0.0 : correct / total;
  }

  // ─── Header Detection ─────────────────────────────────────────────────────
  static bool looksLikeHeader(List<String> row) {
    if (row.isEmpty) return false;
    int textLike = 0;
    for (final cell in row) {
      final c = cell.trim();
      if (c.isEmpty) continue;
      // Headers: short, mostly letters, no numbers dominating
      if (c.length <= 30 &&
          RegExp(r'^[A-Za-z\s_\-/]+$').hasMatch(c) &&
          !RegExp(r'^\d+$').hasMatch(c)) {
        textLike++;
      }
    }
    final nonEmpty = row.where((c) => c.trim().isNotEmpty).length;
    if (nonEmpty == 0) return false;
    return textLike / nonEmpty >= 0.6;
  }

  // ─── Formatters ───────────────────────────────────────────────────────────
  static String formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static String formatDateTime(DateTime dt) =>
      DateFormat('dd MMM yyyy, hh:mm a').format(dt);
}
