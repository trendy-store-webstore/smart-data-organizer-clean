# Smart Data Organizer v2 📊
> AI-Powered Excel-like Data Cleaner — Android

---

## ✅ All Errors Fixed in This Version

| # | Error | Fix Applied |
|---|---|---|
| 1 | Flutter Gradle old syntax | Modern `plugins {}` syntax in settings.gradle & build.gradle |
| 2 | `kotlin_version` undefined | Fixed dependency: `kotlin-stdlib:1.9.0` |
| 3 | pluto_grid ^8.4.1 not found | Pinned to `pluto_grid: 8.0.0` |
| 4 | `isAlwaysShownScrollbar` deprecated | Removed |
| 5 | flutter_spinkit `.withValues` error | Pinned to `flutter_spinkit: 5.1.0` |
| 6 | file_picker mismatch | Pinned to `file_picker: 6.1.1` |
| 7 | Regex `+` not a prefix operator | Fixed to `r"""^['"]+..."""` |
| 8 | Missing assets/icons/ directory | Removed asset reference from pubspec |
| 9 | `ic_launcher` not found | Using `@android:drawable/sym_def_app_icon` |

---

## 🚀 Setup (3 steps)

```bash
# 1. Extract ZIP
cd smart_data_organizer_v2

# 2. Get packages
flutter pub get

# 3. Run on Android device/emulator
flutter run
```

**Build APK:**
```bash
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

> ⚠️ Requires Flutter 3.22.3+ and Android SDK 21+

---

## 🔑 API Key

The OpenAI key is already embedded. To use your own key:
- Open the app → **Settings → Custom API Key** → paste your `sk-...` key

Or edit directly in:
```
lib/core/constants/app_constants.dart  →  defaultOpenAiKey
```

---

## 📂 File Storage

Exports are saved to: **Downloads/SmartDataOrganizer/**

The app requests storage permission automatically before saving.
- Android 11+: Uses `MANAGE_EXTERNAL_STORAGE`
- Android ≤10: Uses `WRITE_EXTERNAL_STORAGE`

---

## 📋 Parser Logic (Fixed)

### What was wrong before:
Whole messy rows were going into a single cell.

### What's fixed now:
1. **Separator detection** — scores each candidate (tab, pipe, tilde, semicolon, comma) by consistency across lines
2. **Sub-field parsing** — handles `Key|Value` tokens like `CheckIn|01-03-2026` → extracts value
3. **Column normalization** — all rows padded to same column count
4. **Deduplication** — exact duplicate rows removed
5. **Type inference** — email, phone, date, amount, ID, status, name detected per column
6. **AI fallback** — triggers when confidence < 55%, uses GPT-3.5 to parse natural language

### Example:
```
Input:  B001~Rahul Sharma~Delhi~CheckIn|01-03-2026~CheckOut|03-03-2026~Guests|2~4500~Confirmed

Output table:
| ID   | Name         | City  | Check In   | Check Out  | Guests | Amount | Status    |
|------|--------------|-------|------------|------------|--------|--------|-----------|
| B001 | Rahul Sharma | Delhi | 01-03-2026 | 03-03-2026 | 2      | 4500   | Confirmed |
```

---

## 🎯 Features

| Feature | Status |
|---|---|
| .xlsx / .xls import | ✅ |
| .csv / .txt / .json import | ✅ |
| Paste raw text | ✅ Fixed (no infinite loading) |
| AI parsing (OpenAI GPT) | ✅ |
| Excel-like editor (PlutoGrid) | ✅ |
| Add/delete/duplicate rows | ✅ |
| Search & filter | ✅ |
| Sort by column | ✅ |
| Column rename & type mapping | ✅ |
| Export .xlsx / .csv / .json / .txt / .pdf | ✅ |
| Save to Downloads folder | ✅ Fixed |
| File history | ✅ |
| Theme (Light/Dark/System) | ✅ Fixed |
| Custom API key | ✅ New |
| AdMob (banner + interstitial) | ✅ New (test ads) |
| Works offline (local parser) | ✅ |

---

## 💡 Replace Test Ads with Real Ads

In `lib/core/constants/app_constants.dart`:
```dart
static const String admobAppId = 'ca-app-pub-XXXXXXXXXXXXXXXX~XXXXXXXXXX';
static const String bannerAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
static const String interstitialAdUnitId = 'ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX';
```

Also update in `android/app/src/main/AndroidManifest.xml`:
```xml
<meta-data
    android:name="com.google.android.gms.ads.APPLICATION_ID"
    android:value="YOUR_REAL_ADMOB_APP_ID"/>
```

---

## 📁 Project Structure

```
lib/
├── main.dart
├── core/
│   ├── constants/app_constants.dart    ← API keys, AdMob IDs, config
│   ├── theme/app_theme.dart            ← Light + Dark themes
│   └── utils/app_utils.dart            ← Parser utilities, pattern detection
├── domain/entities/parsed_dataset.dart
├── data/datasources/
│   ├── local_parser_service.dart       ← Full rewrite: proper column splitting
│   ├── ai_parser_service.dart          ← OpenAI GPT, custom key support
│   ├── export_service.dart             ← Downloads folder, permission request
│   └── ad_service.dart                 ← AdMob banner + interstitial
└── presentation/
    ├── providers/
    │   ├── app_provider.dart           ← Parse orchestrator, fixed async flow
    │   ├── settings_provider.dart      ← Theme + all settings, notifyListeners fixed
    │   └── history_provider.dart
    └── screens/
        ├── splash_screen.dart
        ├── home_screen.dart
        ├── import_screen.dart
        ├── paste_text_screen.dart
        ├── parsing_progress_screen.dart ← Fixed infinite loading
        ├── spreadsheet_editor_screen.dart ← PlutoGrid 8.0.0 compatible
        ├── column_mapping_screen.dart
        ├── export_screen.dart
        ├── history_screen.dart
        └── settings_screen.dart         ← Theme change works live
```
