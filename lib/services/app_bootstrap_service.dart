import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/io_client.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_agent_service.dart';
import 'settings_service.dart';
import 'kanban_service.dart';
import 'url_handler_service.dart';
import 'auth_service.dart';
import '../utils/notification_helper.dart';
import '../utils/cache_helper.dart';
import '../utils/app_image_cache_manager.dart';

class AppBootstrapService {
  static Future<void>? _initFuture;

  /// Trigger asynchronous initialization in parallel.
  /// Idempotent: Subsequent calls return the same future.
  static Future<void> start() {
    return _initFuture ??= _performInit();
  }

  static Future<void> _performInit() async {
    try {
      final ioHttpClient = HttpClient()
        ..idleTimeout = const Duration(seconds: 2)
        ..connectionTimeout = const Duration(seconds: 10);
      final supabaseHttpClient = IOClient(ioHttpClient);

      // Execute essential services concurrently to avoid serial blocking
      await Future.wait([
        NotificationHelper.init(),
        Supabase.initialize(
          url: 'https://fefckqwvcvuadiixvhns.supabase.co',
          anonKey:
              'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZlZmNrcXd2Y3Z1YWRpaXh2aG5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYzNDE5OTUsImV4cCI6MjA1MTkxNzk5NX0.-OUllwH7v2K-j4uIx7QQaV654R5Gz5_1jP4BGdkWWfg',
          httpClient: supabaseHttpClient,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        ),
        UserAgentService.initialize(),
        AppSettings.instance.init(),
        KanbanService.instance.init(),
      ]);

      // Initialize Deep Linking listeners & AuthService listener
      UrlHandlerService.initialize();
      AuthService.instance;

      // Trigger low-priority background auto cache cleanup and legacy image cache migration
      Future.delayed(const Duration(seconds: 3), () async {
        await AppImageCacheManager.migrateLegacyCache();
        CacheHelper.performAutoCacheCleanup();
      });
    } catch (e, stack) {
      debugPrint('[AppBootstrapService] Initialization error: $e\n$stack');
    }
  }
}
