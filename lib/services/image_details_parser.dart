import 'dart:convert';
import 'package:dio/dio.dart';
import '../models/image_details.dart';
import 'user_agent_service.dart';
import '../utils/cache_helper.dart';

class ImageDetailsParser {
  static final Dio _dio = UserAgentService.createDio();

  /// Scrape moely.link detail page HTML for rich native elements
  static Future<ImageDetails?> fetchDetails(String id, {bool forceRefresh = false}) async {
    // Try to load from local cache first for instant offline-first experience
    if (!forceRefresh && id.isNotEmpty) {
      try {
        final cachedMap = await CacheHelper.loadDetailsFromCache(id);
        if (cachedMap != null) {
          final cached = ImageDetails.fromJson(cachedMap);
          final cleanTitle = cached.title.replaceFirst(RegExp(r'^id[:：]\s*', caseSensitive: false), '').trim();
          final isValidCache = cached.id.isNotEmpty && 
                               cached.title.isNotEmpty && 
                               cleanTitle.isNotEmpty;
          if (isValidCache) {
            return cached;
          }
        }
      } catch (_) {}
    }

    try {
      final response = await _dio.get('https://www.moely.link/img/$id/');
      if (response.statusCode != 200) return null;
      
      final html = response.data.toString();

      // 1. Extract Title (e.g. <h1>day57 风堇 (ID: 130872940)</h1> or <h1>ID: 2058691399894376532</h1>)
      String title = '';
      final titleRegex = RegExp(r'<h1[^>]*>([\s\S]*?)</h1>', caseSensitive: false);
      final titleMatch = titleRegex.firstMatch(html);
      if (titleMatch != null) {
        var rawTitle = titleMatch.group(1)?.trim() ?? '';
        rawTitle = _decodeHtmlEntities(rawTitle).replaceAll(RegExp(r'<[^>]*>'), '').trim();
        final withoutIdPrefix = rawTitle.replaceFirst(RegExp(r'^id[:：]\s*', caseSensitive: false), '').trim();
        if (rawTitle.isNotEmpty && withoutIdPrefix.isNotEmpty) {
          title = rawTitle;
        }
      }
      if (title.isEmpty) {
        title = id.isNotEmpty ? 'ID: $id' : '';
      }

      // 1. Extract resolution (e.g. 原图尺寸：宽<code>1451</code>x高<code>2048</code>)
      String resolution = '';
      final resRegex = RegExp(r'原图尺寸：[^<]*宽(?:<code>)?(\d+)(?:</code>)?\s*x\s*高(?:<code>)?(\d+)(?:</code>)?', caseSensitive: false);
      final resMatch = resRegex.firstMatch(html);
      if (resMatch != null) {
        final width = resMatch.group(1) ?? '';
        final height = resMatch.group(2) ?? '';
        resolution = '${width}x$height';
      }

      // 2. Extract original source link (robustly locate via button text and find immediate parent <a>)
      String sourceUrl = '';
      for (final keyword in ['查看来源', 'btn-source']) {
        final kwIdx = html.indexOf(keyword);
        if (kwIdx != -1) {
          final aStartIdx = html.lastIndexOf('<a', kwIdx);
          if (aStartIdx != -1) {
            final aEndTagIdx = html.indexOf('>', aStartIdx);
            if (aEndTagIdx != -1 && aEndTagIdx < kwIdx + 40) {
              final aTagContent = html.substring(aStartIdx, aEndTagIdx + 1);
              final hrefMatch = RegExp(r'''href=["']?([^"'\s>]+)''', caseSensitive: false).firstMatch(aTagContent);
              if (hrefMatch != null) {
                var url = hrefMatch.group(1)?.trim() ?? '';
                url = url.replaceAll('&amp;', '&');
                if (url.startsWith('http://') || url.startsWith('https://')) {
                  sourceUrl = url;
                  break;
                }
              }
            }
          }
        }
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
      // E.g. data-src="https://t.moely.link/media/..." or src="https://t.moely.link/media/..."
      final List<String> previewUrls = [];
      final previewRegex = RegExp(r'''(?:data-src|src)=["']([^"']+)["']''', caseSensitive: false);
      final previewMatches = previewRegex.allMatches(html);
      for (final match in previewMatches) {
        var url = match.group(1) ?? '';
        url = url.replaceAll('&amp;', '&');
        if (url.startsWith('/')) {
          url = 'https://www.moely.link$url';
        }
        // Only include illustrations which reside in /media/
        if (url.isNotEmpty && url.contains('/media/') && !previewUrls.contains(url)) {
          previewUrls.add(url);
        }
      }

      // Self-healing: if previewUrls has fewer items than downloadUrls,
      // populate from downloadUrls to ensure all pages are visible and browsable
      if (previewUrls.length < downloadUrls.length) {
        for (int i = previewUrls.length; i < downloadUrls.length; i++) {
          previewUrls.add(downloadUrls[i]);
        }
      }

      // 4.5 Extract ALL addStar image URLs (for exact thumbnail/star URLs on each page)
      // E.g. addStar("starText","130872940","https://i.moely.link/c/540x540_70/...")
      final List<String> starUrls = [];
      final starRegex = RegExp(r'''addStar\s*\(\s*["\'][^"\']*["\']\s*,\s*["\'][^"\']*["\']\s*,\s*["\']([^"\']+)["\']\s*\)''');
      final starMatches = starRegex.allMatches(html);
      for (final match in starMatches) {
        final url = match.group(1) ?? '';
        if (url.isNotEmpty && !starUrls.contains(url)) {
          starUrls.add(url);
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
          // Replace `<br>` and `<p>` tags with actual newlines to preserve formatting
          description = description
              .replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n')
              .replaceAll(RegExp(r'</?p>', caseSensitive: false), '\n');
          
          // Convert HTML links to Markdown format [TEXT](URL)
          description = description.replaceAllMapped(
            RegExp(r"""<a\s+[^>]*href=["']([^"']+)["'][^>]*>([\s\S]*?)</a>""", caseSensitive: false),
            (match) {
              var url = match.group(1) ?? '';
              final text = match.group(2) ?? '';
              if (url.startsWith('/')) {
                url = 'https://www.moely.link$url';
              }
              return '[$text]($url)';
            },
          );
          
          description = _decodeHtmlEntities(description);
          // Clean any other remaining HTML tags
          description = description.replaceAll(RegExp('<[^>]*>'), '');
        }
      }
      
      // 6. Extract tags completely in sync with the website tags container
      final List<String> tags = [];
      
      final startTagsDouble = '<div class="tags">';
      final startTagsSingle = '<div class=\'tags\'>';
      final startTagsNoQuote = '<div class=tags>';
      
      int tagsStart = -1;
      int tIdx = html.indexOf(startTagsDouble);
      if (tIdx != -1) {
        tagsStart = tIdx + startTagsDouble.length;
      } else {
        tIdx = html.indexOf(startTagsSingle);
        if (tIdx != -1) {
          tagsStart = tIdx + startTagsSingle.length;
        } else {
          tIdx = html.indexOf(startTagsNoQuote);
          if (tIdx != -1) {
            tagsStart = tIdx + startTagsNoQuote.length;
          }
        }
      }

      if (tagsStart != -1) {
        final tagsEnd = html.indexOf('</div>', tagsStart);
        if (tagsEnd != -1) {
          final tagsContent = html.substring(tagsStart, tagsEnd);
          
          // Match standard links like <a href="...">#Tag</a> and non-clickable spans like <span>#Tag</span> in order (handles quote-less href and captures slug)
          final tagRegex = RegExp(
            r'''<a\s+[^>]*href=["']?/tags/([^"'\s>]+)/?["']?[^>]*>\s*(#?[^<]+)</a>|<span>\s*(#?[^<]+)</span>''',
            caseSensitive: false,
          );
          final matches = tagRegex.allMatches(tagsContent);
          
          for (final match in matches) {
            final slugGroup = match.group(1);
            final aGroup = match.group(2);
            final spanGroup = match.group(3);
            
            if (aGroup != null) {
              final tagText = aGroup.trim();
              if (tagText.isNotEmpty) {
                final formattedTag = tagText.startsWith('#') ? tagText : '#$tagText';
                if (slugGroup != null && slugGroup.isNotEmpty) {
                  tags.add('$formattedTag|slug:$slugGroup');
                } else {
                  tags.add(formattedTag);
                }
              }
            } else if (spanGroup != null) {
              final tagText = spanGroup.trim();
              if (tagText.isNotEmpty) {
                final formattedTag = tagText.startsWith('#') ? tagText : '#$tagText';
                tags.add('$formattedTag|nolink');
              }
            }
          }
        }
      }
      
      // Fallback in case of parsing failures
      if (tags.isEmpty) {
        final tagRegex = RegExp(
          r'''<a\s+[^>]*href=["']?/tags/([^"'\s>]+)/?["']?[^>]*>\s*(#?[^<]+)</a>|<span>\s*(#?[^<]+)</span>''',
          caseSensitive: false,
        );
        final tagMatches = tagRegex.allMatches(html);
        for (final match in tagMatches) {
          final slugGroup = match.group(1);
          final aGroup = match.group(2);
          final spanGroup = match.group(3);
          
          if (aGroup != null) {
            final tagText = aGroup.trim();
            if (tagText.isNotEmpty) {
              final formattedTag = tagText.startsWith('#') ? tagText : '#$tagText';
              if (slugGroup != null && slugGroup.isNotEmpty) {
                tags.add('$formattedTag|slug:$slugGroup');
              } else {
                tags.add(formattedTag);
              }
            }
          } else if (spanGroup != null) {
            final tagText = spanGroup.trim();
            if (tagText.isNotEmpty) {
              final formattedTag = tagText.startsWith('#') ? tagText : '#$tagText';
              tags.add('$formattedTag|nolink');
            }
          }
        }
      }

      // 7. Extract category
      String category = 'Other';
      final categoryRegex = RegExp(r'分类：<a[^>]*>([^<]+)</a>', caseSensitive: false);
      final categoryMatch = categoryRegex.firstMatch(html);
      if (categoryMatch != null) {
        category = categoryMatch.group(1)?.trim() ?? 'Other';
      }

      // 8. Extract user/author (画师), artistUid and hasArtistPage
      String user = 'Unknown';
      String? artistUid;
      bool hasArtistPage = false;

      // 8.1 Only when the artist is wrapped in an anchor tag pointing to /artist/, it has an official artist profile page
      final artistLinkRegex = RegExp(r'''画师：\s*<a\s+[^>]*href=["']?(?:https?://[^/]+)?/artist/([^"'\s>/]+)/?["']?[^>]*>([^<]+)</a>''', caseSensitive: false);
      final artistLinkMatch = artistLinkRegex.firstMatch(html);
      if (artistLinkMatch != null) {
        hasArtistPage = true;
        artistUid = artistLinkMatch.group(1)?.trim();
        user = _decodeHtmlEntities(artistLinkMatch.group(2)?.trim() ?? 'Unknown');
      } else {
        // 8.2 Plain text fallback: artist works are fewer than minArtistCount threshold, so no artist page exists
        hasArtistPage = false;
        final userRegex = RegExp(r'画师：\s*([^<&\n\r]+)', caseSensitive: false);
        final userMatch = userRegex.firstMatch(html);
        if (userMatch != null) {
          user = _decodeHtmlEntities(userMatch.group(1)?.trim() ?? 'Unknown');
        }
      }

      // 8.3 Extract structured wallpaper metadata if present for exact artist UID (keep hasArtistPage accurate)
      try {
        final wpRegex = RegExp(r'''<script\s+id=["']?wallpaper["']?[^>]*>([\s\S]*?)</script>''', caseSensitive: false);
        final wpMatch = wpRegex.firstMatch(html);
        if (wpMatch != null) {
          final jsonStr = wpMatch.group(1)?.trim() ?? '';
          if (jsonStr.isNotEmpty) {
            final wpData = json.decode(jsonStr);
            if (wpData is Map<String, dynamic>) {
              if (wpData['artist'] != null && wpData['artist'].toString().trim().isNotEmpty) {
                artistUid ??= wpData['artist'].toString().trim();
              }
              if (user == 'Unknown' && wpData['user'] != null && wpData['user'].toString().trim().isNotEmpty) {
                user = wpData['user'].toString().trim();
              }
            }
          }
        }
      } catch (_) {}

      final details = ImageDetails(
        id: id,
        title: title,
        resolution: resolution,
        tags: tags,
        sourceUrl: sourceUrl,
        downloadUrl: downloadUrl,
        downloadUrls: downloadUrls,
        previewUrls: previewUrls,
        starUrls: starUrls,
        description: description,
        category: category,
        user: user,
        artistUid: artistUid,
        hasArtistPage: hasArtistPage,
      );

      // Save to offline details cache
      await CacheHelper.saveDetailsToCache(id, details.toJson());

      return details;
    } catch (e) {
      return null;
    }
  }

  /// Decode standard named and numeric HTML character entities
  static String _decodeHtmlEntities(String input) {
    var output = input;
    final entities = {
      '&nbsp;': ' ',
      '&amp;': '&',
      '&lt;': '<',
      '&gt;': '>',
      '&quot;': '"',
      '&#39;': "'",
      '&#039;': "'",
      '&apos;': "'",
      '&mdash;': '—',
      '&ndash;': '–',
      '&hellip;': '…',
      '&mldr;': '…',
      '&middot;': '·',
      '&copy;': '©',
      '&reg;': '®',
      '&trade;': '™',
      '&ldquo;': '“',
      '&rdquo;': '”',
      '&lsquo;': '‘',
      '&rsquo;': '’',
    };
    
    entities.forEach((entity, value) {
      output = output.replaceAll(entity, value);
    });
    
    // Decimal code points
    output = output.replaceAllMapped(RegExp(r'&#(\d+);'), (match) {
      final code = int.parse(match.group(1)!);
      return String.fromCharCode(code);
    });
    // Hexadecimal code points
    output = output.replaceAllMapped(RegExp(r'&#x([0-9a-fA-F]+);'), (match) {
      final code = int.parse(match.group(1)!, radix: 16);
      return String.fromCharCode(code);
    });
    
    return output;
  }
}
