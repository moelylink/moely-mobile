import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../utils/cache_helper.dart';

class AppSettings extends ChangeNotifier {
  static final AppSettings instance = AppSettings._();
  AppSettings._();

  ThemeMode _themeMode = ThemeMode.system;
  Color _themeColor = const Color(0xFF8B5CF6); // Royal Purple default
  Color _customColor = const Color(0xFF3B82F6); // Vibrant Blue default custom
  bool _enableTranslation = true;
  String _translationLanguage = 'zh-CN';
  String _translationEngine = 'microsoft'; // 'microsoft' or 'google'
  bool _showJumpConfirmation = true;
  bool _browseInApp = true;
  String _downloadPath = '';
  bool _enableOverscrollRandom = true;
  bool _enableInfiniteScroll = false;
  bool _showGridImageInfo = true;
  bool _autoCheckUpdate = true;
  bool _debugMode = false;
  int _maxCacheSizeIndex = 4; // 0: 自动, 1: 2GB, 2: 5GB, 3: 10GB, 4: 无限制
  int _autoClearDaysIndex = 4; // 0: 7天, 1: 14天, 2: 30天, 3: 90天, 4: 不清理

  ThemeMode get themeMode => _themeMode;
  Color get themeColor => _themeColor;
  Color get customColor => _customColor;
  bool get enableTranslation => _enableTranslation;
  String get translationLanguage => _translationLanguage;
  String get translationEngine => _translationEngine;
  bool get showJumpConfirmation => _showJumpConfirmation;
  bool get browseInApp => _browseInApp;
  String get downloadPath => _downloadPath;
  bool get enableOverscrollRandom => _enableOverscrollRandom;
  bool get enableInfiniteScroll => _enableInfiniteScroll;
  bool get showGridImageInfo => _showGridImageInfo;
  bool get autoCheckUpdate => _autoCheckUpdate;
  bool get debugMode => _debugMode;
  int get maxCacheSizeIndex => _maxCacheSizeIndex;
  int get autoClearDaysIndex => _autoClearDaysIndex;

  /// Initialize and load settings from disk
  Future<void> init() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final newDir = Directory('${supportDir.path}/settings');
      if (!newDir.existsSync()) {
        newDir.createSync(recursive: true);
      }
      final file = File('${newDir.path}/app_settings.json');

      // Seamless migration from old path (docDir/app_settings.json)
      final docDir = await getApplicationDocumentsDirectory();
      final oldFile = File('${docDir.path}/app_settings.json');
      if (oldFile.existsSync() && !file.existsSync()) {
        try {
          oldFile.copySync(file.path);
          oldFile.deleteSync();
        } catch (_) {}
      }

