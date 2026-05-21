import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/datasources/ad_service.dart';
import 'presentation/providers/app_provider.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/providers/history_provider.dart';
import 'presentation/screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  // Initialize AdMob
  await AdService().initialize();
  runApp(const SmartDataOrganizerApp());
}

class SmartDataOrganizerApp extends StatelessWidget {
  const SmartDataOrganizerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => SettingsProvider()..init()),
        ChangeNotifierProvider(create: (_) => HistoryProvider()..init()),
        ChangeNotifierProvider(create: (_) => AppProvider()),
      ],
      child: Consumer<SettingsProvider>(
        builder: (_, settings, __) => MaterialApp(
          title: 'Smart Data Organizer',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: settings.themeMode,   // ← live rebuild on change
          home: const SplashScreen(),
        ),
      ),
    );
  }
}
