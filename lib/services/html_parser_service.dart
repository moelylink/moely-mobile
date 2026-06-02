import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/image_item.dart';
import 'user_agent_service.dart';
import '../utils/cache_helper.dart';

class HtmlPageResult {
  final List<MoelyImage> images;
  final int totalPages;

  HtmlPageResult({required this.images, required this.totalPages});
}

class HtmlParserService {
  static final Dio _dio = UserAgentService.createDio();

  static Map<String, dynamic> _resultToJson(HtmlPageResult result) {
    return {
      'totalPages': result.totalPages,
      'images': result.images.map((img) => img.toJson()).toList(),
    };
  }

  static HtmlPageResult _resultFromJson(Map<String, dynamic> json) {
    final list = (json['images'] as List? ?? [])
        .map((item) => MoelyImage.fromJson(item as Map<String, dynamic>))
        .toList();
    return HtmlPageResult(
      images: list,
      totalPages: json['totalPages'] ?? 1,
    );
  }

  /// Extract the total number of pages from HTML content
  static int parseTotalPages(String html) {
    // Standard WordPress pagination pattern: href=".../page/(\d+)/..."
    final regex = RegExp(r'page/([0-9]+)/');
    final matches = regex.allMatches(html);
    int maxPage = 1;
    for (final match in matches) {
      final pageNum = int.tryParse(match.group(1) ?? '');
      if (pageNum != null && pageNum > maxPage) {
        maxPage = pageNum;
      }
    }
    return maxPage;
  }

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
      
