import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../../domain/entities/parsed_dataset.dart';

class ColumnMappingScreen extends StatefulWidget {
  final ParsedDataset dataset;
  const ColumnMappingScreen({super.key, required this.dataset});

  @override
  State<ColumnMappingScreen> createState() => _ColumnMappingScreenState();
}

class _ColumnMappingScreenState extends State<ColumnMappingScreen> {
  late List<TextEditingController> _nameCtrl;
  late List<String> _types;

  @override
  void initState() {
    super.initState();
    _nameCtrl = widget.dataset.headers.map((h) => TextEditingController(text: h)).toList();
    _types = List<String>.from(widget.dataset.columnTypes);
    // Pad types if needed
    while (_types.length < widget.dataset.headers.length) _types.add('Text');
  }

  @override
  void dispose() {
    for (final c in _nameCtrl) c.dispose();
    super.dispose();
  }

  void _apply() {
    final headers = _nameCtrl.map((c) => c.text.trim().isEmpty ? 'Column' : c.text.trim()).toList();
    Navigator.pop(context, widget.dataset.copyWith(headers: headers, columnTypes: _types));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Column Mapping'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
        actions: [
          TextButton(
            onPressed: _apply,
            child: const Text('Apply', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: Column(children: [
        Container(
          padding: const EdgeInsets.all(14),
          color: AppColors.primaryLight,
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 15, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text('Rename columns and set their data type.',
                  style: TextStyle(fontSize: 12, color: AppColors.primary)),
            ),
          ]),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: widget.dataset.headers.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _ColumnCard(
              index: i + 1,
              ctrl: _nameCtrl[i],
              type: _types[i],
              samples: widget.dataset.rows.take(3).map((r) => i < r.length ? r[i] : '').where((v) => v.isNotEmpty).toList(),
              onTypeChanged: (t) => setState(() => _types[i] = t),
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: ElevatedButton(
              onPressed: _apply,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text('Apply Column Mapping'),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ColumnCard extends StatelessWidget {
  final int index;
  final TextEditingController ctrl;
  final String type;
  final List<String> samples;
  final ValueChanged<String> onTypeChanged;

  const _ColumnCard({
    required this.index,
    required this.ctrl,
    required this.type,
    required this.samples,
    required this.onTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(7)),
            child: Center(child: Text('$index',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12))),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: ctrl,
              decoration: const InputDecoration(hintText: 'Column name', isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Text('Type: ', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: AppConstants.columnTypes.contains(type) ? type : 'Text',
              isDense: true,
              decoration: const InputDecoration(isDense: true,
                  contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8)),
              items: AppConstants.columnTypes.map((t) =>
                  DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) { if (v != null) onTypeChanged(v); },
            ),
          ),
        ]),
        if (samples.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text('Sample: ${samples.join(', ')}',
              style: const TextStyle(fontSize: 11, color: AppColors.textHint),
              overflow: TextOverflow.ellipsis),
        ],
      ]),
    );
  }
}
