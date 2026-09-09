import 'dart:io';
import 'package:flutter/services.dart';

class WidgetService {
  static const MethodChannel _channel = MethodChannel('link.moely.mobile/widget');

  /// Check if the current platform is Android
  static bool get isPlatformAndroid => Platform.isAndroid;

  /// Pin a widget to the home screen
  static Future<bool> pinWidget(String providerName) async {
    if (!isPlatformAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('pinWidget', {
        'providerName': providerName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to pin widget: ${e.message}');
      return false;
    }
  }

  /// Check if premium widgets are unlocked
  static Future<bool> isPremiumUnlocked() async {
    if (!isPlatformAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('isPremiumUnlocked');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to check premium status: ${e.message}');
      return false;
    }
  }

  /// Set the premium unlock status
  static Future<bool> setPremiumUnlocked(bool value) async {
    if (!isPlatformAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('setPremiumUnlocked', {
        'value': value,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set premium status: ${e.message}');
      return false;
    }
  }

  /// Force update all widget instances of a provider
  static Future<bool> updateWidget(String providerName) async {
    if (!isPlatformAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('updateWidget', {
        'providerName': providerName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to update widget: ${e.message}');
      return false;
    }
  }

  /// Save configuration for custom gallery widget (optionally for a specific instance)
  static Future<bool> setGalleryImages(
    List<String> images, {
    int? widgetId,
    String title = "自定义画廊",
    int scale = 6,
  }) async {
    if (!isPlatformAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('setGalleryImages', {
        'images': images,
        'widgetId': widgetId,
        'title': title,
        'scale': scale,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to set gallery images: ${e.message}');
      return false;
    }
  }

  /// Get configuration map for custom gallery widget (optionally for a specific instance)
  static Future<Map<String, dynamic>> getGalleryConfig({int? widgetId}) async {
    if (!isPlatformAndroid) return {'images': <String>[], 'title': '自定义画廊', 'scale': 6};
    try {
      final Map? result = await _channel.invokeMapMethod('getGalleryImages', {
        'widgetId': widgetId,
      });
      if (result != null) {
        return {
          'images': (result['images'] as List?)?.map((e) => e.toString()).toList() ?? <String>[],
          'title': result['title']?.toString() ?? '自定义画廊',
          'scale': (result['scale'] as num?)?.toInt() ?? 6,
        };
      }
    } on PlatformException catch (e) {
      print('Failed to get gallery images: ${e.message}');
    }
    return {'images': <String>[], 'title': '自定义画廊', 'scale': 6};
  }

  /// Get active gallery widgets placed on the home screen
  static Future<List<Map<String, dynamic>>> getActiveGalleryWidgets() async {
    if (!isPlatformAndroid) return [];
    try {
      final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>('getActiveGalleryWidgets');
      if (result != null) {
        return result.map((item) {
          final map = item as Map;
          return {
            'id': (map['id'] as num).toInt(),
            'title': map['title']?.toString() ?? '自定义画廊',
          };
        }).toList();
      }
    } on PlatformException catch (e) {
      print('Failed to get active gallery widgets: ${e.message}');
    }
    return [];
  }

  /// Get all active widgets placed on the home screen across all providers
  static Future<List<Map<String, dynamic>>> getAllActiveWidgets() async {
    if (!isPlatformAndroid) return [];
    try {
      final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>('getAllActiveWidgets');
      if (result != null) {
        final List<Map<String, dynamic>> list = [];
        for (final item in result) {
          if (item is Map) {
            final idVal = item['id'];
            final id = idVal is num ? idVal.toInt() : 0;
            list.add({
              'id': id,
              'type': item['type']?.toString() ?? 'gallery',
              'provider': item['provider']?.toString() ?? 'GalleryWidgetProvider',
              'customName': item['customName']?.toString() ?? '',
            });
          }
        }
        return list;
      }
    } on PlatformException catch (e) {
      print('Failed to get all active widgets: ${e.message}');
      rethrow;
    }
    return [];
  }

  /// Save custom name for a specific widget instance
  static Future<bool> saveWidgetCustomName(int widgetId, String customName) async {
    if (!isPlatformAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('saveWidgetCustomName', {
        'widgetId': widgetId,
        'customName': customName,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to save widget custom name: ${e.message}');
      return false;
    }
  }

  /// Check if launcher shortcut permission is granted
  static Future<bool> checkShortcutPermission() async {
    if (!isPlatformAndroid) return true;
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkShortcutPermission');
      return result ?? true;
    } on PlatformException catch (e) {
      print('Failed to check shortcut permission: ${e.message}');
      return true;
    }
  }

  /// Open shortcut permission settings
  static Future<bool> openShortcutPermissionSettings() async {
    if (!isPlatformAndroid) return false;
    try {
      final bool? result = await _channel.invokeMethod<bool>('openShortcutPermissionSettings');
      return result ?? false;
    } on PlatformException catch (e) {
      print('Failed to open shortcut settings: ${e.message}');
      return false;
    }
  }
}
