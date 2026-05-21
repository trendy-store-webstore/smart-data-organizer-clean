import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  bool _aiEnabled = true;
  String _defaultExportFormat = 'xlsx';
  String _dateFormat = 'dd-MM-yyyy';
  String _currencySymbol = '₹';
  String _customApiKey = '';

  ThemeMode get themeMode => _themeMode;
  bool get aiEnabled => _aiEnabled;
  String get defaultExportFormat => _defaultExportFormat;
  String get dateFormat => _dateFormat;
  String get currencySymbol => _currencySymbol;
  String get customApiKey => _customApiKey;
  String get activeApiKey =>
      _customApiKey.isNotEmpty ? _customApiKey : AppConstants.defaultOpenAiKey;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(AppConstants.keyThemeMode) ?? 0;
    // clamp to valid index
    _themeMode = ThemeMode.values[idx.clamp(0, 2)];
    _aiEnabled = prefs.getBool(AppConstants.keyAiEnabled) ?? true;
    _defaultExportFormat = prefs.getString(AppConstants.keyDefaultExportFormat) ?? 'xlsx';
    _dateFormat = prefs.getString(AppConstants.keyDateFormat) ?? 'dd-MM-yyyy';
    _currencySymbol = prefs.getString(AppConstants.keyCurrencySymbol) ?? '₹';
    _customApiKey = prefs.getString(AppConstants.keyCustomApiKey) ?? '';
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.keyThemeMode, mode.index);
    notifyListeners();
  }

  Future<void> setAiEnabled(bool v) async {
    _aiEnabled = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyAiEnabled, v);
    notifyListeners();
  }

  Future<void> setDefaultExportFormat(String v) async {
    _defaultExportFormat = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyDefaultExportFormat, v);
    notifyListeners();
  }

  Future<void> setDateFormat(String v) async {
    _dateFormat = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyDateFormat, v);
    notifyListeners();
  }

  Future<void> setCurrencySymbol(String v) async {
    _currencySymbol = v;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyCurrencySymbol, v);
    notifyListeners();
  }

  Future<void> setCustomApiKey(String v) async {
    _customApiKey = v.trim();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyCustomApiKey, _customApiKey);
    notifyListeners();
  }
}
