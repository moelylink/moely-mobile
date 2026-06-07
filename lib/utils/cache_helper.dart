import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class CacheHelper {
  // Directory retrievers
  static Future<Directory> getImagesCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final dir = Directory('${tempDir.path}/libCachedImageData');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> getDetailsCacheDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/details_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> getIndexCacheDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/index_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> getFavoritesCacheDir() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/favorites_cache');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir;
  }

  static Future<Directory> getWebViewCacheDir() async {
    final tempDir = await getTemporaryDirectory();
    final parentDir = tempDir.parent;
    final webviewDir1 = Directory('${parentDir.path}/app_webview');
    if (webviewDir1.existsSync()) return webviewDir1;
    
    final webviewDir2 = Directory('${tempDir.path}/WebView');
    if (!webviewDir2.existsSync()) webviewDir2.createSync(recursive: true);
    return webviewDir2;
  }

  // Get size of a directory
  static Future<int> getDirSize(Directory dir) async {
    int totalSize = 0;
    try {
      if (dir.existsSync()) {
        final List<FileSystemEntity> files = dir.listSync(recursive: true);
        for (final FileSystemEntity file in files) {
          if (file is File) {
            totalSize += file.lengthSync();
          }
        }
      }
    } catch (_) {}
    return totalSize;
  }

  // Format file size
  static String formatSize(int bytes) {
    if (bytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB"];
    var i = 0;
    double size = bytes.toDouble();
    while (size >= 1024 && i < suffixes.length - 1) {
      size /= 1024;
      i++;
    }
    return "${size.toStringAsFixed(2)} ${suffixes[i]}";
  }

  // Clear specific directory
  static Future<void> clearDir(Directory dir) async {
    try {
      if (dir.existsSync()) {
        final List<FileSystemEntity> files = dir.listSync(recursive: true);
        for (final FileSystemEntity file in files) {
          if (file is File) {
            await file.delete();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to clear directory ${dir.path}: $e');
    }
  }

  // Detail Cache Operations
  static Future<void> saveDetailsToCache(String id, Map<String, dynamic> jsonMap) async {
    try {
      final cacheDir = await getDetailsCacheDir();
      final cacheFile = File('${cacheDir.path}/$id.json');
      await cacheFile.writeAsString(json.encode(jsonMap));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadDetailsFromCache(String id) async {
    try {
      final cacheDir = await getDetailsCacheDir();
      final cacheFile = File('${cacheDir.path}/$id.json');
      if (cacheFile.existsSync()) {
        final content = await cacheFile.readAsString();
        return json.decode(content);
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteDetailsFromCache(String id) async {
    try {
      final cacheDir = await getDetailsCacheDir();
      final cacheFile = File('${cacheDir.path}/$id.json');
      if (cacheFile.existsSync()) {
        await cacheFile.delete();
      }
    } catch (_) {}
  }

  // Index Cache Operations (home, category, tags)
  static Future<void> saveIndexToCache(String cacheKey, Map<String, dynamic> jsonMap) async {
    try {
      final cacheDir = await getIndexCacheDir();
      final cacheFile = File('${cacheDir.path}/$cacheKey.json');
      await cacheFile.writeAsString(json.encode(jsonMap));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadIndexFromCache(String cacheKey) async {
    try {
      final cacheDir = await getIndexCacheDir();
      final cacheFile = File('${cacheDir.path}/$cacheKey.json');
      if (cacheFile.existsSync()) {
        final content = await cacheFile.readAsString();
        return json.decode(content);
      }
    } catch (_) {}
    return null;
  }

  /// Query actual system storage information (totalSpace and freeSpace)
  static Future<Map<String, int>> getSystemStorageInfo() async {
    // Standard fallbacks (e.g., 256GB total, 150GB free)
    int total = 256 * 1024 * 1024 * 1024;
    int free = 150 * 1024 * 1024 * 1024;

    if (Platform.isAndroid || Platform.isIOS) {
      try {
        const channel = MethodChannel('link.moely.mobile/app_info');
        final Map? result = await channel.invokeMethod('getStorageSpace');
        if (result != null) {
          total = (result['totalSpace'] as num).toInt();
          free = (result['freeSpace'] as num).toInt();
        }
      } catch (_) {}
    } else if (Platform.isWindows) {
      try {
        final result = await Process.run('powershell', [
          '-Command',
          "Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object DeviceID -eq 'C:' | Select-Object Size, FreeSpace | Format-List"
        ]);
        if (result.exitCode == 0) {
          final output = result.stdout.toString();
          final sizeMatch = RegExp(r'Size\s*:\s*(\d+)').firstMatch(output);
          final freeMatch = RegExp(r'FreeSpace\s*:\s*(\d+)').firstMatch(output);
          if (sizeMatch != null && freeMatch != null) {
            total = int.parse(sizeMatch.group(1)!);
            free = int.parse(freeMatch.group(1)!);
          }
        }
      } catch (_) {}
    }
    return {
      'totalSpace': total,
      'freeSpace': free,
    };
  }
}
