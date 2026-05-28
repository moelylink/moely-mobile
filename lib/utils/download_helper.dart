import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../services/user_agent_service.dart';
import '../services/settings_service.dart';

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
      final publicDownloadDir = Directory('/storage/emulated/0/Download/moely');
      if (!await publicDownloadDir.exists()) {
        await publicDownloadDir.create(recursive: true);
      }
      return publicDownloadDir;
    } else {
      return await getApplicationDocumentsDirectory();
    }
  }

  /// Pause an active download task
  static void pauseTask(DownloadTask task) {
    task.status = 'paused';
    task.cancelToken?.cancel('User paused download');
    task.onStateChanged?.call();
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
          }
          onProgress(received, total);
        },
      );

      if (response.statusCode == 200) {
        task.status = 'completed';
        task.progress = 1.0;
        task.onStateChanged?.call();
        activeTasks.remove(task);
        return savePath;
      } else {
        task.status = 'failed';
        task.onStateChanged?.call();
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // If paused/cancelled by user, do not execute the fallback
      if (e is DioException && CancelToken.isCancel(e)) {
        task.status = 'paused';
        task.onStateChanged?.call();
        throw Exception('下载已暂停');
      }

      // Try fallback to absolute safe application directory if public path errors
      try {
        final safeDir = await getApplicationSupportDirectory();
        final safePath = p.join(safeDir.path, filename);
        
        final response = await _dio.download(
          url,
          safePath,
          cancelToken: task.cancelToken,
          onReceiveProgress: (received, total) {
            if (total > 0) {
              task.progress = received / total;
              task.onStateChanged?.call();
            }
            onProgress(received, total);
          },
        );
        
        if (response.statusCode == 200) {
          task.status = 'completed';
          task.progress = 1.0;
          task.onStateChanged?.call();
          activeTasks.remove(task);
          return safePath;
        } else {
          task.status = 'failed';
          task.onStateChanged?.call();
          throw Exception('Secure download fallback also failed: ${response.statusCode}');
        }
      } catch (fallbackError) {
        if (fallbackError is DioException && CancelToken.isCancel(fallbackError)) {
          task.status = 'paused';
          task.onStateChanged?.call();
          throw Exception('下载已暂停');
        }
        task.status = 'failed';
        task.onStateChanged?.call();
        rethrow;
      }
    }
  }
}
