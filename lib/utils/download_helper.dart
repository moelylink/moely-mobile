import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

class DownloadHelper {
  static final Dio _dio = Dio();

  /// Downloads an image to public/private storage, adaptively supporting Android & iOS
  static Future<String> downloadImage(
    String url, 
    String filename, {
    required void Function(int received, int total) onProgress,
  }) async {
    try {
      Directory? targetDir;

      if (Platform.isAndroid) {
        // Try public Download folder on Android for premium UX
        final publicDownloadDir = Directory('/storage/emulated/0/Download/moely');
        if (!await publicDownloadDir.exists()) {
          await publicDownloadDir.create(recursive: true);
        }
        targetDir = publicDownloadDir;
      } else {
        // iOS / other platforms get app's documents directory
        targetDir = await getApplicationDocumentsDirectory();
      }

      final savePath = p.join(targetDir.path, filename);
      
      final response = await _dio.download(
        url,
        savePath,
        onReceiveProgress: onProgress,
      );

      if (response.statusCode == 200) {
        return savePath;
      } else {
        throw Exception('Download failed with status: ${response.statusCode}');
      }
    } catch (e) {
      // Fallback to absolute safe application directory if public path errors
      final safeDir = await getApplicationSupportDirectory();
      final safePath = p.join(safeDir.path, filename);
      
      final response = await _dio.download(
        url,
        safePath,
        onReceiveProgress: onProgress,
      );
      
      if (response.statusCode == 200) {
        return safePath;
      } else {
        throw Exception('Secure download fallback also failed: $e');
      }
    }
  }
}
