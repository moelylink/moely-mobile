import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/image_details.dart';
import 'user_agent_service.dart';

class ImageDetailsParser {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': UserAgentService.userAgent,
    },
  ));

  /// Scrape moely.link detail page HTML for rich native elements
  static Future<ImageDetails?> fetchDetails(String id) async {
    try {
      final response = await _dio.get('https://www.moely.link/img/$id/');
      if (response.statusCode != 200) return null;
      
      final html = response.data.toString();

      // 1. Extract resolution (e.g. 原图尺寸：宽784x高2048)
      String resolution = '未知尺寸';
      final resRegex = RegExp('原图尺寸：([^<>\n|]+)');
      final resMatch = resRegex.firstMatch(html);
      if (resMatch != null) {
        resolution = resMatch.group(1)?.trim() ?? '未知尺寸';
      }

      // 2. Extract original source link
      String sourceUrl = '';
      final sourceRegex = RegExp('href="([^"]+)"[^>]*>查看来源</a>');
      final sourceMatch = sourceRegex.firstMatch(html);
      if (sourceMatch != null) {
        sourceUrl = sourceMatch.group(1) ?? '';
      }

      // 3. Extract ALL original image download links
      // e.g. downloadImg("downloadText_p0","2057757333657399317_p0","aHR0cHM6...")
      final List<String> downloadUrls = [];
      final downloadRegex = RegExp('downloadImg\\s*\\(\\s*["\'][^"\']*["\']\\s*,\\s*["\'][^"\']*["\']\\s*,\\s*["\']([^"\']+)["\']\\s*\\)');
      final downloadMatches = downloadRegex.allMatches(html);
      
      for (final match in downloadMatches) {
        final base64Str = match.group(1) ?? '';
        if (base64Str.isNotEmpty) {
          try {
            final decodedBytes = base64.decode(base64Str);
            final decodedUrl = utf8.decode(decodedBytes);
            if (decodedUrl.isNotEmpty && !downloadUrls.contains(decodedUrl)) {
              downloadUrls.add(decodedUrl);
            }
          } catch (_) {}
        }
      }

      // Fallback first downloadUrl
      final String downloadUrl = downloadUrls.isNotEmpty ? downloadUrls.first : '';

      // 4. Extract ALL preview/medium image URLs
      // E.g. data-src="https://t.moely.link/media/..."
      final List<String> previewUrls = [];
      final previewRegex = RegExp('data-src="([^"]+)"');
      final previewMatches = previewRegex.allMatches(html);
      for (final match in previewMatches) {
        var url = match.group(1) ?? '';
        url = url.replaceAll('&amp;', '&');
        // Only include illustrations which reside in /media/
        if (url.isNotEmpty && url.contains('/media/') && !previewUrls.contains(url)) {
          previewUrls.add(url);
        }
      }

      // 5. Extract description from #detail_info via pure stable string manipulation
      // e.g. <div id=detail_info>Springあまね😏✨🥺</div>
      String description = '暂无描述';
      final startTagDouble = 'id="detail_info">';
      final startTagSingle = 'id=\'detail_info\'>';
      final startTagNoQuote = 'id=detail_info>';
      
      int startPos = -1;
      int idx = html.indexOf(startTagDouble);
      if (idx != -1) {
        startPos = idx + startTagDouble.length;
      } else {
        idx = html.indexOf(startTagSingle);
        if (idx != -1) {
          startPos = idx + startTagSingle.length;
        } else {
          idx = html.indexOf(startTagNoQuote);
          if (idx != -1) {
            startPos = idx + startTagNoQuote.length;
          }
        }
      }

      if (startPos != -1) {
        final endPos = html.indexOf('</div>', startPos);
        if (endPos != -1) {
          description = html.substring(startPos, endPos).trim();
          // Clean basic HTML tags from description if any
          description = description.replaceAll(RegExp('<[^>]*>'), '');
        }
      }

      // 6. Extract tags
      final List<String> tags = [];
      final tagRegex = RegExp('href="[^"]*/tags/[^"]*"[^>]*>#?([^<]+)</a>');
      final tagMatches = tagRegex.allMatches(html);
      for (var m in tagMatches) {
        final t = m.group(1)?.trim();
        if (t != null && t.isNotEmpty && t != '暂无标签') {
          if (!t.startsWith('#')) {
            tags.add('#$t');
          } else {
            tags.add(t);
          }
        }
      }

      return ImageDetails(
        id: id,
        resolution: resolution,
        tags: tags,
        sourceUrl: sourceUrl,
        downloadUrl: downloadUrl,
        downloadUrls: downloadUrls,
        previewUrls: previewUrls,
        description: description,
      );
    } catch (e) {
      // Return basic model on network error instead of failing
      return ImageDetails(
        id: id,
        resolution: '未连接网络',
        tags: [],
        sourceUrl: '',
        downloadUrl: '',
        downloadUrls: [],
        previewUrls: [],
        description: '加载失败，请检查网络连接',
      );
    }
  }
}
