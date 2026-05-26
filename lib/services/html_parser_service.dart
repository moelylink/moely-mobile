import 'package:dio/dio.dart';
import '../models/image_item.dart';
import 'user_agent_service.dart';

class HtmlParserService {
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    headers: {
      'User-Agent': UserAgentService.userAgent,
    },
  ));

  /// Parse portfolio-item lists into MoelyImage objects
  static List<MoelyImage> parseHtmlToImages(String html) {
    final List<MoelyImage> list = [];
    
    // Split HTML by portfolio-item block
    final parts = html.split('portfolio-item');
    if (parts.length <= 1) return list;
    
    // The first chunk is before the first portfolio-item, skip it
    for (int i = 1; i < parts.length; i++) {
      final block = parts[i];
      
      // 1. Extract ID
      final idRegex = RegExp('href=/img/([0-9]+)/');
      final idMatch = idRegex.firstMatch(block);
      if (idMatch == null) continue;
      final id = idMatch.group(1)!;
      
      // 2. Extract Preview Image URL
      final srcRegex = RegExp('data-src=([^ >]+)');
      final srcMatch = srcRegex.firstMatch(block);
      if (srcMatch == null) continue;
      var urls = srcMatch.group(1)!;
      // Strip trailing quotes or brackets
      urls = urls.replaceAll('"', '').replaceAll("'", '').replaceAll('>', '');
      
      // 3. Extract Total count (if any)
      final totalRegex = RegExp('class=total-num>([0-9]+)');
      final totalMatch = totalRegex.firstMatch(block);
      final total = totalMatch?.group(1);
      
      // 4. Extract Author and Platform
      final authorRegex = RegExp('By (Pixiv|Twitter) @([^<]+)');
      final authorMatch = authorRegex.firstMatch(block);
      final category = authorMatch?.group(1) ?? 'Other';
      final user = authorMatch?.group(2)?.trim() ?? 'Unknown';
      
      list.add(MoelyImage(
        id: id,
        user: user,
        category: category,
        urls: urls,
        total: total,
      ));
    }
    
    return list;
  }

  /// Fetch illustrations for a specific category (e.g. 'pixiv', 'twitter')
  static Future<List<MoelyImage>> fetchCategoryImages(String category, int page) async {
    final String url = page == 1
        ? 'https://www.moely.link/category/$category/'
        : 'https://www.moely.link/category/$category/page/$page/';
        
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return parseHtmlToImages(response.data.toString());
      }
    } catch (_) {}
    return [];
  }

  /// Fetch illustrations for a specific tag name
  static Future<List<MoelyImage>> fetchTagImages(String tag, int page) async {
    final encodedTag = Uri.encodeComponent(tag);
    final String url = page == 1
        ? 'https://www.moely.link/tags/$encodedTag/'
        : 'https://www.moely.link/tags/$encodedTag/page/$page/';
        
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return parseHtmlToImages(response.data.toString());
      }
    } catch (_) {}
    return [];
  }

  /// Fetch search query illustrations
  static Future<List<MoelyImage>> fetchSearchImages(String query, int page) async {
    final encodedQuery = Uri.encodeComponent(query);
    final String url = page == 1
        ? 'https://www.moely.link/?s=$encodedQuery'
        : 'https://www.moely.link/page/$page/?s=$encodedQuery';
        
    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        return parseHtmlToImages(response.data.toString());
      }
    } catch (_) {}
    return [];
  }

  /// Fetch tag cloud from /tags/
  static Future<List<Map<String, dynamic>>> fetchTagsList() async {
    final List<Map<String, dynamic>> tags = [];
    try {
      final response = await _dio.get('https://www.moely.link/tags/');
      if (response.statusCode == 200) {
        final html = response.data.toString();
        // Regex matches standard tags like <span><a href=/tags/%E5%A5%B3%E5%AD%A9%E5%AD%90/>#女孩子 (1497)</a></span>
        final tagRegex = RegExp('href=/tags/([^/]+)/>#?([^(]+)\\(([0-9]+)\\)</a>');
        final matches = tagRegex.allMatches(html);
        
        for (final m in matches) {
          final urlName = Uri.decodeComponent(m.group(1)!);
          final displayName = m.group(2)!.trim();
          final count = int.tryParse(m.group(3)!) ?? 0;
          
          tags.add({
            'name': displayName,
            'urlName': urlName,
            'count': count,
          });
        }
      }
    } catch (_) {}
    return tags;
  }
}
