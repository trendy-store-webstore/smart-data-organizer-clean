import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../../core/theme/app_theme.dart';
import '../../domain/entities/parsed_dataset.dart';
import '../providers/app_provider.dart';
import 'spreadsheet_editor_screen.dart';

class ParsingProgressScreen extends StatefulWidget {
  final String fileName;
  final Function(ParsedDataset)? onComplete;

  const ParsingProgressScreen({
    super.key,
    required this.fileName,
    this.onComplete,
  });

  @override
  State<ParsingProgressScreen> createState() => _ParsingProgressScreenState();
}

class _ParsingProgressScreenState extends State<ParsingProgressScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    // Listen after first frame so provider is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AppProvider>().addListener(_onStateChange);
    });
  }

  @override
  void dispose() {
    context.read<AppProvider>().removeListener(_onStateChange);
    super.dispose();
  }

  void _onStateChange() {
    if (_navigated || !mounted) return;
    final provider = context.read<AppProvider>();

    if (provider.state == ParseState.success && provider.dataset != null) {
      _navigated = true;
      widget.onComplete?.call(provider.dataset!);
      final ds = provider.dataset!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => SpreadsheetEditorScreen(dataset: ds)),
        );
      });
    } else if (provider.state == ParseState.error) {
      _navigated = true;
      final err = provider.errorMessage ?? 'Parsing failed';
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(err), backgroundColor: AppColors.error),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false, // prevent back during parsing
      child: Scaffold(
        body: Consumer<AppProvider>(
          builder: (_, provider, __) => Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF1D4ED8), Color(0xFF2563EB), Color(0xFF0EA5E9)],
              ),
            ),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(36),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Spinner
                    Container(
                      width: 110,
                      height: 110,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const SpinKitDoubleBounce(color: Colors.white, size: 80),
                    ),
                    const SizedBox(height: 36),
                    const Text(
                      'Processing Your Data',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.fileName,
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 36),
                    // Progress bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: provider.progress,
                        minHeight: 8,
                        backgroundColor: Colors.white24,
                        valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      provider.statusMessage.isEmpty
                          ? 'Initializing...'
                          : provider.statusMessage,
                      style: const TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                    const SizedBox(height: 48),
                    _StepsRow(progress: provider.progress),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StepsRow extends StatelessWidget {
  final double progress;
  const _StepsRow({required this.progress});

  @override
  Widget build(BuildContext context) {
    final steps = [
      {'label': 'Read',    'at': 0.15},
      {'label': 'Parse',   'at': 0.40},
      {'label': 'Analyze', 'at': 0.65},
      {'label': 'Clean',   'at': 0.88},
      {'label': 'Done',    'at': 1.00},
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: steps.asMap().entries.map((e) {
        final done = progress >= (e.value['at'] as double);
        return Row(children: [
          Column(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: done ? Colors.white : Colors.white24,
                shape: BoxShape.circle,
              ),
              child: Icon(
                done ? Icons.check_rounded : Icons.circle,
                size: done ? 18 : 8,
                color: done ? AppColors.primary : Colors.white54,
              ),
            ),
            const SizedBox(height: 5),
            Text(e.value['label'] as String,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  color: done ? Colors.white : Colors.white38,
                )),
          ]),
          if (e.key < steps.length - 1)
            Container(
              width: 26, height: 2,
              color: progress > (e.value['at'] as double) ? Colors.white : Colors.white24,
            ),
        ]);
      }).toList(),
    );
  }
}
