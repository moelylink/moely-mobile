import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:app_links/app_links.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/image_item.dart';
import '../views/image_detail_screen.dart';
import '../views/category_grid_screen.dart';
import '../views/tag_grid_screen.dart';
import '../views/search_grid_screen.dart';
import '../views/denoised_web_screen.dart';
import '../views/home_screen.dart';
import '../views/latest_tab.dart';
import 'settings_service.dart';
import '../utils/toast_helper.dart';

class UrlHandlerService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final AppLinks _appLinks = AppLinks();

  /// Initialize system-wide AppLinks listeners for deep linking.
  static void initialize() {
    // 1. Handle cold start deep links (launching app via a link)
    _appLinks.getInitialLink().then((uri) {
      if (uri != null) {
        debugPrint('Cold start AppLink received: $uri');
        // Give a delay to ensure the navigator is mounted and ready
        Future.delayed(const Duration(milliseconds: 800), () {
          handleUrl(null, uri.toString());
        });
      }
    });

    // 2. Handle warm start deep links (app already running/in background)
    _appLinks.uriLinkStream.listen((uri) {
      debugPrint('Warm start AppLink received: $uri');
      // Give a small delay to ensure rendering context is stable
      Future.delayed(const Duration(milliseconds: 100), () {
        handleUrl(null, uri.toString());
      });
    }, onError: (err) {
      debugPrint('AppLink stream error: $err');
    });
  }

  static void _launchExternalLink(BuildContext context, String url) {
    if (AppSettings.instance.browseInApp) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => DenoisedWebScreen(
            url: url,
            title: '外部链接',
          ),
        ),
      );
    } else {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        launchUrl(uri, mode: LaunchMode.externalApplication).catchError((err) {
          debugPrint('Failed to launch external URL: $err');
          ToastHelper.show(context, '打开外部链接失败: $err', type: ToastType.error);
          return false;
        });
      }
    }
  }

  /// Handle and route Moely URLs inside the app.
  /// Returns `true` if the URL was handled inside the app, `false` otherwise.
  static bool handleUrl(BuildContext? context, String url) {
    if (url.isEmpty) return false;

    // 1. Intercept Deep Link Auth Callbacks before any normalization
    if (url.startsWith('moely://auth-callback')) {
      debugPrint("Intercepted Authentication Callback Deep Link: $url");
      final navContext = context ?? navigatorKey.currentContext;

      // Extract access_token and refresh_token from the callback hash/fragment
      try {
        final normalizedLink = url.replaceFirst('#', '?');
        final uri = Uri.parse(normalizedLink);
        final accessToken = uri.queryParameters['access_token'];
        final refreshToken = uri.queryParameters['refresh_token'];
        
        if (accessToken != null && refreshToken != null) {
          debugPrint("Recovering session with accessToken and refreshToken from Web Login Page");
          Supabase.instance.client.auth.setSession(
            refreshToken,
            accessToken: accessToken,
          ).then((response) {
            debugPrint("Session successfully recovered: ${response.session?.user.email}");
          }).catchError((e) {
            debugPrint("Error recovering session: $e");
          });
        }
      } catch (e) {
        debugPrint("Error recovering session from deep link: $e");
      }

      if (navContext != null) {
        Navigator.popUntil(navContext, (route) => route.isFirst);
        ToastHelper.show(navContext, '🎉 登录成功，欢迎来到萌哩！', type: ToastType.success);
      }
      return true;
    }

    // Normalize moely:// or relative urls
    String normalizedUrl = url.trim();
    if (normalizedUrl.startsWith('moely://')) {
      normalizedUrl = normalizedUrl.replaceFirst('moely://', 'https://www.moely.link/');
    } else if (normalizedUrl.startsWith('/')) {
      normalizedUrl = 'https://www.moely.link$normalizedUrl';
    }

    // Parse Uri safely
    final uri = Uri.tryParse(normalizedUrl);
    if (uri == null) return false;

    final host = uri.host.toLowerCase();

    // If it's a website jump redirect, decode the target URL first!
    if (host == 'www.moely.link' || host == 'moely.link') {
      final path = uri.path;
      if (path.contains('/go/') || path.contains('/jump/')) {
        var target = uri.queryParameters['target'];
        if (target != null && target.isNotEmpty) {
          try {
            var base64Str = Uri.decodeComponent(target);
            while (base64Str.length % 4 != 0) {
              base64Str += '=';
            }
            final decodedBytes = base64.decode(base64Str);
            final decodedUrl = utf8.decode(decodedBytes);
            if (decodedUrl.isNotEmpty) {
              return handleUrl(context, decodedUrl);
            }
          } catch (_) {
            return handleUrl(context, target);
          }
        }
      }
    }

    // If it is NOT a moely link, treat as an external URL.
    final isMoelyHost = host == 'www.moely.link' || host == 'moely.link' || host.isEmpty;
    if (!isMoelyHost) {
      final navContext = context ?? navigatorKey.currentContext;
      if (navContext != null) {
        if (AppSettings.instance.showJumpConfirmation) {
          showDialog(
            context: navContext,
            builder: (dialogContext) {
              final theme = Theme.of(dialogContext);
              return AlertDialog(
                backgroundColor: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                title: Row(
                  children: [
                    Icon(Icons.open_in_new_rounded, color: theme.colorScheme.primary),
                    const SizedBox(width: 12),
                    const Text('提示', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
                content: SizedBox(
                  width: MediaQuery.of(dialogContext).size.width * 0.85,
                  child: Text(
                    '您即将离开目前页面，前往外部网址：\n\n$normalizedUrl',
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(dialogContext);
                      _launchExternalLink(navContext, normalizedUrl);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: theme.colorScheme.primary,
                      foregroundColor: theme.colorScheme.onPrimary,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('确认前往', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              );
            },
          );
        } else {
          _launchExternalLink(navContext, normalizedUrl);
        }
        return true;
      }
      return false;
    }

    // Process moely.link URLs
    final path = uri.path;
    final queryParams = uri.queryParameters;

    final navContext = context ?? navigatorKey.currentContext;
    if (navContext == null) return false;

    // 1. Search Query: ?s=query
    if (queryParams.containsKey('s')) {
      final query = queryParams['s'];
      if (query != null && query.isNotEmpty) {
        Navigator.push(
          navContext,
          MaterialPageRoute(
            builder: (context) => SearchGridScreen(query: query),
          ),
        );
        return true;
      }
    }

    // 2. Image Detail: /img/<id>/ or /img/<id>
    final imgMatch = RegExp(r'^/img/(\d+)').firstMatch(path);
    if (imgMatch != null) {
      final id = imgMatch.group(1)!;
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (context) => ImageDetailScreen(
            image: MoelyImage(
              id: id,
              user: 'Loading...',
              category: 'Other',
              urls: '',
            ),
          ),
        ),
      );
      return true;
    }

    // 3. Random page: /random/ or /random
    if (path == '/random/' || path == '/random') {
      Navigator.popUntil(navContext, (route) => route.isFirst);
      HomeScreen.homeKey.currentState?.switchTab(2); // Switch to Random Tab
      return true;
    }

    // 4. Tag page: /tags/<tag_name>/(page/<num>/)?
    final tagMatch = RegExp(r'^/tags/([^/]+)').firstMatch(path);
    if (tagMatch != null) {
      final tagName = Uri.decodeComponent(tagMatch.group(1)!);
      
      // Parse optional page number
      int pageNum = 1;
      final pageInPathMatch = RegExp(r'/page/(\d+)').firstMatch(path);
      if (pageInPathMatch != null) {
        pageNum = int.tryParse(pageInPathMatch.group(1) ?? '1') ?? 1;
      }

      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (context) => TagGridScreen(
            tag: tagName,
            initialPage: pageNum,
          ),
        ),
      );
      return true;
    }

    // 5. Category page: /category/<category_code>/(page/<num>/)?
    final categoryMatch = RegExp(r'^/category/([^/]+)').firstMatch(path);
    if (categoryMatch != null) {
      final categoryCode = categoryMatch.group(1)!.toLowerCase();
      
      // Parse optional page number
      int pageNum = 1;
      final pageInPathMatch = RegExp(r'/page/(\d+)').firstMatch(path);
      if (pageInPathMatch != null) {
        pageNum = int.tryParse(pageInPathMatch.group(1) ?? '1') ?? 1;
      }

      String title = categoryCode;
      if (categoryCode == 'pixiv') {
        title = 'Pixiv 插画';
      } else if (categoryCode == 'twitter') {
        title = 'Twitter 插画';
      } else {
        title = '${categoryCode[0].toUpperCase()}${categoryCode.substring(1)}';
      }
      Navigator.push(
        navContext,
        MaterialPageRoute(
          builder: (context) => CategoryGridScreen(
            categoryCode: categoryCode,
            title: title,
            initialPage: pageNum,
          ),
        ),
      );
      return true;
    }

    // 6. Latest / Homepage: / or /page/<num>/
    if (path == '/' || path == '') {
      Navigator.popUntil(navContext, (route) => route.isFirst);
      HomeScreen.homeKey.currentState?.switchTab(0); // Switch to Latest Tab
      LatestTab.initialPage = 1;
      LatestTab.latestTabKey.currentState?.jumpToPage(1);
      return true;
    }

    final pageMatch = RegExp(r'^/page/(\d+)').firstMatch(path);
    if (pageMatch != null) {
      final pageNum = int.tryParse(pageMatch.group(1) ?? '1') ?? 1;
      Navigator.popUntil(navContext, (route) => route.isFirst);
      HomeScreen.homeKey.currentState?.switchTab(0); // Switch to Latest Tab
      LatestTab.initialPage = pageNum;
      LatestTab.latestTabKey.currentState?.jumpToPage(pageNum);
      return true;
    }

    return false;
  }
}
