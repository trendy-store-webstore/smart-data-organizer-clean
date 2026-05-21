import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:dotted_border/dotted_border.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../core/utils/app_utils.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/history_provider.dart';
import 'parsing_progress_screen.dart';

class ImportScreen extends StatefulWidget {
  const ImportScreen({super.key});
  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  PlatformFile? _file;
  String? _preview;

  Future<void> _pick() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: AppConstants.supportedExtensions,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final f = result.files.first;
      setState(() {
        _file = f;
        _preview = _genPreview(f);
      });
    } catch (e) {
      _snack('Could not pick file: $e');
    }
  }

  String? _genPreview(PlatformFile f) {
    if (f.bytes == null) return null;
    final ext = f.extension?.toLowerCase() ?? '';
    if (['txt', 'csv', 'json'].contains(ext)) {
      try {
        return String.fromCharCodes(f.bytes!.take(1500));
      } catch (_) {}
    }
    return '${f.name} — ${AppUtils.formatFileSize(f.size)}';
  }

  Future<void> _process() async {
    if (_file == null) return;
    final app = context.read<AppProvider>();
    final settings = context.read<SettingsProvider>();
    final history = context.read<HistoryProvider>();

    if (!mounted) return;
    Navigator.push(context,
        MaterialPageRoute(builder: (_) => ParsingProgressScreen(
          fileName: _file!.name,
          onComplete: (ds) => history.addRecord(ds),
        )));

    try {
      final tmp = await getTemporaryDirectory();
      final tmpFile = File('${tmp.path}/${_file!.name}');
      await tmpFile.writeAsBytes(_file!.bytes!);
      await app.parseFile(
        filePath: tmpFile.path,
        fileName: _file!.name,
        aiEnabled: settings.aiEnabled,
        apiKey: settings.activeApiKey,
      );
    } catch (e) {
      if (mounted) _snack('Error: $e');
    }
  }

  void _snack(String msg) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(msg), backgroundColor: AppColors.error));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Upload File'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Drop zone
          GestureDetector(
            onTap: _pick,
            child: DottedBorder(
              color: _file != null ? AppColors.accent : AppColors.primary.withOpacity(0.45),
              strokeWidth: 2,
              dashPattern: const [8, 4],
              borderType: BorderType.RRect,
              radius: const Radius.circular(16),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 44),
                decoration: BoxDecoration(
                  color: _file != null
                      ? AppColors.accent.withOpacity(0.05)
                      : AppColors.primary.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(children: [
                  Icon(
                    _file != null ? Icons.check_circle_rounded : Icons.cloud_upload_rounded,
                    size: 54,
                    color: _file != null ? AppColors.accent : AppColors.primary,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    _file != null ? _file!.name : 'Tap to select a file',
                    style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: _file != null ? AppColors.accent : AppColors.primary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _file != null
                        ? AppUtils.formatFileSize(_file!.size)
                        : 'Supports: .xlsx  .xls  .csv  .txt  .json',
                    style: TextStyle(fontSize: 12,
                        color: _file != null ? AppColors.accent.withOpacity(0.8) : AppColors.textSecondary),
                  ),
                ]),
              ),
            ),
          ),
          if (_preview != null && _preview!.length > 5) ...[
            const SizedBox(height: 20),
            const Text('Raw Preview', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              constraints: const BoxConstraints(maxHeight: 180),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                child: Text(
                  _preview!.length > 900 ? '${_preview!.substring(0, 900)}…' : _preview!,
                  style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: Color(0xFF94D2BD)),
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          _InfoCard(),
          const SizedBox(height: 100),
        ]),
      ),
      bottomNavigationBar: _file != null
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => setState(() { _file = null; _preview = null; }),
                      child: const Text('Clear'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _process,
                      icon: const Icon(Icons.auto_fix_high_rounded),
                      label: const Text('Parse & Organize'),
                    ),
                  ),
                ]),
              ),
            )
          : null,
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('What can be parsed?', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
        const SizedBox(height: 10),
        ...[
          'Excel files with single or multiple sheets',
          'CSV with comma, tab, semicolon delimiters',
          'Text files with pipe (|), tilde (~) separators',
          'JSON arrays and objects',
          'Messy unstructured data (AI fallback)',
        ].map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 5),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('• ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          ]),
        )),
      ]),
    );
  }
}
