import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../providers/app_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/history_provider.dart';
import 'parsing_progress_screen.dart';

class PasteTextScreen extends StatefulWidget {
  const PasteTextScreen({super.key});
  @override
  State<PasteTextScreen> createState() => _PasteTextScreenState();
}

class _PasteTextScreenState extends State<PasteTextScreen> {
  final _ctrl = TextEditingController();
  bool _hasText = false;

  static const _examples = [
    {
      'label': 'Simple CSV',
      'text': 'Rahul Sharma, Delhi, 9876543210, rahul@gmail.com\n'
          'Priya Verma, Mumbai, 8765432109, priya@yahoo.com\n'
          'Ajay Kumar, Kolkata, 7654321098, ajay@outlook.com',
    },
    {
      'label': 'Booking data (tilde)',
      'text': 'B001~Rahul Sharma~Delhi~CheckIn|01-03-2026~CheckOut|03-03-2026~Guests|2~4500~Confirmed\n'
          'B002~Priya Verma~Mumbai~CheckIn|05-03-2026~CheckOut|07-03-2026~Guests|1~3200~Pending\n'
          'B003~Ajay Kumar~Kolkata~CheckIn|10-03-2026~CheckOut|12-03-2026~Guests|3~6000~Confirmed',
    },
    {
      'label': 'Natural language',
      'text': 'Rahul from Delhi arriving 1 March, 2 guests, paid 4500, confirmed\n'
          'Priya from Mumbai arriving 5 March, 1 guest, paid 3200, pending\n'
          'Ajay from Kolkata arriving 10 March, 3 guests, paid 6000, confirmed',
    },
  ];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  Future<void> _parse() async {
    final text = _ctrl.text.trim();
    if (text.isEmpty) return;
    final app = context.read<AppProvider>();
    final settings = context.read<SettingsProvider>();
    final history = context.read<HistoryProvider>();

    if (!mounted) return;
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ParsingProgressScreen(
        fileName: 'Pasted Data',
        onComplete: (ds) => history.addRecord(ds),
      ),
    ));

    await app.parsePastedText(
      text: text,
      aiEnabled: settings.aiEnabled,
      apiKey: settings.activeApiKey,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paste Raw Text'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, color: Theme.of(context).dividerColor),
        ),
      ),
      body: Column(children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Input box
              Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).cardTheme.color,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _hasText ? AppColors.primary : Theme.of(context).dividerColor,
                    width: _hasText ? 2 : 1,
                  ),
                ),
                child: Column(children: [
                  TextField(
                    controller: _ctrl,
                    maxLines: 14,
                    onChanged: (v) => setState(() => _hasText = v.trim().isNotEmpty),
                    style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                    decoration: const InputDecoration(
                      hintText: 'Paste your data here…\n\nExamples:\n'
                          '• Name, City, Phone, Email\n'
                          '• ID~Name~Date~Amount~Status\n'
                          '• Natural language sentences',
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.all(14),
                    ),
                  ),
                  if (_ctrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('${_ctrl.text.split('\n').length} lines',
                            style: const TextStyle(fontSize: 11, color: AppColors.textHint)),
                        TextButton(
                          onPressed: () { _ctrl.clear(); setState(() => _hasText = false); },
                          child: const Text('Clear', style: TextStyle(color: AppColors.error)),
                        ),
                      ]),
                    ),
                ]),
              ),
              const SizedBox(height: 20),
              const Text('Try an example:', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              ..._examples.map((ex) => _ExampleTile(
                label: ex['label']!,
                text: ex['text']!,
                onTap: () { _ctrl.text = ex['text']!; setState(() => _hasText = true); },
              )),
              const SizedBox(height: 16),
              _TipsCard(),
            ]),
          ),
        ),
        // Bottom bar
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: ElevatedButton.icon(
              onPressed: _hasText ? _parse : null,
              icon: const Icon(Icons.auto_fix_high_rounded),
              label: const Text('Parse & Organize'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
          ),
        ),
      ]),
    );
  }
}

class _ExampleTile extends StatelessWidget {
  final String label, text;
  final VoidCallback onTap;
  const _ExampleTile({required this.label, required this.text, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Theme.of(context).cardTheme.color,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: AppColors.primary)),
            const SizedBox(height: 3),
            Text(text.length > 90 ? '${text.substring(0, 90)}…' : text,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace', color: AppColors.textSecondary)),
          ])),
          const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textHint),
        ]),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1A05) : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.warning.withOpacity(0.3)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.lightbulb_outline_rounded, size: 16, color: AppColors.warning),
          SizedBox(width: 6),
          Text('Tips', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.warning, fontSize: 13)),
        ]),
        const SizedBox(height: 8),
        ...[
          'Each line = one record',
          'Separators: comma, tab, pipe (|), tilde (~), semicolon',
          'AI fallback handles natural language text',
          'Enable AI in Settings for best results',
        ].map((t) => Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('• ', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w700)),
            Expanded(child: Text(t, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary))),
          ]),
        )),
      ]),
    );
  }
}
