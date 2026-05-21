import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_utils.dart';
import '../../domain/entities/parsed_dataset.dart';
import '../providers/history_provider.dart';
import '../providers/app_provider.dart';
import 'spreadsheet_editor_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('History'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
        actions: [
          Consumer<HistoryProvider>(
            builder: (_, hp, __) => hp.records.isEmpty
                ? const SizedBox()
                : TextButton(
                    onPressed: () => _confirmClear(context, hp),
                    child: const Text('Clear All', style: TextStyle(color: AppColors.error)),
                  ),
          ),
        ],
      ),
      body: Consumer<HistoryProvider>(
        builder: (context, hp, _) {
          if (hp.records.isEmpty) {
            return Center(
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Icon(Icons.history_rounded, size: 72,
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.15)),
                const SizedBox(height: 16),
                const Text('No history yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                const SizedBox(height: 8),
                const Text('Processed files appear here',
                    style: TextStyle(fontSize: 13, color: AppColors.textHint)),
              ]),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: hp.records.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, i) {
              final r = hp.records[i];
              return Dismissible(
                key: Key(r.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: AppColors.error,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) => hp.deleteRecord(r.id),
                child: _HistoryCard(
                  record: r,
                  onTap: () => _open(context, r, hp),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _open(BuildContext ctx, HistoryRecord r, HistoryProvider hp) {
    final ds = hp.getDataset(r.id);
    if (ds == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(
          const SnackBar(content: Text('Could not load this record')));
      return;
    }
    ctx.read<AppProvider>().loadDataset(ds);
    Navigator.push(ctx, MaterialPageRoute(builder: (_) => SpreadsheetEditorScreen(dataset: ds)));
  }

  void _confirmClear(BuildContext ctx, HistoryProvider hp) {
    showDialog(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Remove all history? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(d); hp.clearAll(); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final HistoryRecord record;
  final VoidCallback onTap;
  const _HistoryCard({required this.record, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: record.sourceType == 'paste'
                  ? AppColors.accent.withOpacity(0.1)
                  : AppColors.primaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              record.sourceType == 'paste' ? Icons.content_paste_rounded : Icons.table_chart_rounded,
              color: record.sourceType == 'paste' ? AppColors.accent : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(record.fileName,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                    overflow: TextOverflow.ellipsis),
              ),
              if (record.wasAiParsed)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3E8FF),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('AI',
                      style: TextStyle(fontSize: 10, color: Color(0xFF7C3AED), fontWeight: FontWeight.w700)),
                ),
            ]),
            const SizedBox(height: 3),
            Text('${record.rowCount} rows · ${record.columnCount} columns',
                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            const SizedBox(height: 2),
            Text(AppUtils.formatDateTime(record.processedAt),
                style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
        ]),
      ),
    );
  }
}
