import 'dart:io';
import 'dart:math' as math;
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/settings_service.dart';
import '../utils/toast_helper.dart';
import '../services/url_handler_service.dart';
import '../utils/notification_helper.dart';

class UpdateService {
  static bool _isDownloading = false;

  /// Check for updates
  static Future<void> checkUpdate({bool force = false}) async {
    // Only check if autoCheckUpdate is enabled or if force is true
    if (!AppSettings.instance.autoCheckUpdate && !force) {
      return;
    }

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final localVersion = packageInfo.version;
      
      // Fetch latest version from URL
      final dio = Dio();
      final response = await dio.get(
        'https://mobile.moely.link/app/version.txt',
        options: Options(responseType: ResponseType.plain),
      );
      
      if (response.statusCode == 200) {
        final remoteVersion = response.data.toString().trim();
        if (_isNewVersion(localVersion, remoteVersion)) {
          final context = UrlHandlerService.navigatorKey.currentContext;
          if (context != null) {
            _showUpdateDialog(context, remoteVersion);
          }
        } else if (force) {
          final context = UrlHandlerService.navigatorKey.currentContext;
          if (context != null) {
            ToastHelper.show(context, '当前已是最新版本', type: ToastType.success);
          }
        }
      } else {
        if (force) {
          final context = UrlHandlerService.navigatorKey.currentContext;
          if (context != null) {
            ToastHelper.show(context, '检查更新失败，请稍后重试', type: ToastType.error);
          }
        }
      }
    } catch (e) {
      debugPrint('Update check failed: $e');
      if (force) {
        final context = UrlHandlerService.navigatorKey.currentContext;
        if (context != null) {
          ToastHelper.show(context, '检查更新出错，请检查网络', type: ToastType.error);
        }
      }
    }
  }

  /// Version comparison helper
  static bool _isNewVersion(String local, String remote) {
    final localClean = local.replaceAll(RegExp(r'^v'), '').trim();
    final remoteClean = remote.replaceAll(RegExp(r'^v'), '').trim();

    final localBase = localClean.split('+')[0];
    final remoteBase = remoteClean.split('+')[0];

    final localParts = localBase.split('.');
    final remoteParts = remoteBase.split('.');

    final length = localParts.length > remoteParts.length ? localParts.length : remoteParts.length;
    for (int i = 0; i < length; i++) {
      final localVal = i < localParts.length ? (int.tryParse(localParts[i]) ?? 0) : 0;
      final remoteVal = i < remoteParts.length ? (int.tryParse(remoteParts[i]) ?? 0) : 0;
      if (remoteVal > localVal) return true;
      if (remoteVal < localVal) return false;
    }

    // Check build number if versions are equal
    final localHasBuild = localClean.contains('+');
    final remoteHasBuild = remoteClean.contains('+');
    if (localHasBuild && remoteHasBuild) {
      final localBuild = int.tryParse(localClean.split('+')[1]) ?? 0;
      final remoteBuild = int.tryParse(remoteClean.split('+')[1]) ?? 0;
      return remoteBuild > localBuild;
    } else if (remoteHasBuild) {
      return true;
    }

    return false;
  }

  /// Show the premium update dialog
  static void _showUpdateDialog(BuildContext context, String remoteVersion) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        final theme = Theme.of(context);
        final isDark = theme.brightness == Brightness.dark;
        
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          backgroundColor: theme.colorScheme.surface,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        theme.colorScheme.surface,
                        theme.colorScheme.surface.withBlue(theme.colorScheme.surface.blue + 10),
                      ]
                    : [
                        theme.colorScheme.surface,
                        theme.colorScheme.surface.withBlue(255),
                      ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top Visual Icon / Animation
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.system_update_rounded,
                      size: 40,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Title
                Text(
                  '发现新版本！',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Version Info
                Text(
                  '最新版本: v$remoteVersion',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Update note / description
                Text(
                  '新版本已准备就绪。点击更新将会在后台下载并自动安装，不影响您的正常使用。',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 24),
                
                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          '以后再说',
                          style: TextStyle(
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          _startDownload(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.colorScheme.primary,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          '立即更新',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Start background download
  static Future<void> _startDownload(BuildContext context) async {
    if (_isDownloading) {
      ToastHelper.show(context, '正在下载中，请勿重复操作', type: ToastType.warning);
      return;
    }

    _isDownloading = true;
    ToastHelper.show(context, '开始在后台下载更新...', type: ToastType.info);

    try {
      // Check install package permission for Android
      if (Platform.isAndroid) {
        final status = await Permission.requestInstallPackages.status;
        if (!status.isGranted) {
          // Request permission
          final result = await Permission.requestInstallPackages.request();
          if (!result.isGranted) {
            _isDownloading = false;
            ToastHelper.show(context, '未获得应用安装权限，无法自动安装', type: ToastType.error);
            return;
          }
        }
      }

      final directory = await getTemporaryDirectory();
      final savePath = '${directory.path}/moely_release.apk';
      
      // Show starting notification
      NotificationHelper.showDownloadNotification(
        filename: 'moely_release.apk',
        progress: 0.0,
      );

      final dio = Dio();
      await dio.download(
        'https://mobile.moely.link/app/release.apk',
        savePath,
        onReceiveProgress: (received, total) {
          if (total > 0) {
            NotificationHelper.showDownloadNotification(
              filename: 'moely_release.apk',
              progress: received / total,
            );
          }
        },
      );

      _isDownloading = false;

      // Show completed notification
      NotificationHelper.showDownloadNotification(
        filename: 'moely_release.apk',
        progress: 1.0,
        filePath: savePath,
        isCompleted: true,
      );
      
      // Auto install
      final installResult = await OpenFilex.open(savePath);
      if (installResult.type != ResultType.done) {
        final errContext = UrlHandlerService.navigatorKey.currentContext;
        if (errContext != null) {
          ToastHelper.show(errContext, '打开安装包失败: ${installResult.message}', type: ToastType.error);
        }
      }
    } catch (e) {
      _isDownloading = false;
      debugPrint('Download update failed: $e');
      
      // Show failure notification
      NotificationHelper.showDownloadNotification(
        filename: 'moely_release.apk',
        progress: 0.0,
        isFailed: true,
      );

      final errContext = UrlHandlerService.navigatorKey.currentContext;
      if (errContext != null) {
        ToastHelper.show(errContext, '更新包下载失败，请检查网络', type: ToastType.error);
      }
    }
  }
}
