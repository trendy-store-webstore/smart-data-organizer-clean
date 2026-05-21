import 'dart:convert';
import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/parsed_dataset.dart';

class ExportService {

  /// Requests storage write permission (Android)
  Future<bool> requestStoragePermission() async {
    if (Platform.isAndroid) {
      final sdkInt = await _androidSdkVersion();
      if (sdkInt >= 30) {
        // Android 11+ — use MANAGE_EXTERNAL_STORAGE or scoped storage
        final status = await Permission.manageExternalStorage.request();
        return status.isGranted;
      } else {
        final status = await Permission.storage.request();
        return status.isGranted;
      }
    }
    return true;
  }

  Future<int> _androidSdkVersion() async {
    try {
      final result = await Process.run('getprop', ['ro.build.version.sdk']);
      return int.tryParse(result.stdout.toString().trim()) ?? 29;
    } catch (_) {
      return 29;
    }
  }

  /// Returns a writable path in Downloads if possible, else app documents dir
  Future<String> _getExportDir() async {
    if (Platform.isAndroid) {
      // Try Downloads folder
      final downloadsDir = Directory('/storage/emulated/0/Download');
      if (await downloadsDir.exists()) {
        final appFolder = Directory('${downloadsDir.path}/SmartDataOrganizer');
        if (!await appFolder.exists()) await appFolder.create(recursive: true);
        return appFolder.path;
      }
    }
    final dir = await getApplicationDocumentsDirectory();
    return dir.path;
  }

  Future<ExportResult> export({
    required ParsedDataset dataset,
    required String format,
    bool shareAfter = false,
  }) async {
    try {
      // Request permission first
      final hasPermission = await requestStoragePermission();
      if (!hasPermission) {
        return ExportResult.failure(
            'Storage permission denied. Please allow in Settings → App → Permissions.');
      }

      final dir = await _getExportDir();
      final baseName = dataset.fileName
          .replaceAll(RegExp(r'\.[^.]+$'), '')
          .replaceAll(RegExp(r'[^A-Za-z0-9_\-]'), '_');
      final ts = DateTime.now().millisecondsSinceEpoch;
      final filePath = '$dir/${baseName}_$ts.$format';

      List<int> bytes;
      switch (format.toLowerCase()) {
        case 'xlsx': bytes = _buildXlsx(dataset); break;
        case 'csv':  bytes = _buildCsv(dataset);  break;
        case 'json': bytes = _buildJson(dataset);  break;
        case 'txt':  bytes = _buildTxt(dataset);   break;
        case 'pdf':  bytes = await _buildPdf(dataset); break;
        default: return ExportResult.failure('Unknown format: $format');
      }

      await File(filePath).writeAsBytes(bytes);

      if (shareAfter) {
        await Share.shareXFiles([XFile(filePath)],
            subject: 'Export: ${dataset.fileName}');
      }

      return ExportResult.success(filePath);
    } catch (e) {
      return ExportResult.failure('Export failed: $e');
    }
  }

  List<int> _buildXlsx(ParsedDataset dataset) {
    final excel = Excel.createExcel();
    final sheet = excel['Data'];

    final headerStyle = CellStyle(
      bold: true,
      backgroundColorHex: ExcelColor.fromHexString('#2563EB'),
      fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    );

    for (int c = 0; c < dataset.headers.length; c++) {
      final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: 0));
      cell.value = TextCellValue(dataset.headers[c]);
      cell.cellStyle = headerStyle;
      sheet.setColumnWidth(c, 20);
    }

    for (int r = 0; r < dataset.rows.length; r++) {
      for (int c = 0; c < dataset.rows[r].length; c++) {
        final cell = sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: r + 1));
        cell.value = TextCellValue(dataset.rows[r][c]);
      }
    }

    return excel.encode()!;
  }

  List<int> _buildCsv(ParsedDataset dataset) {
    final data = [dataset.headers, ...dataset.rows];
    return utf8.encode(const ListToCsvConverter().convert(data));
  }

  List<int> _buildJson(ParsedDataset dataset) {
    final records = dataset.rows.map((row) {
      final m = <String, String>{};
      for (int i = 0; i < dataset.headers.length; i++) {
        m[dataset.headers[i]] = i < row.length ? row[i] : '';
      }
      return m;
    }).toList();
    return utf8.encode(const JsonEncoder.withIndent('  ').convert(records));
  }

  List<int> _buildTxt(ParsedDataset dataset) {
    final buf = StringBuffer();
    final widths = List.generate(dataset.headers.length, (i) {
      int w = dataset.headers[i].length;
      for (final row in dataset.rows) {
        if (i < row.length && row[i].length > w) w = row[i].length;
      }
      return w + 2;
    });
    final totalWidth = widths.fold(0, (a, b) => a + b) + (widths.length - 1) * 3;

    for (int i = 0; i < dataset.headers.length; i++) {
      buf.write(dataset.headers[i].padRight(widths[i]));
      if (i < dataset.headers.length - 1) buf.write(' | ');
    }
    buf.writeln();
    buf.writeln('-' * totalWidth);
    for (final row in dataset.rows) {
      for (int i = 0; i < dataset.headers.length; i++) {
        final v = i < row.length ? row[i] : '';
        buf.write(v.padRight(widths[i]));
        if (i < dataset.headers.length - 1) buf.write(' | ');
      }
      buf.writeln();
    }
    return utf8.encode(buf.toString());
  }

  Future<List<int>> _buildPdf(ParsedDataset dataset) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(20),
        build: (ctx) => [
          pw.Text(dataset.fileName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('${dataset.rowCount} rows × ${dataset.columnCount} columns',
              style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600)),
          pw.SizedBox(height: 12),
          pw.Table(
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
            columnWidths: {
              for (int i = 0; i < dataset.headers.length; i++)
                i: const pw.FlexColumnWidth(1),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.blue700),
                children: dataset.headers
                    .map((h) => pw.Padding(
                          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: pw.Text(h,
                              style: pw.TextStyle(
                                  color: PdfColors.white,
                                  fontWeight: pw.FontWeight.bold,
                                  fontSize: 8)),
                        ))
                    .toList(),
              ),
              ...dataset.rows.asMap().entries.map((e) => pw.TableRow(
                    decoration: pw.BoxDecoration(
                        color: e.key % 2 == 0 ? PdfColors.white : PdfColors.blue50),
                    children: e.value
                        .map((cell) => pw.Padding(
                              padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 3),
                              child: pw.Text(cell,
                                  style: const pw.TextStyle(fontSize: 7)),
                            ))
                        .toList(),
                  )),
            ],
          ),
        ],
      ),
    );
    return pdf.save();
  }

  String getClipboardText(ParsedDataset dataset) {
    final rows = [dataset.headers, ...dataset.rows];
    return rows.map((r) => r.join('\t')).join('\n');
  }
}

class ExportResult {
  final String? filePath;
  final String? error;
  final bool success;

  const ExportResult._({this.filePath, this.error, required this.success});
  factory ExportResult.success(String path) => ExportResult._(filePath: path, success: true);
  factory ExportResult.failure(String e) => ExportResult._(error: e, success: false);
}
