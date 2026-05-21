class AppConstants  
  // ─── OpenAI ──────────────────────────────────────────────────────────────
  // Default key (kept private inside the app)
  static const String defaultOpenAiKey = 'TEST_KEY';
  static const String openAiBaseUrl =
      'https://api.openai.com/v1/chat/completions';
  static const String openAiModel = 'gpt-3.5-turbo';

  // ─── AdMob Test IDs (replace with real IDs before publishing) ────────────
  static const String admobAppId =
      'ca-app-pub-3940256099942544~3347511713'; // Test app ID
  static const String bannerAdUnitId =
      'ca-app-pub-3940256099942544/6300978111'; // Test banner
  static const String interstitialAdUnitId =
      'ca-app-pub-3940256099942544/1033173712'; // Test interstitial

  // ─── App Info ─────────────────────────────────────────────────────────────
  static const String appName = 'Smart Data Organizer';
  static const String appVersion = '1.0.0';

  // ─── SharedPreferences Keys ────────────────────────────────────────────────
  static const String keyThemeMode = 'theme_mode';
  static const String keyAiEnabled = 'ai_enabled';
  static const String keyDefaultExportFormat = 'default_export_format';
  static const String keyDateFormat = 'date_format';
  static const String keyCurrencySymbol = 'currency_symbol';
  static const String keyHistory = 'history_records';
  static const String keyCustomApiKey = 'custom_api_key';

  // ─── Parsing ──────────────────────────────────────────────────────────────
  static const double aiConfidenceThreshold = 0.55;
  static const int maxFileSizeMB = 50;

  // ─── Supported extensions ─────────────────────────────────────────────────
  static const List<String> supportedExtensions = [
    'xlsx', 'xls', 'csv', 'txt', 'json'
  ];

  // ─── Export formats ───────────────────────────────────────────────────────
  static const List<String> exportFormats = ['xlsx', 'csv', 'json', 'txt', 'pdf'];

  // ─── Date formats ─────────────────────────────────────────────────────────
  static const List<String> dateFormats = [
    'dd-MM-yyyy', 'MM-dd-yyyy', 'yyyy-MM-dd', 'dd/MM/yyyy', 'MM/dd/yyyy',
  ];

  // ─── Currency symbols ─────────────────────────────────────────────────────
  static const List<String> currencySymbols = ['₹', '\$', '€', '£', '¥'];

  // ─── Column type labels ───────────────────────────────────────────────────
  static const List<String> columnTypes = [
    'Text', 'Name', 'Phone', 'Email', 'Date',
    'Amount', 'City', 'ID', 'Status', 'Number', 'Address', 'Notes',
  ];
}
