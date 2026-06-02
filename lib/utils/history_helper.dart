import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'cache_helper.dart';
import '../services/user_agent_service.dart';

class HistoryItem {
  final String id;
  final String thumbnailUrl;
  final DateTime timestamp;

  HistoryItem({
    required this.id,
    required this.thumbnailUrl,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'thumbnailUrl': thumbnailUrl,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryItem.fromJson(Map<String, dynamic> json) => HistoryItem(
        id: json['id'] as String,
        thumbnailUrl: json['thumbnailUrl'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

class HistoryHelper {
  static Future<File> _getHistoryFile() async {
    final supportDir = await getApplicationSupportDirectory();
    final settingsDir = Directory('${supportDir.path}/settings');
    if (!settingsDir.existsSync()) {
      settingsDir.createSync(recursive: true);
    }
    return File('${settingsDir.path}/browsing_history.json');
  }

  static Future<Directory> getHistoryImagesDir() async {
    final favDir = await CacheHelper.getFavoritesCacheDir();
    final imgDir = Directory('${favDir.path}/history_images');
    if (!imgDir.existsSync()) {
      imgDir.createSync(recursive: true);
    }
    return imgDir;
  }

  /// Add an item to history (max 100 items, moves duplicates to the top)
  static Future<void> addToHistory(String id, String thumbnailUrl) async {
    try {
      final file = await _getHistoryFile();
      List<HistoryItem> items = [];
      
      if (file.existsSync()) {
        final content = await file.readAsString();
        final List<dynamic> jsonList = json.decode(content);
        items = jsonList.map((e) => HistoryItem.fromJson(e)).toList();
      }

      // Remove existing item to avoid duplicates and put new one at the top
      items.removeWhere((item) => item.id == id);
      
      // Add new item at the top (index 0)
      items.insert(
        0,
        HistoryItem(
          id: id,
          thumbnailUrl: thumbnailUrl,
          timestamp: DateTime.now(),
        ),
      );

      // Cap at 100 items
      if (items.length > 100) {
        items = items.sublist(0, 100);
      }

      final jsonString = json.encode(items.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);

      // Asynchronously cache history preview images into the favorites cache scope
      Future.microtask(() async {
        try {
          final imgDir = await getHistoryImagesDir();
          final localFile = File('${imgDir.path}/$id.jpg');
          if (!localFile.existsSync() && thumbnailUrl.isNotEmpty) {
            final dio = UserAgentService.createDio();
            await dio.download(thumbnailUrl, localFile.path);
          }
        } catch (_) {}
      });
    } catch (_) {}
  }

  /// Get all browsing history items
  static Future<List<HistoryItem>> getHistory() async {
    try {
      final file = await _getHistoryFile();
      if (!file.existsSync()) return [];
      
      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      return jsonList.map((e) => HistoryItem.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  /// Delete a single history item by image ID
  static Future<void> deleteHistoryItem(String id) async {
    try {
      final file = await _getHistoryFile();
      if (!file.existsSync()) return;

      final content = await file.readAsString();
      final List<dynamic> jsonList = json.decode(content);
      List<HistoryItem> items = jsonList.map((e) => HistoryItem.fromJson(e)).toList();

      items.removeWhere((item) => item.id == id);

      final jsonString = json.encode(items.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (_) {}
  }

  /// Save the entire history list directly
  static Future<void> saveHistory(List<HistoryItem> items) async {
    try {
      final file = await _getHistoryFile();
      final jsonString = json.encode(items.map((e) => e.toJson()).toList());
      await file.writeAsString(jsonString);
    } catch (_) {}
  }

  /// Clear all browsing history
  static Future<void> clearHistory() async {
    try {
      final file = await _getHistoryFile();
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }
}
