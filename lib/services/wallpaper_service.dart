import 'package:flutter/services.dart';

class WallpaperService {
  static const _channel = MethodChannel('link.moely.mobile/wallpaper');

  /// Set native wallpaper.
  /// [type]: 1 = System/Desktop, 2 = Lock Screen, 3 = Both System and Lock
  static Future<bool> setWallpaper(String path, int type) async {
    try {
      final bool result = await _channel.invokeMethod('setWallpaper', {
        'path': path,
        'type': type,
      });
      return result;
    } on PlatformException catch (e) {
      throw Exception('平台操作失败: ${e.message}');
    } catch (e) {
      throw Exception('未知错误: $e');
    }
  }

  /// Scan media file to refresh native gallery.
  static Future<void> scanFile(String path) async {
    try {
      await _channel.invokeMethod('scanFile', {'path': path});
    } catch (_) {
      // Ignore errors for media scanning non-critically
    }
  }
}