      // 2. Extract Preview Image URL (Robust parsing matching data-src first, then falling back to src, and prepending schema for relative URLs)
      final srcMatch = RegExp(r'''data-src=["']?([^"'\s>]+)''').firstMatch(block) ??
                       RegExp(r'''src=["']?([^"'\s>]+)''').firstMatch(block);
      if (srcMatch == null) continue;
      var urls = srcMatch.group(1)!;
      if (urls.startsWith('/')) {
        urls = 'https://www.moely.link$urls';
      }
      urls = urls.replaceAll('&amp;', '&');
      
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
  static Future<HtmlPageResult> fetchCategoryImages(String category, int page) async {
    final String url = page == 1
        ? 'https://www.moely.link/category/$category/'
        : 'https://www.moely.link/category/$category/page/$page/';
        
    final String cacheKey = 'category_${category}_page_$page';
    
    // Try offline load first
    HtmlPageResult? cachedResult;
    try {
      final cachedMap = await CacheHelper.loadIndexFromCache(cacheKey);
      if (cachedMap != null) {
        cachedResult = _resultFromJson(cachedMap);
      }
    } catch (_) {}

    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final html = response.data.toString();
        final images = parseHtmlToImages(html);
        final parsedPages = parseTotalPages(html);
        final result = HtmlPageResult(
          images: images,
          totalPages: parsedPages > page ? parsedPages : page,
        );
        
        await CacheHelper.saveIndexToCache(cacheKey, _resultToJson(result));
        return result;
      }
    } catch (_) {
      if (cachedResult != null) return cachedResult;
    }
    return cachedResult ?? HtmlPageResult(images: [], totalPages: 1);
  }

  /// Fetch illustrations for a specific tag name
  static Future<HtmlPageResult> fetchTagImages(String tag, int page) async {
    // If the tag slug contains %, it is already the exact percent-encoded URL path segment from the website.
    // Otherwise, we encode it to make sure it's valid for HTTP.
    final String encodedTag = tag.contains('%') ? tag : Uri.encodeComponent(tag);
    final String url = page == 1
        ? 'https://www.moely.link/tags/$encodedTag/'
        : 'https://www.moely.link/tags/$encodedTag/page/$page/';
        
    final String cacheKey = 'tag_${encodedTag}_page_$page';
    
    // Try offline load first
    HtmlPageResult? cachedResult;
    try {
      final cachedMap = await CacheHelper.loadIndexFromCache(cacheKey);
      if (cachedMap != null) {
        cachedResult = _resultFromJson(cachedMap);
      }
    } catch (_) {}

    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final html = response.data.toString();
        final images = parseHtmlToImages(html);
        final parsedPages = parseTotalPages(html);
        final result = HtmlPageResult(
          images: images,
          totalPages: parsedPages > page ? parsedPages : page,
        );
        
        await CacheHelper.saveIndexToCache(cacheKey, _resultToJson(result));
        return result;
      }
    } catch (_) {
      if (cachedResult != null) return cachedResult;
    }
    return cachedResult ?? HtmlPageResult(images: [], totalPages: 1);
  }

  /// Fetch home page illustrations by parsing HTML
  static Future<HtmlPageResult> fetchHomeImages(int page) async {
    final String url = page == 1
        ? 'https://www.moely.link/'
        : 'https://www.moely.link/page/$page/';
        
    final String cacheKey = 'home_page_$page';
    
    // Try offline load first
    HtmlPageResult? cachedResult;
    try {
      final cachedMap = await CacheHelper.loadIndexFromCache(cacheKey);
      if (cachedMap != null) {
        cachedResult = _resultFromJson(cachedMap);
      }
    } catch (_) {}

    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final html = response.data.toString();
        final images = parseHtmlToImages(html);
        final parsedPages = parseTotalPages(html);
        final result = HtmlPageResult(
          images: images,
          totalPages: parsedPages > page ? parsedPages : page,
        );
        
        await CacheHelper.saveIndexToCache(cacheKey, _resultToJson(result));
        return result;
      }
    } catch (_) {
      if (cachedResult != null) return cachedResult;
    }
    return cachedResult ?? HtmlPageResult(images: [], totalPages: 1);
  }

  // Global cache variables for Algolia search configurations
  static String _algoliaAppId = 'U0L71ACDM6';
  static String _algoliaApiKey = '6be7ad4b51ff3ce560c5e5ebf665428a';
  static String _algoliaIndexName = 'netlify_64116cf5-2468-4c56-9356-24d4d73c4459_main_all';
  static bool _algoliaConfigLoaded = false;

  /// Load Algolia Config from local cache or fetch from https://www.moely.link/search/
  static Future<void> _ensureAlgoliaConfig() async {
    if (_algoliaConfigLoaded) return;

    File? cacheFile;
    try {
      final cacheDir = await getTemporaryDirectory();
      cacheFile = File('${cacheDir.path}/algolia_config.json');
      
      // 1. Try reading from persistent cache
      if (await cacheFile.exists()) {
        final content = await cacheFile.readAsString();
        final Map<String, dynamic> data = json.decode(content);
        if (data.containsKey('appId') && data.containsKey('apiKey') && data.containsKey('indexName')) {
          _algoliaAppId = data['appId']!;
          _algoliaApiKey = data['apiKey']!;
          _algoliaIndexName = data['indexName']!;
          _algoliaConfigLoaded = true;
          // Trigger a background update to keep the keys fresh
          _updateAlgoliaConfigBackground(cacheFile);
          return;
        }
      }
    } catch (_) {}

    // 2. If no cache exists, fetch and parse synchronously to ensure the first search succeeds
    try {
      if (cacheFile != null) {
        await _fetchAndSaveAlgoliaConfig(cacheFile);
      }
    } catch (_) {
      // Fallback to hardcoded defaults is already set
    }
    _algoliaConfigLoaded = true;
  }

  /// Fetch from search page HTML and save to file
  static Future<void> _fetchAndSaveAlgoliaConfig(File cacheFile) async {
    final response = await _dio.get('https://www.moely.link/search/');
    if (response.statusCode == 200) {
      final html = response.data.toString();
      
      // Parse appId and apiKey
      // E.g., algoliasearch('U0L71ACDM6', '6be7ad4b51ff3ce560c5e5ebf665428a')
      final clientMatch = RegExp(r'''algoliasearch\s*\(\s*['"]([^'"]+)['"]\s*,\s*['"]([^'"]+)['"]\s*\)''').firstMatch(html);
      
      // Parse indexName
      // E.g., initIndex('netlify_64116cf5-2468-4c56-9356-24d4d73c4459_main_all')
      final indexMatch = RegExp(r'''initIndex\s*\(\s*['"]([^'"]+)['"]\s*\)''').firstMatch(html);

      if (clientMatch != null && indexMatch != null) {
        final parsedAppId = clientMatch.group(1)!;
        final parsedApiKey = clientMatch.group(2)!;
        final parsedIndexName = indexMatch.group(1)!;

        _algoliaAppId = parsedAppId;
        _algoliaApiKey = parsedApiKey;
        _algoliaIndexName = parsedIndexName;

        final configData = {
          'appId': parsedAppId,
          'apiKey': parsedApiKey,
          'indexName': parsedIndexName,
          'updatedAt': DateTime.now().toIso8601String(),
        };

        await cacheFile.writeAsString(json.encode(configData));
      }
    }
  }

  /// Silently update the cache in the background
  static void _updateAlgoliaConfigBackground(File cacheFile) {
    Future.microtask(() async {
      try {
        await _fetchAndSaveAlgoliaConfig(cacheFile);
      } catch (_) {}
    });
  }

  /// Fetch search query illustrations via Algolia REST API
  static Future<List<MoelyImage>> fetchSearchImages(String query, int page, {int limit = 30}) async {
    await _ensureAlgoliaConfig();
    final String url = 'https://$_algoliaAppId-dsn.algolia.net/1/indexes/$_algoliaIndexName/query';
    
    try {
      final response = await _dio.post(
        url,
        data: {
          'query': query,
          'hitsPerPage': limit,
          'page': page - 1, // Algolia pages are 0-indexed
        },
        options: Options(
          headers: {
            'X-Algolia-API-Key': _algoliaApiKey,
            'X-Algolia-Application-Id': _algoliaAppId,
            'Content-Type': 'application/json',
          },
        ),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> resData = response.data;
        final List<dynamic> hits = resData['hits'] ?? [];
        final List<MoelyImage> list = [];

        for (final hit in hits) {
          final String hitUrl = hit['url'] ?? '';
          if (hitUrl.isEmpty || !hitUrl.contains('/img/')) continue;

          // Get page ID from URL (e.g. /img/1234/ -> 1234)
          final cleanUrl = hitUrl.endsWith('/') ? hitUrl.substring(0, hitUrl.length - 1) : hitUrl;
          final pathParts = cleanUrl.split('/');
          if (pathParts.isEmpty) continue;
          final pageId = pathParts.last;

          // Parse artist and category from description
          // Example description: "由 @username 创作的插画 - ID: 1234，发布于Twitter"
          final String desc = hit['description'] ?? '';
          String user = 'Unknown';
          String category = 'Other';

          if (desc.isNotEmpty) {
            final authorMatch = RegExp(r'由\s*@([^\s，\-]+)\s*创作').firstMatch(desc) ??
                                RegExp(r'由\s*@([^\s]+)\s*创作').firstMatch(desc);
            if (authorMatch != null) {
              user = authorMatch.group(1)?.trim() ?? 'Unknown';
            }

            final lowerDesc = desc.toLowerCase();
            if (lowerDesc.contains('pixiv')) {
              category = 'Pixiv';
            } else if (lowerDesc.contains('twitter')) {
              category = 'Twitter';
            }
          }

          // Get image preview URL or fallback
          final String thumbUrl = hit['image'] ?? 'https://www.moely.link/assets/img/favicon.png';

          list.add(MoelyImage(
            id: pageId,
            user: user,
            category: category,
            urls: thumbUrl,
            total: '1',
          ));
        }
        return list;
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
          final urlName = m.group(1)!;
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
