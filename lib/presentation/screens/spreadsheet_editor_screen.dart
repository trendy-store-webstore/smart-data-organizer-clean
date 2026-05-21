import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pluto_grid/pluto_grid.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/parsed_dataset.dart';
import '../providers/app_provider.dart';
import 'export_screen.dart';
import 'column_mapping_screen.dart';

class SpreadsheetEditorScreen extends StatefulWidget {
  final ParsedDataset dataset;
  const SpreadsheetEditorScreen({super.key, required this.dataset});

  @override
  State<SpreadsheetEditorScreen> createState() => _SpreadsheetEditorScreenState();
}

class _SpreadsheetEditorScreenState extends State<SpreadsheetEditorScreen> {
  late PlutoGridStateManager _stateManager;
  late List<PlutoColumn> _columns;
  late List<PlutoRow> _rows;
  late ParsedDataset _dataset;

  final _searchCtrl = TextEditingController();
  bool _showSearch = false;
  final List<ParsedDataset> _undoStack = [];
  final List<ParsedDataset> _redoStack = [];

  @override
  void initState() {
    super.initState();
    _dataset = widget.dataset;
    _buildGridData(_dataset);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _buildGridData(ParsedDataset ds) {
    _columns = ds.headers.asMap().entries.map((e) {
      return PlutoColumn(
        title: e.value,
        field: 'c${e.key}',
        type: PlutoColumnType.text(),
        width: 150,
        enableSorting: true,
        enableContextMenu: true,
        titleTextAlign: PlutoColumnTextAlign.left,
      );
    }).toList();

    _rows = ds.rows.map((row) {
      final cells = <String, PlutoCell>{};
      for (int i = 0; i < ds.headers.length; i++) {
        cells['c$i'] = PlutoCell(value: i < row.length ? row[i] : '');
      }
      return PlutoRow(cells: cells);
    }).toList();
  }

  ParsedDataset _extractDataset() {
    final headers = _columns.map((c) => c.title).toList();
    final rows = _stateManager.rows.map((row) =>
      _columns.map((c) => row.cells[c.field]?.value.toString() ?? '').toList()
    ).toList();
    return _dataset.copyWith(headers: headers, rows: rows);
  }

  void _saveUndo() => _undoStack.add(_extractDataset());

  void _undo() {
    if (_undoStack.isEmpty) return;
    _redoStack.add(_extractDataset());
    _reloadGrid(_undoStack.removeLast());
  }

  void _redo() {
    if (_redoStack.isEmpty) return;
    _undoStack.add(_extractDataset());
    _reloadGrid(_redoStack.removeLast());
  }

  void _reloadGrid(ParsedDataset ds) {
    setState(() {
      _dataset = ds;
      _buildGridData(ds);
    });
  }

  void _addRow() {
    _saveUndo();
    final cells = <String, PlutoCell>{};
    for (final col in _columns) {
      cells[col.field] = PlutoCell(value: '');
    }
    _stateManager.appendRows([PlutoRow(cells: cells)]);
    setState(() {});
  }

  void _deleteSelected() {
    _saveUndo();
    final selected = _stateManager.currentSelectingRows;
    if (selected.isNotEmpty) {
      _stateManager.removeRows(selected);
    } else if (_stateManager.currentRow != null) {
      _stateManager.removeCurrentRow();
    }
    setState(() {});
  }

  void _duplicateSelected() {
    _saveUndo();
    final row = _stateManager.currentRow;
    if (row == null) return;
    final newCells = <String, PlutoCell>{};
    for (final col in _columns) {
      newCells[col.field] = PlutoCell(value: row.cells[col.field]?.value ?? '');
    }
    _stateManager.insertRows(
      _stateManager.rows.indexOf(row) + 1,
      [PlutoRow(cells: newCells)],
    );
    setState(() {});
  }

  void _addColumn() async {
    final name = await _inputDialog('New Column Name', 'Column ${_columns.length + 1}');
    if (name == null || name.isEmpty) return;
    _saveUndo();
    final fieldId = 'cx${DateTime.now().millisecondsSinceEpoch}';
    _stateManager.insertColumns(_columns.length, [
      PlutoColumn(title: name, field: fieldId, type: PlutoColumnType.text(), width: 150),
    ]);
    setState(() {});
  }

  void _searchFilter(String q) {
    if (q.isEmpty) {
      _stateManager.setFilter(null);
    } else {
      _stateManager.setFilter((row) => row.cells.values
          .any((c) => c.value.toString().toLowerCase().contains(q.toLowerCase())));
    }
  }

  void _copyClipboard() {
    final ds = _extractDataset();
    final text = [ds.headers.join('\t'), ...ds.rows.map((r) => r.join('\t'))].join('\n');
    Clipboard.setData(ClipboardData(text: text));
    _snack('Table copied to clipboard');
  }

  void _export() {
    final ds = _extractDataset();
    context.read<AppProvider>().updateDataset(ds);
    Navigator.push(context, MaterialPageRoute(builder: (_) => ExportScreen(dataset: ds)));
  }

  void _openColumnMapping() async {
    final ds = _extractDataset();
    final result = await Navigator.push<ParsedDataset>(
      context,
      MaterialPageRoute(builder: (_) => ColumnMappingScreen(dataset: ds)),
    );
    if (result != null) {
      _saveUndo();
      _reloadGrid(result);
    }
  }

  Future<String?> _inputDialog(String title, String def) async {
    final ctrl = TextEditingController(text: def);
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, autofocus: true,
            decoration: const InputDecoration(hintText: 'Enter name...')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text), child: const Text('OK')),
        ],
      ),
    );
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
  );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_dataset.fileName,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
            Text(
              '${_dataset.rowCount} rows · ${_dataset.columnCount} cols'
              '${_dataset.wasAiParsed ? " · AI" : ""}',
              style: TextStyle(
                  fontSize: 11,
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
            ),
          ]),
        ),
        actions: [
          IconButton(
            icon: Icon(_showSearch ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () => setState(() {
              _showSearch = !_showSearch;
              if (!_showSearch) {
                _searchCtrl.clear();
                _searchFilter('');
              }
            }),
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.view_column_rounded),
            onPressed: _openColumnMapping,
            tooltip: 'Column Mapping',
          ),
          PopupMenuButton<String>(
            onSelected: (v) {
              switch (v) {
                case 'undo': _undo(); break;
                case 'redo': _redo(); break;
                case 'add_col': _addColumn(); break;
                case 'dup_row': _duplicateSelected(); break;
                case 'copy': _copyClipboard(); break;
              }
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'undo', child: _MenuItem(Icons.undo_rounded, 'Undo')),
              const PopupMenuItem(value: 'redo', child: _MenuItem(Icons.redo_rounded, 'Redo')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'add_col', child: _MenuItem(Icons.add_box_rounded, 'Add Column')),
              const PopupMenuItem(value: 'dup_row', child: _MenuItem(Icons.content_copy_rounded, 'Duplicate Row')),
              const PopupMenuDivider(),
              const PopupMenuItem(value: 'copy', child: _MenuItem(Icons.copy_rounded, 'Copy Table')),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ElevatedButton.icon(
              onPressed: _export,
              icon: const Icon(Icons.file_download_rounded, size: 16),
              label: const Text('Export'),
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: Column(children: [
        // AI badge
        if (_dataset.wasAiParsed)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFFF3E8FF),
            child: const Row(children: [
              Icon(Icons.auto_awesome_rounded, size: 14, color: Color(0xFF7C3AED)),
              SizedBox(width: 6),
              Text('Organized using AI', style: TextStyle(fontSize: 12, color: Color(0xFF7C3AED), fontWeight: FontWeight.w500)),
            ]),
          ),
        // Search bar
        if (_showSearch)
          Container(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: Theme.of(context).scaffoldBackgroundColor,
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: _searchFilter,
              decoration: InputDecoration(
                hintText: 'Search rows...',
                isDense: true,
                prefixIcon: const Icon(Icons.search_rounded, size: 18),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () { _searchCtrl.clear(); _searchFilter(''); setState(() {}); },
                      )
                    : null,
              ),
            ),
          ),
        // Toolbar
        _Toolbar(onAddRow: _addRow, onDeleteRow: _deleteSelected),
        // Grid
        Expanded(
          child: PlutoGrid(
            columns: _columns,
            rows: _rows,
            onLoaded: (e) {
              _stateManager = e.stateManager;
              _stateManager.setSelectingMode(PlutoGridSelectingMode.row);
            },
            configuration: PlutoGridConfiguration(
              style: PlutoGridStyleConfig(
                gridBorderColor: Theme.of(context).dividerColor,
                columnTextStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                cellTextStyle: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                gridBackgroundColor: Theme.of(context).scaffoldBackgroundColor,
                rowColor: isDark ? AppColors.darkCard : Colors.white,
                oddRowColor: isDark ? const Color(0xFF172032) : const Color(0xFFF8FAFC),
                activatedColor: AppColors.primary.withOpacity(0.12),
                activatedBorderColor: AppColors.primary,
                columnHeight: 46,
                rowHeight: 42,
              ),
              columnSize: const PlutoGridColumnSizeConfig(
                autoSizeMode: PlutoAutoSizeMode.none,
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

class _Toolbar extends StatelessWidget {
  final VoidCallback onAddRow, onDeleteRow;
  const _Toolbar({required this.onAddRow, required this.onDeleteRow});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(children: [
        _Btn(icon: Icons.add_rounded, label: 'Add Row', color: AppColors.accent, onTap: onAddRow),
        const SizedBox(width: 8),
        _Btn(icon: Icons.delete_outline_rounded, label: 'Delete', color: AppColors.error, onTap: onDeleteRow),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _Btn({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ]),
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _MenuItem(this.icon, this.label);

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Icon(icon, size: 18),
      const SizedBox(width: 10),
      Text(label),
    ]);
  }
}
