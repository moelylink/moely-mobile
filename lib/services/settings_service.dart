import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  ThemeMode _themeMode = ThemeMode.system;
  Color _themeColor = const Color(0xFF3B82F6); // Vibrant Blue default
  bool _enableTranslation = true;
  String _translationLanguage = 'zh-CN';
  String _translationEngine = 'microsoft'; // 'microsoft' or 'google'
  bool _showJumpConfirmation = true;

  ThemeMode get themeMode => _themeMode;
  Color get themeColor => _themeColor;
  bool get enableTranslation => _enableTranslation;
  String get translationLanguage => _translationLanguage;
  String get translationEngine => _translationEngine;
  bool get showJumpConfirmation => _showJumpConfirmation;

  /// Initialize and load settings from disk
  Future<void> init() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_settings.json');
      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync());
        if (data['themeMode'] != null) {
          _themeMode = ThemeMode.values[data['themeMode']];
        }
        if (data['themeColor'] != null) {
          _themeColor = Color(data['themeColor']);
        }
        if (data['enableTranslation'] != null) {
          _enableTranslation = data['enableTranslation'];
        }
        if (data['translationLanguage'] != null) {
          _translationLanguage = data['translationLanguage'];
        }
        if (data['translationEngine'] != null) {
          _translationEngine = data['translationEngine'];
        }
        if (data['showJumpConfirmation'] != null) {
          _showJumpConfirmation = data['showJumpConfirmation'];
        }
      }
    } catch (_) {}
  }

  /// Save current settings to disk
  Future<void> save() async {
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/app_settings.json');
      final data = {
        'themeMode': _themeMode.index,
        'themeColor': _themeColor.value,
        'enableTranslation': _enableTranslation,
        'translationLanguage': _translationLanguage,
        'translationEngine': _translationEngine,
        'showJumpConfirmation': _showJumpConfirmation,
      };
      file.writeAsStringSync(jsonEncode(data));
    } catch (_) {}
  }

  void setThemeMode(ThemeMode mode) {
    _themeMode = mode;
    save();
    notifyListeners();
  }

  void setThemeColor(Color color) {
    _themeColor = color;
    save();
    notifyListeners();
  }

  void setEnableTranslation(bool enable) {
    _enableTranslation = enable;
    save();
    notifyListeners();
  }

  void setTranslationLanguage(String lang) {
    _translationLanguage = lang;
    save();
    notifyListeners();
  }

  void setTranslationEngine(String engine) {
    _translationEngine = engine;
    save();
    notifyListeners();
  }

  void setShowJumpConfirmation(bool show) {
    _showJumpConfirmation = show;
    save();
    notifyListeners();
  }
}
