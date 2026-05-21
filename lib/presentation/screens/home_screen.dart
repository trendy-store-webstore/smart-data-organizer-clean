import 'package:flutter/material.dart';
import 'package:animate_do/animate_do.dart';
import '../../core/theme/app_theme.dart';
import '../../data/datasources/ad_service.dart';
import 'import_screen.dart';
import 'paste_text_screen.dart';
import 'history_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _go(BuildContext ctx, Widget screen) =>
      Navigator.push(ctx, MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 190,
            floating: false,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Icon(Icons.table_chart_rounded, color: Colors.white, size: 28),
                            Row(
                              children: [
                                _iconBtn(Icons.history_rounded, () => _go(context, const HistoryScreen())),
                                const SizedBox(width: 4),
                                _iconBtn(Icons.settings_rounded, () => _go(context, const SettingsScreen())),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        const Text('Smart Data Organizer',
                            style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 5),
                        const Text('Import messy data → Clean structured table',
                            style: TextStyle(color: Colors.white70, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                FadeInUp(child: _sectionTitle('Import Data')),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 80),
                  child: _ImportCard(
                    icon: Icons.upload_file_rounded,
                    title: 'Upload File',
                    subtitle: '.xlsx  ·  .xls  ·  .csv  ·  .txt  ·  .json',
                    color: AppColors.primary,
                    onTap: () => _go(context, const ImportScreen()),
                  ),
                ),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 140),
                  child: _ImportCard(
                    icon: Icons.content_paste_rounded,
                    title: 'Paste Raw Text',
                    subtitle: 'Paste messy data — AI will organize it',
                    color: AppColors.accent,
                    onTap: () => _go(context, const PasteTextScreen()),
                  ),
                ),
                const SizedBox(height: 24),
                // Banner ad
                const BannerAdWidget(),
                const SizedBox(height: 20),
                FadeInUp(delay: const Duration(milliseconds: 200), child: _sectionTitle('Features')),
                const SizedBox(height: 12),
                FadeInUp(
                  delay: const Duration(milliseconds: 250),
                  child: _FeaturesGrid(),
                ),
                const SizedBox(height: 24),
                FadeInUp(delay: const Duration(milliseconds: 300), child: _FormatsCard()),
                const SizedBox(height: 30),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => Material(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(8), child: Icon(icon, color: Colors.white, size: 22)),
        ),
      );

  Widget _sectionTitle(String t) => Text(t,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700));
}

class _ImportCard extends StatelessWidget {
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;
  const _ImportCard({required this.icon, required this.title, required this.subtitle, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).cardTheme.color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Row(
            children: [
              Container(
                width: 50, height: 50,
                decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(subtitle, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55))),
                ]),
              ),
              Icon(Icons.arrow_forward_ios_rounded, size: 15, color: color.withOpacity(0.7)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeaturesGrid extends StatelessWidget {
  static const _items = [
    {'icon': Icons.auto_fix_high_rounded,    'label': 'AI Parsing',    'c': 0xFF8B5CF6},
    {'icon': Icons.table_rows_rounded,       'label': 'Excel Editor',  'c': 0xFF059669},
    {'icon': Icons.file_download_rounded,    'label': 'Export PDF/XLS','c': 0xFFDC2626},
    {'icon': Icons.history_rounded,          'label': 'File History',  'c': 0xFFF59E0B},
    {'icon': Icons.wifi_off_rounded,         'label': 'Works Offline', 'c': 0xFF0891B2},
    {'icon': Icons.cleaning_services_rounded,'label': 'Auto Clean',    'c': 0xFF7C3AED},
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 1.1),
      itemCount: _items.length,
      itemBuilder: (_, i) {
        final item = _items[i];
        final color = Color(item['c'] as int);
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardTheme.color,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(item['icon'] as IconData, color: color, size: 28),
            const SizedBox(height: 8),
            Text(item['label'] as String,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
          ]),
        );
      },
    );
  }
}

class _FormatsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkCard : AppColors.primaryLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Row(children: [
          Icon(Icons.info_outline_rounded, size: 16, color: AppColors.primary),
          SizedBox(width: 8),
          Text('Supported Formats', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.primary, fontSize: 13)),
        ]),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6, runSpacing: 6,
          children: ['.xlsx', '.xls', '.csv', '.txt', '.json', 'Paste Text'].map((f) =>
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(6)),
              child: Text(f, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            )
          ).toList(),
        ),
      ]),
    );
  }
}
