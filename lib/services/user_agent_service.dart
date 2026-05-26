import 'package:package_info_plus/package_info_plus.dart';

class UserAgentService {
  static String _userAgent = 'MoelyMobile/2.0.0'; // Fallback version if initialization fails

  /// Get the dynamically resolved clean Native User-Agent string: e.g. "MoelyMobile/2.0.0"
  static String get userAgent => _userAgent;

  /// Fetch app metadata dynamically from platform build definitions
  static Future<void> initialize() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      _userAgent = 'MoelyMobile/${packageInfo.version}';
    } catch (_) {
      // In case of error (e.g. unit tests or local simulation), fallback to hardcoded v2.0.0
    }
  }
}
