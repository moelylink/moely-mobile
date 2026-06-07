import 'dart:io';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/user_agent_service.dart';
import '../services/settings_service.dart';
import '../services/wallpaper_service.dart';
import 'notification_helper.dart';

class DownloadTask {
  final String url;
  final String filename;
  double progress; // 0.0 to 1.0
  String status; // 'running', 'paused', 'completed', 'failed'
  CancelToken? cancelToken;
  VoidCallback? onStateChanged;

  DownloadTask({
    required this.url,
    required this.filename,
    this.progress = 0.0,
    this.status = 'running',
    this.cancelToken,
    this.onStateChanged,
  });
}

class DownloadHelper {
  static final Dio _dio = UserAgentService.createDio();
  static final List<DownloadTask> activeTasks = [];

  static Future<File> _getRegistryFile() async {
    final supportDir = await getApplicationSupportDirectory();
    final dir = Directory('${supportDir.path}/downloads_cache');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }
    return File('${dir.path}/downloads_registry.json');
  }

  static Future<List<Map<String, dynamic>>> getRegisteredDownloads() async {
    try {
      final file = await _getRegistryFile();
      if (file.existsSync()) {
        final content = await file.readAsString();
        final List<dynamic> list = json.decode(content);
        final List<Map<String, dynamic>> result = [];
        
        for (final item in list) {
          if (item is Map) {
            result.add(Map<String, dynamic>.from(item));
          } else if (item is String) {
            // Backward compatibility migration:
            // Convert legacy path string into rich metadata record.
            final path = item;
            final f = File(path);
            final exists = f.existsSync();
            result.add({
              'path': path,
              'filename': p.basename(path),
              'size': exists ? f.lengthSync() : 0,
              'downloadTime': exists 
                  ? f.lastModifiedSync().toIso8601String() 
                  : DateTime.now().toIso8601String(),
            });
          }
        }
        return result;
      }
    } catch (e) {
      debugPrint('Failed to read downloads registry: $e');
    }
    return [];
  }

  static Future<void> registerDownload(String path) async {
    try {
      final list = await getRegisteredDownloads();
      final exists = list.any((item) => item['path'] == path);
      if (!exists) {
        final f = File(path);
        final fExists = f.existsSync();
        final size = fExists ? f.lengthSync() : 0;
        
        list.add({
          'path': path,
          'filename': p.basename(path),
          'size': size,
          'downloadTime': DateTime.now().toIso8601String(),
        });
        
        final file = await _getRegistryFile();
        await file.writeAsString(json.encode(list));
      }
    } catch (e) {
      debugPrint('Failed to register download: $e');
    }
  }

  static Future<void> unregisterDownload(String path) async {
    try {
      final list = await getRegisteredDownloads();
      final lengthBefore = list.length;
      list.removeWhere((item) => item['path'] == path);
      if (list.length != lengthBefore) {
        final file = await _getRegistryFile();
        await file.writeAsString(json.encode(list));
      }
    } catch (e) {
      debugPrint('Failed to unregister download: $e');
    }
  }

  /// Returns the current active download directory
  static Future<Directory> getDownloadDirectory() async {
    final customPath = AppSettings.instance.downloadPath;
    if (customPath.isNotEmpty) {
      final dir = Directory(customPath);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      return dir;
    }

    if (Platform.isAndroid) {
      final publicDownloadDir = Directory('/storage/emulated/0/Download/Moely');
      if (!await publicDownloadDir.exists()) {
        await publicDownloadDir.create(recursive: true);
      }
      return publicDownloadDir;
    } else {
      final docDir = await getApplicationDocumentsDirectory();
      final moelyDir = Directory('${docDir.path}/MoelyDownloads');
      if (!await moelyDir.exists()) {
        await moelyDir.create(recursive: true);
      }
      return moelyDir;
    }
  }

  /// Pause an active download task
  static void pauseTask(DownloadTask task) {
    task.status = 'paused';
    task.cancelToken?.cancel('User paused download');
    task.onStateChanged?.call();
    NotificationHelper.cancelNotification(task.filename);
  }

  /// Resume a paused download task
  static void resumeTask(DownloadTask task, {required VoidCallback onDone}) {
    task.status = 'running';
    task.cancelToken = CancelToken();
    task.onStateChanged?.call();

    downloadImage(
      task.url,
      task.filename,
      cancelToken: task.cancelToken,
      onProgress: (received, total) {
        // Progress updates are handled automatically in downloadImage
      },
    ).then((_) {
      onDone();
    }).catchError((err) {
      debugPrint('Resume task failed: $err');
      onDone();
    });
  }

  /// Downloads an image to public/private storage, adaptively supporting Android & iOS
  static Future<String> downloadImage(
    String url, 
    String filename, {
    required void Function(int received, int total) onProgress,
    CancelToken? cancelToken,
  }) async {
    // Look up or register the task for real-time tracking in the download manager
    DownloadTask? task = activeTasks.firstWhere((t) => t.filename == filename, orElse: () {
      final t = DownloadTask(
        url: url,
        filename: filename,
        status: 'running',
        cancelToken: cancelToken ?? CancelToken(),
      );
      activeTasks.add(t);
      return t;
    });

    task.status = 'running';
    if (cancelToken != null) {
      task.cancelToken = cancelToken;
    } else if (task.cancelToken == null) {
      task.cancelToken = CancelToken();
    }

    // Trigger start notification
    NotificationHelper.showDownloadNotification(
      filename: filename,
      progress: 0.0,
    );

    try {
      final targetDir = await getDownloadDirectory();
      final savePath = p.join(targetDir.path, filename);
      
      final response = await _dio.download(
        url,
        savePath,
        cancelToken: task.cancelToken,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            task.progress = received / total;
            task.onStateChanged?.call();
            NotificationHelper.showDownloadNotification(
              filename: filename,
              progress: task.progress,
            );
          }
          onProgress(received, total);
        },
      );

      if (response.statusCode == 200) {
        task.status = 'completed';
        task.progress = 1.0;
        task.onStateChanged?.call();
        activeTasks.remove(task);

        // Show completed notification
        NotificationHelper.showDownloadNotification(
          filename: filename,
          progress: 1.0,
          filePath: savePath,
          isCompleted: true,
        );

        // Notify Android system MediaScanner to scan and index the new image file
        if (Platform.isAndroid) {
          try {
            WallpaperService.scanFile(savePath);
          } catch (_) {}
        }

        // Register the download in the local database
        await registerDownload(savePath);

        return savePath;
      } else {
        task.status = 'failed';
        task.onStateChanged?.call();
        NotificationHelper.showDownloadNotification(
          filename: filename,
          progress: 0.0,
          isFailed: true,
        );
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // If paused/cancelled by user, do not execute the fallback
      if (e is DioException && CancelToken.isCancel(e)) {
        task.status = 'paused';
        task.onStateChanged?.call();
        NotificationHelper.cancelNotification(filename);
        throw Exception('下载已暂停');
      }

      // Try fallback to absolute safe application directory if public path errors
      try {
        final safeDir = await getApplicationSupportDirectory();
        final moelyFallbackDir = Directory('${safeDir.path}/MoelyDownloads');
        if (!await moelyFallbackDir.exists()) {
          await moelyFallbackDir.create(recursive: true);
        }
        final safePath = p.join(moelyFallbackDir.path, filename);
        
        final response = await _dio.download(
          url,
          safePath,
          cancelToken: task.cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              task.progress = received / total;
              task.onStateChanged?.call();
              NotificationHelper.showDownloadNotification(
                filename: filename,
                progress: task.progress,
              );
            }
            onProgress(received, total);
          },
        );
        
        if (response.statusCode == 200) {
          task.status = 'completed';
          task.progress = 1.0;
          task.onStateChanged?.call();
          activeTasks.remove(task);

          // Show completed notification
          NotificationHelper.showDownloadNotification(
            filename: filename,
            progress: 1.0,
            filePath: safePath,
            isCompleted: true,
          );

          // Notify Android system MediaScanner to scan and index the fallback image file
          if (Platform.isAndroid) {
            try {
              WallpaperService.scanFile(safePath);
            } catch (_) {}
          }

          // Register the download in the local database
          await registerDownload(safePath);

          return safePath;
        } else {
          task.status = 'failed';
          task.onStateChanged?.call();
          NotificationHelper.showDownloadNotification(
            filename: filename,
            progress: 0.0,
            isFailed: true,
          );
          throw Exception('Secure download fallback also failed: ${response.statusCode}');
        }
      } catch (fallbackError) {
        if (fallbackError is DioException && CancelToken.isCancel(fallbackError)) {
          task.status = 'paused';
          task.onStateChanged?.call();
          NotificationHelper.cancelNotification(filename);
          throw Exception('下载已暂停');
        }
        task.status = 'failed';
        task.onStateChanged?.call();
        NotificationHelper.showDownloadNotification(
          filename: filename,
          progress: 0.0,
          isFailed: true,
        );
        rethrow;
      }
    }
  }
}
