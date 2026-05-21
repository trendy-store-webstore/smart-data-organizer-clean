import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/constants/app_constants.dart';
import '../providers/settings_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: Consumer<SettingsProvider>(
        builder: (context, s, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [

            // ── Appearance ─────────────────────────────────────────────────
            _Header('Appearance'),
            _Card(children: [
              _tile(
                context,
                icon: Icons.palette_rounded,
                iconColor: AppColors.primary,
                title: 'Theme',
                subtitle: _themeName(s.themeMode),
                onTap: () => _themePicker(context, s),
              ),
            ]),

            const SizedBox(height: 6),

            // ── AI Settings ────────────────────────────────────────────────
            _Header('AI Parsing'),
            _Card(children: [
              SwitchListTile(
                value: s.aiEnabled,
                onChanged: s.setAiEnabled,
                secondary: _iconBox(Icons.auto_awesome_rounded, const Color(0xFF8B5CF6)),
                title: const Text('Enable AI Parsing',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                subtitle: const Text('Uses OpenAI GPT when local confidence is low',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              ),
              const Divider(height: 1, indent: 66),
              _tile(
                context,
                icon: Icons.key_rounded,
                iconColor: AppColors.accent,
                title: 'Custom API Key',
                subtitle: s.customApiKey.isEmpty ? 'Using built-in key' : 'Custom key active',
                onTap: () => _apiKeyDialog(context, s),
              ),
            ]),

            const SizedBox(height: 6),

            // ── Export ─────────────────────────────────────────────────────
            _Header('Export'),
            _Card(children: [
              _tile(
                context,
                icon: Icons.file_download_rounded,
                iconColor: const Color(0xFFF59E0B),
                title: 'Default Format',
                subtitle: '.${s.defaultExportFormat.toUpperCase()}',
                onTap: () => _picker(context,
                  title: 'Default Export Format',
                  options: AppConstants.exportFormats.map((f) => '.${f.toUpperCase()}').toList(),
                  selected: '.${s.defaultExportFormat.toUpperCase()}',
                  onSelected: (v) => s.setDefaultExportFormat(v.replaceAll('.', '').toLowerCase()),
                ),
              ),
            ]),

            const SizedBox(height: 6),

            // ── Data Format ────────────────────────────────────────────────
            _Header('Data Formatting'),
            _Card(children: [
              _tile(
                context,
                icon: Icons.calendar_today_rounded,
                iconColor: AppColors.primary,
                title: 'Date Format',
                subtitle: s.dateFormat,
                onTap: () => _picker(context,
                  title: 'Date Format',
                  options: AppConstants.dateFormats,
                  selected: s.dateFormat,
                  onSelected: s.setDateFormat,
                ),
              ),
              const Divider(height: 1, indent: 66),
              _tile(
                context,
                icon: Icons.currency_rupee_rounded,
                iconColor: AppColors.accent,
                title: 'Currency Symbol',
                subtitle: s.currencySymbol,
                onTap: () => _picker(context,
                  title: 'Currency Symbol',
                  options: AppConstants.currencySymbols,
                  selected: s.currencySymbol,
                  onSelected: s.setCurrencySymbol,
                ),
              ),
            ]),

            const SizedBox(height: 6),

            // ── About ──────────────────────────────────────────────────────
            _Header('About'),
            _Card(children: [
              _tile(
                context,
                icon: Icons.info_outline_rounded,
                iconColor: AppColors.primary,
                title: 'Version',
                subtitle: 'v${AppConstants.appVersion}',
                onTap: null,
              ),
            ]),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  String _themeName(ThemeMode m) {
    switch (m) {
      case ThemeMode.light: return 'Light';
      case ThemeMode.dark: return 'Dark';
      case ThemeMode.system: return 'System Default';
    }
  }

  Widget _iconBox(IconData icon, Color color) => Container(
    width: 38, height: 38,
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Icon(icon, color: color, size: 20),
  );

  Widget _tile(BuildContext ctx, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
  }) {
    return ListTile(
      leading: _iconBox(icon, iconColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
      trailing: onTap != null ? const Icon(Icons.arrow_forward_ios_rounded, size: 14) : null,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
    );
  }

  void _themePicker(BuildContext ctx, SettingsProvider s) {
    _picker(ctx,
      title: 'Select Theme',
      options: ['Light', 'Dark', 'System Default'],
      selected: _themeName(s.themeMode),
      onSelected: (v) {
        final mode = v == 'Dark'
            ? ThemeMode.dark
            : v == 'System Default'
                ? ThemeMode.system
                : ThemeMode.light;
        s.setThemeMode(mode);
      },
    );
  }

  void _picker(BuildContext ctx, {
    required String title,
    required List<String> options,
    required String selected,
    required ValueChanged<String> onSelected,
  }) {
    showModalBottomSheet(
      context: ctx,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (bctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(children: [
                Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                const Spacer(),
                IconButton(icon: const Icon(Icons.close_rounded), onPressed: () => Navigator.pop(bctx)),
              ]),
            ),
            const Divider(height: 1),
            ...options.map((opt) => ListTile(
              title: Text(opt),
              trailing: opt == selected
                  ? const Icon(Icons.check_rounded, color: AppColors.primary)
                  : null,
              onTap: () { onSelected(opt); Navigator.pop(bctx); },
            )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _apiKeyDialog(BuildContext ctx, SettingsProvider s) {
    final ctrl = TextEditingController(text: s.customApiKey);
    showDialog(
      context: ctx,
      builder: (d) => AlertDialog(
        title: const Text('Custom OpenAI API Key'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Leave blank to use the built-in key.\n'
              'Enter your own key if you encounter issues.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              obscureText: true,
              decoration: const InputDecoration(
                hintText: 'sk-...',
                labelText: 'API Key',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () { ctrl.text = ''; s.setCustomApiKey(''); Navigator.pop(d); },
            child: const Text('Reset to Default', style: TextStyle(color: AppColors.error)),
          ),
          ElevatedButton(
            onPressed: () { s.setCustomApiKey(ctrl.text); Navigator.pop(d); },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String title;
  const _Header(this.title);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 10, 0, 8),
    child: Text(title,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
            color: AppColors.textSecondary, letterSpacing: 0.5)),
  );
}

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Theme.of(context).dividerColor),
    ),
    child: Column(children: children),
  );
}
