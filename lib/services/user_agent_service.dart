import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';

class UserAgentService {
  static String _userAgent = 'MoelyMobile/2.0.0'; // Fallback version if initialization fails

  /// Get the dynamically resolved clean Native User-Agent string: e.g. "MoelyMobile/2.0.0"
  static String get userAgent => _userAgent;

  /// Get unified global headers for all requests
  static Map<String, String> get headers => {
    'User-Agent': _userAgent,
    'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,image/apng,*/*;q=0.8',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
  };

  /// Create a Dio client pre-configured with the latest global headers dynamically
  static Dio createDio({BaseOptions? options}) {
    final dio = Dio(options ?? BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ));
    // Add interceptor to dynamically inject latest headers on every request if not already present
    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        for (final entry in headers.entries) {
          if (!options.headers.containsKey(entry.key)) {
            options.headers[entry.key] = entry.value;
          }
        }
        return handler.next(options);
      },
    ));
    return dio;
  }

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
