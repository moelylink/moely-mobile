import 'dart:io';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../services/settings_service.dart';

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

  // Clear specific directory safely and thoroughly
  static Future<void> clearDir(Directory dir) async {
    try {
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
        return;
      }
      
      // Strategy 1: Attempt whole-directory recursive wipe for maximum speed and cleanliness
      try {
        dir.deleteSync(recursive: true);
        dir.createSync(recursive: true);
        return;
      } catch (_) {}

      // Strategy 2: Fallback entity-by-entity granular deletion
      try {
        final List<FileSystemEntity> entities = dir.listSync(recursive: true, followLinks: false);
        for (final FileSystemEntity entity in entities) {
          try {
            if (entity is File) {
              entity.deleteSync();
            }
          } catch (_) {}
        }
        for (final FileSystemEntity entity in entities.reversed) {
          try {
            if (entity is Directory && entity.path != dir.path) {
              entity.deleteSync(recursive: false);
            }
          } catch (_) {}
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Failed to clear directory ${dir.path}: $e');
    }
  }

  /// Clean all image caches across all known cache directories and memory
  static Future<void> clearAllImageCaches() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final supportDir = await getApplicationSupportDirectory();
      final docDir = await getApplicationDocumentsDirectory();

      final imgDirs = [
        Directory('${tempDir.path}/libCachedImageData'),
        Directory('${tempDir.path}/cache'),
        Directory('${tempDir.path}/flutter_cache_manager'),
        Directory('${tempDir.path}/image_picker'),
        Directory('${supportDir.path}/libCachedImageData'),
        Directory('${docDir.path}/libCachedImageData'),
      ];

      for (final dir in imgDirs) {
        await clearDir(dir);
      }

      try {
        await DefaultCacheManager().emptyCache();
      } catch (_) {}

      try {
        PaintingBinding.instance.imageCache.clear();
        PaintingBinding.instance.imageCache.clearLiveImages();
      } catch (_) {}
    } catch (_) {}
  }

  /// Clean all WebView caches across all potential directories
  static Future<void> clearAllWebViewCaches() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final parentDir = tempDir.parent;
      final supportDir = await getApplicationSupportDirectory();
      final docDir = await getApplicationDocumentsDirectory();

      final webDirs = [
        Directory('${parentDir.path}/app_webview'),
        Directory('${tempDir.path}/WebView'),
        Directory('${tempDir.path}/app_webview'),
        Directory('${supportDir.path}/app_webview'),
        Directory('${docDir.path}/app_webview'),
        Directory('${supportDir.path}/WebView'),
        Directory('${docDir.path}/WebView'),
      ];

      for (final dir in webDirs) {
        await clearDir(dir);
      }
    } catch (_) {}
  }

  /// Clean all favorites cache across all directories
  static Future<void> clearAllFavoritesCache() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();
      final docDir = await getApplicationDocumentsDirectory();

      final dirs = [
        Directory('${supportDir.path}/favorites_cache'),
        Directory('${tempDir.path}/favorites_cache'),
        Directory('${docDir.path}/favorites_cache'),
      ];

      for (final dir in dirs) {
        await clearDir(dir);
      }
    } catch (_) {}
  }

  // Detail Cache Operations (Long-term persistent offline cache)
  static Future<void> saveDetailsToCache(String id, Map<String, dynamic> jsonMap) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;
    try {
      final cacheDir = await getDetailsCacheDir();
      final cacheFile = File('${cacheDir.path}/$cleanId.json');
      await cacheFile.writeAsString(json.encode(jsonMap));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadDetailsFromCache(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return null;
    try {
      final cacheDir = await getDetailsCacheDir();
      final cacheFile = File('${cacheDir.path}/$cleanId.json');
      if (cacheFile.existsSync()) {
        final content = await cacheFile.readAsString();
        final dynamic decoded = json.decode(content);
        if (decoded is Map<String, dynamic>) {
          if (decoded.containsKey('data') && decoded['data'] is Map<String, dynamic>) {
            return decoded['data'] as Map<String, dynamic>;
          }
          return decoded;
        }
      }
    } catch (_) {}
    return null;
  }

  static Future<void> deleteDetailsFromCache(String id) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;
    try {
      final supportDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();
      final docDir = await getApplicationDocumentsDirectory();

      final filesToDelete = [
        File('${supportDir.path}/details_cache/$cleanId.json'),
        File('${tempDir.path}/details_cache/$cleanId.json'),
        File('${docDir.path}/details_cache/$cleanId.json'),
      ];

      for (final file in filesToDelete) {
        if (file.existsSync()) {
          try {
            file.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Clean all detail caches completely across all directories
  static Future<void> clearAllDetailsCache() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();
      final docDir = await getApplicationDocumentsDirectory();

      final dirsToClear = [
        Directory('${supportDir.path}/details_cache'),
        Directory('${tempDir.path}/details_cache'),
        Directory('${docDir.path}/details_cache'),
      ];

      for (final dir in dirsToClear) {
        await clearDir(dir);
      }

      final filesToClean = [
        File('${supportDir.path}/detail_history.json'),
        File('${tempDir.path}/detail_history.json'),
        File('${docDir.path}/detail_history.json'),
      ];
      for (final f in filesToClean) {
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  /// Clean all index caches completely across all directories
  static Future<void> clearAllIndexCache() async {
    try {
      final supportDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();
      final docDir = await getApplicationDocumentsDirectory();

      final dirsToClear = [
        Directory('${supportDir.path}/index_cache'),
        Directory('${tempDir.path}/index_cache'),
        Directory('${docDir.path}/index_cache'),
      ];

      for (final dir in dirsToClear) {
        await clearDir(dir);
      }

      final filesToClean = [
        File('${supportDir.path}/global_index_cache.json'),
        File('${tempDir.path}/global_index_cache.json'),
        File('${docDir.path}/global_index_cache.json'),
      ];
      for (final f in filesToClean) {
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  static const int currentIndexCacheVersion = 2;
  static const int currentIndexCacheTtlMs = 3 * 24 * 60 * 60 * 1000; // 3 days TTL

  // Index Cache Operations (home, category, tags)
  static Future<void> saveIndexToCache(String cacheKey, Map<String, dynamic> jsonMap) async {
    final cleanKey = cacheKey.trim();
    if (cleanKey.isEmpty) return;
    try {
      final cacheDir = await getIndexCacheDir();
      final cacheFile = File('${cacheDir.path}/$cleanKey.json');
      final payload = {
        'version': currentIndexCacheVersion,
        'cached_at': DateTime.now().millisecondsSinceEpoch,
        'data': jsonMap,
      };
      await cacheFile.writeAsString(json.encode(payload));
    } catch (_) {}
  }

  static Future<Map<String, dynamic>?> loadIndexFromCache(String cacheKey) async {
    final cleanKey = cacheKey.trim();
    if (cleanKey.isEmpty) return null;
    try {
      final cacheDir = await getIndexCacheDir();
      final cacheFile = File('${cacheDir.path}/$cleanKey.json');
      if (cacheFile.existsSync()) {
        final content = await cacheFile.readAsString();
        final dynamic decoded = json.decode(content);
        if (decoded is Map<String, dynamic>) {
          final int version = decoded['version'] is int ? decoded['version'] as int : 0;
          final int cachedAt = decoded['cached_at'] is int ? decoded['cached_at'] as int : 0;
          final dynamic data = decoded['data'];

          final isExpired = cachedAt > 0 && (DateTime.now().millisecondsSinceEpoch - cachedAt > currentIndexCacheTtlMs);

          if (version >= currentIndexCacheVersion && !isExpired && data is Map<String, dynamic>) {
            return data;
          } else {
            // Delete corrupt, outdated schema, or expired cache
            try {
              cacheFile.deleteSync();
            } catch (_) {}
          }
        }
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

  static bool _isAutoCleaning = false;

  /// 执行自动缓存清理逻辑 (合并容量限制 LRU 清理与时间维度过期清理)
  static Future<void> performAutoCacheCleanup() async {
    if (_isAutoCleaning) return;
    _isAutoCleaning = true;

    try {
      final docDir = await getApplicationDocumentsDirectory();
      final supportDir = await getApplicationSupportDirectory();
      final tempDir = await getTemporaryDirectory();

      final imgDir = await getImagesCacheDir();
      final detDirs = [
        Directory('${supportDir.path}/details_cache'),
        Directory('${tempDir.path}/details_cache'),
        Directory('${docDir.path}/details_cache'),
      ];
      final idxDirs = [
        Directory('${supportDir.path}/index_cache'),
        Directory('${tempDir.path}/index_cache'),
        Directory('${docDir.path}/index_cache'),
      ];

      // 1. 清理安全的其他杂物/编译缓存 (code_cache 与无主 temp)
      try {
        final codeCacheDir = Directory('${tempDir.parent.path}/code_cache');
        if (codeCacheDir.existsSync()) {
          final files = codeCacheDir.listSync(recursive: true);
          for (final f in files) {
            if (f is File) {
              try { f.deleteSync(); } catch (_) {}
            }
          }
        }
      } catch (_) {}

      // 2. 按时间维度清理 (自动清理过期缓存: 图片文件与图片信息)
      final clearDays = AppSettings.instance.getEffectiveClearDays();
      if (clearDays != null && clearDays > 0) {
        final now = DateTime.now();
        final maxAgeDuration = Duration(days: clearDays);

        void cleanExpiredFilesInDirs(List<Directory> dirs) {
          for (final dir in dirs) {
            if (!dir.existsSync()) continue;
            try {
              final List<FileSystemEntity> entities = dir.listSync(recursive: true);
              for (final entity in entities) {
                if (entity is File) {
                  try {
                    final lastModified = entity.lastModifiedSync();
                    if (now.difference(lastModified) > maxAgeDuration) {
                      entity.deleteSync();
                    }
                  } catch (_) {}
                }
              }
            } catch (_) {}
          }
        }

        cleanExpiredFilesInDirs([imgDir, ...detDirs, ...idxDirs]);
      }

      // 3. 按容量维度清理 (缓存大小限制: LRU 最早未访问淘汰)
      final maxSizeBytes = await AppSettings.instance.getEffectiveMaxCacheSizeBytes();
      if (maxSizeBytes > 0) {
        // 统计图片和信息缓存文件的体积与集合
        final List<File> targetFiles = [];
        int currentSize = 0;

        void collectFiles(Directory dir) {
          if (!dir.existsSync()) return;
          try {
            final List<FileSystemEntity> entities = dir.listSync(recursive: true);
            for (final entity in entities) {
              if (entity is File) {
                try {
                  currentSize += entity.lengthSync();
                  targetFiles.add(entity);
                } catch (_) {}
              }
            }
          } catch (_) {}
        }

        collectFiles(imgDir);
        for (final d in detDirs) { collectFiles(d); }
        for (final d in idxDirs) { collectFiles(d); }

        if (currentSize > maxSizeBytes) {
          // 清理目标设置为 85% 缓冲带
          final int targetSize = (maxSizeBytes * 0.85).toInt();
          int bytesToRemove = currentSize - targetSize;

          // 按修改时间由旧到新排序 (LRU)
          targetFiles.sort((a, b) {
            DateTime tA;
            DateTime tB;
            try { tA = a.lastModifiedSync(); } catch (_) { tA = DateTime.fromMillisecondsSinceEpoch(0); }
            try { tB = b.lastModifiedSync(); } catch (_) { tB = DateTime.fromMillisecondsSinceEpoch(0); }
            return tA.compareTo(tB);
          });

          for (final file in targetFiles) {
            if (bytesToRemove <= 0) break;
            try {
              final len = file.lengthSync();
              file.deleteSync();
              bytesToRemove -= len;
            } catch (_) {}
          }
        }
      }
    } catch (e) {
      debugPrint('Auto cache cleanup error: $e');
    } finally {
      _isAutoCleaning = false;
    }
  }
}
