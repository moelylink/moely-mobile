import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'settings_service.dart';

class LogService {
  static final LogService instance = LogService._();
  LogService._();

  File? _logFile;

  Future<File> get _file async {
    if (_logFile != null) return _logFile!;
    final directory = await getApplicationDocumentsDirectory();
    _logFile = File('${directory.path}/logs.txt');
    return _logFile!;
  }

  /// Write a message to logs.txt if debug mode is active
  static void log(String message) async {
    if (!AppSettings.instance.debugMode) return;

    try {
      final file = await instance._file;
      final timestamp = DateTime.now().toIso8601String();
      await file.writeAsString(
        '[$timestamp] $message\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (e) {
      debugPrint('Failed to write log: $e');
    }
  }

  /// Read the logs.txt content
  Future<String> readLog() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        return await file.readAsString();
      }
    } catch (e) {
      debugPrint('Failed to read log: $e');
    }
    return '暂无日志记录';
  }

  /// Get formatted size of logs.txt
  Future<String> getLogSize() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        final bytes = await file.length();
        if (bytes < 1024) return '$bytes B';
        if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(2)} KB';
        return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
      }
    } catch (_) {}
    return '0 B';
  }

  /// Clear the logs.txt content
  Future<void> clearLog() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  /// Share the logs.txt file using share_plus
  Future<void> shareLog() async {
    try {
      final file = await _file;
      if (await file.exists()) {
        await Share.shareXFiles([XFile(file.path)], text: '萌哩 App 调试日志');
      } else {
        debugPrint('Log file does not exist');
      }
    } catch (e) {
      debugPrint('Failed to share log: $e');
    }
  }
}
