import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import '../models/image_item.dart';
import '../models/artist_item.dart';
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
      final idRegex = RegExp(r'''href=["']?(?:https?://[^/]+)?/img/([0-9]+)/?["']?''');
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
      
      // 4. Extract Author and Platform (Supports optional '@' prefix for both new and old formats)
      final authorRegex = RegExp(r'By\s+(Pixiv|Twitter)\s+@?([^<]+)');
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
      if (cachedResult != null) return cachedResult;
      throw Exception('Failed to load category images: ${response.statusCode}');
    } catch (e) {
      if (cachedResult != null) return cachedResult;
      rethrow;
    }
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
      if (cachedResult != null) return cachedResult;
      throw Exception('Failed to load tag images: ${response.statusCode}');
    } catch (e) {
      if (cachedResult != null) return cachedResult;
      rethrow;
    }
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
      if (cachedResult != null) return cachedResult;
      throw Exception('Failed to load home images: ${response.statusCode}');
    } catch (e) {
      if (cachedResult != null) return cachedResult;
      rethrow;
    }
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

          // Get clean page ID from URL (handles /img/1234/, https://www.moely.link/img/1234/?s=1, etc.)
          final idMatch = RegExp(r'/img/(\d+)').firstMatch(hitUrl);
          if (idMatch == null) continue;
          final pageId = idMatch.group(1)!;

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
      throw Exception('Search request returned status: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  /// Fetch all artists from /artist/
  static Future<List<ArtistItem>> fetchArtistsList() async {
    const String cacheKey = 'artists_list_cache';

    // Try offline load first
    try {
      final cachedMap = await CacheHelper.loadIndexFromCache(cacheKey);
      if (cachedMap != null && cachedMap['artists'] is List) {
        final list = (cachedMap['artists'] as List)
            .map((item) => ArtistItem.fromJson(item as Map<String, dynamic>))
            .toList();
        if (list.isNotEmpty) {
          // Trigger silent background update
          _updateArtistsListBackground(cacheKey);
          return list;
        }
      }
    } catch (_) {}

    return await _fetchAndSaveArtistsList(cacheKey);
  }

  static Future<List<ArtistItem>> _fetchAndSaveArtistsList(String cacheKey) async {
    final List<ArtistItem> artists = [];
    try {
      final response = await _dio.get('https://www.moely.link/artist/');
      if (response.statusCode == 200) {
        final html = response.data.toString();
        
        // Match each artist card
        final cardRegex = RegExp(
          r'''<a\s+[^>]*class=["']?[^"'>]*artist-card-item[^"'>]*["']?[^>]*>([\s\S]*?)</a>''',
          caseSensitive: false,
        );
        final matches = cardRegex.allMatches(html);

        for (final m in matches) {
          final fullTag = m.group(0) ?? '';
          final innerContent = m.group(1) ?? '';

          // 1. Extract UID
          final uidMatch = RegExp(r'''data-uid=["']?([^"'\s>]+)''').firstMatch(fullTag);
          final uid = uidMatch?.group(1)?.trim() ?? '';
          if (uid.isEmpty) continue;

          // 2. Extract Name
          String name = '';
          final nameTagMatch = RegExp(r'''class=["']?artist-card-name["']?[^>]*>([^<]+)</div>''').firstMatch(innerContent);
          if (nameTagMatch != null) {
            name = nameTagMatch.group(1)?.trim() ?? '';
          }
          if (name.isEmpty) {
            final nameAttrMatch = RegExp(r'''data-name=["']?([^"'>]+)''').firstMatch(fullTag);
            name = nameAttrMatch?.group(1)?.trim() ?? uid;
          }

          // 3. Extract Count
          final countMatch = RegExp(r'''data-count=["']?([0-9]+)''').firstMatch(fullTag);
          final count = int.tryParse(countMatch?.group(1) ?? '0') ?? 0;

          // 4. Platform info
          final hasPixivMatch = RegExp(r'''data-has-pixiv=["']?(true|false)''').firstMatch(fullTag);
          final hasTwitterMatch = RegExp(r'''data-has-twitter=["']?(true|false)''').firstMatch(fullTag);
          final hasPixiv = hasPixivMatch?.group(1) == 'true';
          final hasTwitter = hasTwitterMatch?.group(1) == 'true';

          final platformMatch = RegExp(r'''data-platform=["']?([^"'\s>]+)''').firstMatch(fullTag);
          final platform = platformMatch?.group(1) ?? (hasPixiv && hasTwitter ? 'both' : (hasTwitter ? 'twitter' : 'pixiv'));

          // 5. Artist URL
          final hrefMatch = RegExp(r'''href=["']?([^"'\s>]+)''').firstMatch(fullTag);
          var artistUrl = hrefMatch?.group(1) ?? '/artist/$uid/';
          if (artistUrl.startsWith('/')) {
            artistUrl = 'https://www.moely.link$artistUrl';
          }

          // 6. Avatar
          String avatar = '';
          final avatarMatch = RegExp(r'''<img\s+[^>]*class=["']?[^"'>]*artist-card-avatar[^"'>]*["']?[^>]*src=["']?([^"'\s>]+)''').firstMatch(innerContent) ??
                              RegExp(r'''<img\s+[^>]*src=["']?([^"'\s>]+)["']?[^>]*class=["']?[^"'>]*artist-card-avatar''').firstMatch(innerContent);
          if (avatarMatch != null) {
            avatar = avatarMatch.group(1) ?? '';
            if (avatar.startsWith('/')) {
              avatar = 'https://www.moely.link$avatar';
            }
          }

          artists.add(ArtistItem(
            uid: uid,
            name: name,
            avatar: avatar,
            count: count,
            hasPixiv: hasPixiv,
            hasTwitter: hasTwitter,
            platform: platform,
            artistUrl: artistUrl,
          ));
        }

        if (artists.isNotEmpty) {
          await CacheHelper.saveIndexToCache(cacheKey, {
            'artists': artists.map((e) => e.toJson()).toList(),
          });
          return artists;
        }
      }
      throw Exception('Failed to load artists: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }

  static void _updateArtistsListBackground(String cacheKey) {
    Future.microtask(() async {
      try {
        await _fetchAndSaveArtistsList(cacheKey);
      } catch (_) {}
    });
  }

  /// Fetch artist profile and artwork items from /artist/$uid/ or /artist/$uid/page/$page/
  static Future<ArtistProfile> fetchArtistProfile(String uid, int page, {String fallbackName = ''}) async {
    final String url = page == 1
        ? 'https://www.moely.link/artist/$uid/'
        : 'https://www.moely.link/artist/$uid/page/$page/';

    final String cacheKey = 'artist_profile_${uid}_page_$page';

    // Try offline load first
    ArtistProfile? cachedProfile;
    try {
      final cachedMap = await CacheHelper.loadIndexFromCache(cacheKey);
      if (cachedMap != null) {
        cachedProfile = ArtistProfile.fromJson(cachedMap);
      }
    } catch (_) {}

    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200) {
        final html = response.data.toString();

        // 1. Extract Artist Avatar
        String avatar = '';
        final avatarMatch = RegExp(r'''<img\s+[^>]*class=["']?[^"'>]*artist-avatar[^"'>]*["']?[^>]*src=["']?([^"'\s>]+)''').firstMatch(html) ??
                            RegExp(r'''<img\s+[^>]*src=["']?([^"'\s>]+)["']?[^>]*class=["']?[^"'>]*artist-avatar''').firstMatch(html);
        if (avatarMatch != null) {
          avatar = avatarMatch.group(1) ?? '';
          if (avatar.startsWith('/')) {
            avatar = 'https://www.moely.link$avatar';
          }
        }

        // 2. Extract Artist Name
        String name = fallbackName;
        final nameMatch = RegExp(r'''<h1\s+class=["']?artist-name["']?[^>]*>[\s\S]*?<span>(?:画师：)?([^<]+)</span>''').firstMatch(html);
        if (nameMatch != null) {
          final matchedName = nameMatch.group(1)?.trim();
          if (matchedName != null && matchedName.isNotEmpty) {
            name = matchedName;
          }
        }
        if (name.isEmpty) {
          name = uid;
        }

        // 3. Extract Works Count
        int count = 0;
        final countMatch = RegExp(r'''收录作品：\s*([0-9]+)\s*幅''').firstMatch(html);
        if (countMatch != null) {
          count = int.tryParse(countMatch.group(1) ?? '0') ?? 0;
        }

        // 4. Extract external profile links
        String? pixivUrl;
        String? twitterUrl;

        final pixivMatch = RegExp(r'''href=["'](https?://(?:www\.)?pixiv\.net/users/[^"']+)["']''').firstMatch(html);
        if (pixivMatch != null) {
          pixivUrl = pixivMatch.group(1);
        }

        final twitterMatch = RegExp(r'''href=["'](https?://(?:twitter\.com|x\.com)/[^"']+)["']''').firstMatch(html);
        if (twitterMatch != null) {
          twitterUrl = twitterMatch.group(1);
        }

        final bool hasPixiv = pixivUrl != null || html.contains('artist-avatar-platform-badge pixiv') || html.contains('dual-platform') || !html.contains('artist-avatar-platform-badge twitter');
        final bool hasTwitter = twitterUrl != null || html.contains('x-twitter');

        // 5. Extract Images and total pages
        final images = parseHtmlToImages(html);
        final parsedPages = parseTotalPages(html);

        final profile = ArtistProfile(
          uid: uid,
          name: name,
          avatar: avatar,
          count: count > 0 ? count : images.length,
          hasPixiv: hasPixiv,
          hasTwitter: hasTwitter,
          pixivUrl: pixivUrl,
          twitterUrl: twitterUrl,
          images: images,
          totalPages: parsedPages > page ? parsedPages : page,
        );

        await CacheHelper.saveIndexToCache(cacheKey, profile.toJson());
        return profile;
      }
      if (cachedProfile != null) return cachedProfile;
      throw Exception('Failed to load artist profile: ${response.statusCode}');
    } catch (e) {
      if (cachedProfile != null) return cachedProfile;
      rethrow;
    }
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
        return tags;
      }
      throw Exception('Failed to load tags: ${response.statusCode}');
    } catch (e) {
      rethrow;
    }
  }
}
