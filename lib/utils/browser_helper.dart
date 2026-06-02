import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

class BrowserHelper {
  static const MethodChannel _channel = MethodChannel('link.moely.mobile/browser');

  /// Launches the given [url] in Google Chrome if it is installed,
  /// otherwise falls back to the system default browser.
  static Future<void> launchWithChromePriority(String url) async {
    if (kIsWeb) {
      // Standard launch on web
      final Uri defaultUri = Uri.parse(url);
      if (!await launchUrl(defaultUri, mode: LaunchMode.externalApplication)) {
        throw '无法打开外部浏览器，请重试';
      }
      return;
    }

    if (Platform.isAndroid) {
      try {
        final bool? success = await _channel.invokeMethod<bool>('openInChrome', {'url': url});
        if (success == true) {
          debugPrint('Opened URL in Chrome successfully via MethodChannel on Android.');
          return;
        }
      } catch (e) {
        debugPrint('Failed to open in Chrome via MethodChannel: $e. Falling back to default browser.');
      }
    } else if (Platform.isIOS) {
      try {
        final String chromeUrlString = url
            .replaceFirst('https://', 'googlechromes://')
            .replaceFirst('http://', 'googlechrome://');
        final Uri chromeUri = Uri.parse(chromeUrlString);
        if (await canLaunchUrl(chromeUri)) {
          final bool launched = await launchUrl(chromeUri, mode: LaunchMode.externalApplication);
          if (launched) {
            debugPrint('Opened URL in Chrome successfully via scheme on iOS.');
            return;
          }
        }
      } catch (e) {
        debugPrint('Failed to open in Chrome via scheme on iOS: $e. Falling back to default browser.');
      }
    }

    // Fallback to default browser
    final Uri defaultUri = Uri.parse(url);
    final bool launched = await launchUrl(defaultUri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw '无法打开外部浏览器，请重试';
    }
  }
}
