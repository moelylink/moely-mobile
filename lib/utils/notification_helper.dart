import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:open_filex/open_filex.dart';
import 'package:flutter/foundation.dart';

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  /// Initialize the notification service and request permission
  static Future<void> init() async {
    if (_initialized) return;

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    try {
      await _notificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          final String? payload = response.payload;
          if (payload != null && payload.isNotEmpty) {
            try {
              await OpenFilex.open(payload);
            } catch (e) {
              debugPrint('Failed to open file from notification tap: $e');
            }
          }
        },
      );

      // Create notification channels for Android
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) {
        // 1. Channel for active progress (low importance, no sounds during updates)
        await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
          'download_progress_channel',
          '下载进度通知',
          description: '显示文件下载的实时进度',
          importance: Importance.low,
          showBadge: false,
          playSound: false,
          enableVibration: false,
        ));

        // 2. Channel for completion/failure alerts (high importance)
        await androidPlugin.createNotificationChannel(const AndroidNotificationChannel(
          'download_status_channel',
          '下载完成通知',
          description: '显示文件下载成功或失败的状态',
          importance: Importance.high,
          showBadge: true,
          playSound: true,
          enableVibration: true,
        ));
        
        // Request notifications permission at runtime (required for Android 13+)
        await androidPlugin.requestNotificationsPermission();
      }

      // Request permission for iOS/macOS
      final iosPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) {
        await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      _initialized = true;
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
    }
  }

  static final Map<String, int> _lastProgressMap = {};

  /// Cancels an active notification by its filename's hashCode
  static Future<void> cancelNotification(String filename) async {
    if (!_initialized) {
      await init();
    }
    try {
      await _notificationsPlugin.cancel(filename.hashCode);
    } catch (e) {
      debugPrint('Failed to cancel notification: $e');
    }
  }

  /// Displays or updates a local notification showing download progress or completion
  static Future<void> showDownloadNotification({
    required String filename,
    required double progress,
    String? filePath,
    bool isCompleted = false,
    bool isFailed = false,
  }) async {
    // Lazy-initialize the plugin if not already done
    if (!_initialized) {
      await init();
    }

    final int notificationId = filename.hashCode;

    if (isCompleted) {
      _lastProgressMap.remove(filename);

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'download_status_channel',
        '下载完成通知',
        channelDescription: '显示文件下载成功或失败的状态',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        onlyAlertOnce: false,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.show(
        notificationId,
        '下载完成',
        filename,
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
        payload: filePath,
      );
      return;
    }

    if (isFailed) {
      _lastProgressMap.remove(filename);

      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'download_status_channel',
        '下载完成通知',
        channelDescription: '显示文件下载成功或失败的状态',
        importance: Importance.high,
        priority: Priority.high,
        showWhen: true,
        onlyAlertOnce: false,
      );

      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );

      await _notificationsPlugin.show(
        notificationId,
        '下载失败',
        filename,
        NotificationDetails(
          android: androidDetails,
          iOS: iosDetails,
        ),
      );
      return;
    }

    // Throttling mechanism: Only trigger updates if the rounded percentage changes by >= 5%
    final int progressPercent = (progress * 100).clamp(0, 100).toInt();
    final int? lastProgress = _lastProgressMap[filename];
    if (lastProgress != null && (progressPercent - lastProgress).abs() < 5) {
      return;
    }
    _lastProgressMap[filename] = progressPercent;

    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_progress_channel',
      '下载进度通知',
      channelDescription: '显示文件下载的实时进度',
      importance: Importance.low,
      priority: Priority.low,
      onlyAlertOnce: true,
      showProgress: true,
      maxProgress: 100,
      progress: progressPercent,
      ongoing: true, // Keep it persistent in status bar while downloading
    );

    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: false, // Don't pop up banners constantly while downloading
      presentBadge: false,
      presentSound: false,
    );

    await _notificationsPlugin.show(
      notificationId,
      '正在下载 ($progressPercent%)',
      filename,
      NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      ),
    );
  }
}