      if (file.existsSync()) {
        final data = jsonDecode(file.readAsStringSync());
        if (data['themeMode'] != null) {
          _themeMode = ThemeMode.values[data['themeMode']];
        }
        if (data['themeColor'] != null) {
          _themeColor = Color(data['themeColor']);
        }
        if (data['customColor'] != null) {
          _customColor = Color(data['customColor']);
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
        if (data['browseInApp'] != null) {
          _browseInApp = data['browseInApp'];
        }
        if (data['downloadPath'] != null) {
          _downloadPath = data['downloadPath'];
        }
        if (data['enableOverscrollRandom'] != null) {
          _enableOverscrollRandom = data['enableOverscrollRandom'];
        }
        if (data['enableInfiniteScroll'] != null) {
          _enableInfiniteScroll = data['enableInfiniteScroll'];
        }
        if (data['showGridImageInfo'] != null) {
          _showGridImageInfo = data['showGridImageInfo'];
        }
        if (data['autoCheckUpdate'] != null) {
          _autoCheckUpdate = data['autoCheckUpdate'];
        }
        if (data['debugMode'] != null) {
          _debugMode = data['debugMode'];
        }
        if (data['maxCacheSizeIndex'] != null) {
          _maxCacheSizeIndex = data['maxCacheSizeIndex'];
        }
        if (data['autoClearDaysIndex'] != null) {
          _autoClearDaysIndex = data['autoClearDaysIndex'];
        }
      }
    } catch (_) {}
  }

  /// Save current settings to disk
  Future<void> save() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final newDir = Directory('${supportDir.path}/settings');
      if (!newDir.existsSync()) {
        newDir.createSync(recursive: true);
      }
      final file = File('${newDir.path}/app_settings.json');
      final data = {
        'themeMode': _themeMode.index,
        'themeColor': _themeColor.value,
        'customColor': _customColor.value,
        'enableTranslation': _enableTranslation,
        'translationLanguage': _translationLanguage,
        'translationEngine': _translationEngine,
        'showJumpConfirmation': _showJumpConfirmation,
        'browseInApp': _browseInApp,
        'downloadPath': _downloadPath,
        'enableOverscrollRandom': _enableOverscrollRandom,
        'enableInfiniteScroll': _enableInfiniteScroll,
        'showGridImageInfo': _showGridImageInfo,
        'autoCheckUpdate': _autoCheckUpdate,
        'debugMode': _debugMode,
        'maxCacheSizeIndex': _maxCacheSizeIndex,
        'autoClearDaysIndex': _autoClearDaysIndex,
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

  void setCustomColor(Color color) {
    _customColor = color;
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

  void setBrowseInApp(bool browse) {
    _browseInApp = browse;
    save();
    notifyListeners();
  }

  void setDownloadPath(String path) {
    _downloadPath = path;
    save();
    notifyListeners();
  }

  void setEnableOverscrollRandom(bool enable) {
    _enableOverscrollRandom = enable;
    save();
    notifyListeners();
  }

  void setEnableInfiniteScroll(bool enable) {
    _enableInfiniteScroll = enable;
    save();
    notifyListeners();
  }

  void setShowGridImageInfo(bool show) {
    _showGridImageInfo = show;
    save();
    notifyListeners();
  }

  void setAutoCheckUpdate(bool check) {
    _autoCheckUpdate = check;
    save();
    notifyListeners();
  }

  void setDebugMode(bool debug) {
    _debugMode = debug;
    save();
    notifyListeners();
  }

  void setMaxCacheSizeIndex(int index) {
    _maxCacheSizeIndex = index;
    save();
    notifyListeners();
  }

  void setAutoClearDaysIndex(int index) {
    _autoClearDaysIndex = index;
    save();
    notifyListeners();
  }

  /// 计算当前的实际字节限制 (若为无限制则返回 -1)
  Future<int> getEffectiveMaxCacheSizeBytes() async {
    if (_maxCacheSizeIndex == 4) return -1; // 无限制
    if (_maxCacheSizeIndex == 1) return 2 * 1024 * 1024 * 1024;
    if (_maxCacheSizeIndex == 2) return 5 * 1024 * 1024 * 1024;
    if (_maxCacheSizeIndex == 3) return 10 * 1024 * 1024 * 1024;

    // 0: 自动计算 (剩余空间 5% 向下取整到 1GB 整数，clamp 在 [1, 15] GB)
    final storageInfo = await CacheHelper.getSystemStorageInfo();
    final freeBytes = storageInfo['freeSpace'] ?? (150 * 1024 * 1024 * 1024);
    final freeGB = freeBytes / (1024 * 1024 * 1024);
    int calculatedGB = (freeGB * 0.05).floor();
    int targetGB = calculatedGB.clamp(1, 15);
    return targetGB * 1024 * 1024 * 1024;
  }

  /// 获取设定的天数阈值 (若为不清理则返回 null)
  int? getEffectiveClearDays() {
    if (_autoClearDaysIndex == 0) return 7;
    if (_autoClearDaysIndex == 1) return 14;
    if (_autoClearDaysIndex == 2) return 30;
    if (_autoClearDaysIndex == 3) return 90;
    return null; // 4: 不清理
  }
}
