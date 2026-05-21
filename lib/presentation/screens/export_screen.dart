import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../../data/datasources/export_service.dart';
import '../../domain/entities/parsed_dataset.dart';
import '../providers/settings_provider.dart';

class ExportScreen extends StatefulWidget {
  final ParsedDataset dataset;
  const ExportScreen({super.key, required this.dataset});

  @override
  State<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends State<ExportScreen> {
  final _service = ExportService();
  late String _format;
  bool _loading = false;
  String? _savedPath;

  @override
  void initState() {
    super.initState();
    _format = context.read<SettingsProvider>().defaultExportFormat;
  }

  Future<void> _export({bool share = false}) async {
    setState(() { _loading = true; _savedPath = null; });
    final result = await _service.export(dataset: widget.dataset, format: _format, shareAfter: share);
    setState(() => _loading = false);
    if (result.success) {
      setState(() => _savedPath = result.filePath);
      _snack('Saved to: ${result.filePath}', success: true);
    } else {
      _snack(result.error ?? 'Export failed', success: false);
    }
  }

  void _copyClipboard() {
    final text = _service.getClipboardText(widget.dataset);
    Clipboard.setData(ClipboardData(text: text));
    _snack('Copied to clipboard!', success: true);
  }

  void _snack(String msg, {required bool success}) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        backgroundColor: success ? AppColors.accent : AppColors.error,
        duration: const Duration(seconds: 4),
      ));

  @override
  Widget build(BuildContext context) {
    final ds = widget.dataset;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Export Data'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Summary
          _SummaryCard(dataset: ds),
          const SizedBox(height: 24),
          const Text('Select Format', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...AppConstants.exportFormats.map((f) => _FormatTile(
            format: f,
            selected: _format == f,
            onTap: () => setState(() => _format = f),
          )),
          const SizedBox(height: 20),
          if (_savedPath != null) ...[
            _SavedCard(path: _savedPath!),
            const SizedBox(height: 16),
          ],
          // Buttons
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.all(20),
              child: CircularProgressIndicator(),
            ))
          else ...[
            ElevatedButton.icon(
              onPressed: () => _export(share: false),
              icon: const Icon(Icons.save_alt_rounded),
              label: const Text('Save to Downloads'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => _export(share: true),
              icon: const Icon(Icons.share_rounded),
              label: const Text('Export & Share'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _copyClipboard,
              icon: const Icon(Icons.copy_rounded),
              label: const Text('Copy Table to Clipboard'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ],
          const SizedBox(height: 20),
          _StorageNote(),
        ]),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final ParsedDataset dataset;
  const _SummaryCard({required this.dataset});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(children: [
        Container(
          width: 50, height: 50,
          decoration: BoxDecoration(color: AppColors.primaryLight, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.table_chart_rounded, color: AppColors.primary, size: 26),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(dataset.fileName,
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          Text('${dataset.rowCount} rows · ${dataset.columnCount} columns',
              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          Text('Confidence: ${(dataset.confidence * 100).toStringAsFixed(0)}%'
               '${dataset.wasAiParsed ? " (AI)" : ""}',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
        ])),
      ]),
    );
  }
}

class _FormatTile extends StatelessWidget {
  final String format;
  final bool selected;
  final VoidCallback onTap;
  const _FormatTile({required this.format, required this.selected, required this.onTap});

  static const _meta = {
    'xlsx': {'icon': Icons.table_chart_rounded,     'color': 0xFF059669, 'desc': 'Excel Spreadsheet'},
    'csv':  {'icon': Icons.grid_on_rounded,          'color': 0xFF0891B2, 'desc': 'Comma-Separated Values'},
    'json': {'icon': Icons.data_object_rounded,      'color': 0xFFF59E0B, 'desc': 'JSON — for developers'},
    'txt':  {'icon': Icons.text_snippet_rounded,     'color': 0xFF64748B, 'desc': 'Plain text table'},
    'pdf':  {'icon': Icons.picture_as_pdf_rounded,   'color': 0xFFDC2626, 'desc': 'PDF — for printing'},
  };

  @override
  Widget build(BuildContext context) {
    final m = _meta[format] ?? _meta['txt']!;
    final color = Color(m['color'] as int);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? color.withOpacity(0.06) : Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: selected ? color : Theme.of(context).dividerColor, width: selected ? 2 : 1),
        ),
        child: Row(children: [
          Icon(m['icon'] as IconData, color: color, size: 26),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('.${format.toUpperCase()}',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: color)),
            Text(m['desc'] as String,
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          ])),
          if (selected)
            Icon(Icons.check_circle_rounded, color: color)
          else
            const Icon(Icons.radio_button_unchecked_rounded, color: AppColors.textHint),
        ]),
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final String path;
  const _SavedCard({required this.path});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.accent.withOpacity(0.4)),
      ),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('File saved!',
              style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.accent, fontSize: 13)),
          Text(path,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
              overflow: TextOverflow.ellipsis),
        ])),
      ]),
    );
  }
}

class _StorageNote extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.folder_open_rounded, size: 16, color: AppColors.warning),
        SizedBox(width: 8),
        Expanded(child: Text(
          'Files are saved to: Downloads/SmartDataOrganizer/\n'
          'The app will request storage permission before saving.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        )),
      ]),
    );
  }
}
