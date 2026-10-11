import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/user_agent_service.dart';
import '../utils/toast_helper.dart';
import '../widgets/auto_scrolling_text.dart';
import '../widgets/moely_error_widget.dart';

class DenoisedWebScreen extends StatefulWidget {
  final String url;
  final String? title;

  const DenoisedWebScreen({
    super.key,
    required this.url,
    this.title,
  });

  @override
  State<DenoisedWebScreen> createState() => _DenoisedWebScreenState();
}

class _DenoisedWebScreenState extends State<DenoisedWebScreen> {
  late final WebViewController _controller;
  double _progress = 0.0;
  bool _isLoading = true;
  bool _hasError = false;
  late String _currentTitle;
  String? _currentSubtitle;
  String _currentUrl = '';

  @override
  void initState() {
    super.initState();
    _currentUrl = widget.url;

    // 优先使用传入的自定义初始标题，否则展示加载状态并附带域名提示
    final initialHost = Uri.tryParse(widget.url)?.host;
    if (widget.title != null && widget.title!.trim().isNotEmpty) {
      _currentTitle = widget.title!.trim();
    } else {
      _currentTitle = '正在加载...';
    }
    if (initialHost != null && initialHost.isNotEmpty) {
      _currentSubtitle = initialHost;
    }

    _controller = WebViewController()
      ..setUserAgent(UserAgentService.userAgent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..addJavaScriptChannel(
        'TitleNotifier',
        onMessageReceived: (JavaScriptMessage message) {
          final title = message.message.trim();
          if (title.isNotEmpty && mounted && title != _currentTitle) {
            setState(() {
              _currentTitle = title;
            });
          }
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            final host = Uri.tryParse(url)?.host;
            setState(() {
              _isLoading = true;
              _hasError = false;
              _currentUrl = url;
              if (host != null && host.isNotEmpty) {
                _currentSubtitle = host;
              }
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
              _currentUrl = url;
            });
            _updateTitle();
            _injectCSSAndJS();
          },
          onWebResourceError: (WebResourceError error) {
            if (error.isForMainFrame ?? true) {
              setState(() {
                _isLoading = false;
                _hasError = true;
              });
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.url));
  }

  Future<void> _updateTitle() async {
    try {
      final rawTitle = await _controller.getTitle();
      if (rawTitle != null && rawTitle.trim().isNotEmpty && mounted) {
        final title = rawTitle.trim();
        if (title != _currentTitle) {
          setState(() {
            _currentTitle = title;
          });
        }
      }
    } catch (e) {
      debugPrint('Failed to fetch webview title: $e');
    }
  }

  void _injectCSSAndJS() {
    // 1. 去除网站顶部与底部冗余导航与页脚
    // 2. 上报并监听 document.title 的变动，兼容 SPA 页面动态更新
    _controller.runJavaScript('''
      (function() {
        try {
          var style = document.createElement('style');
          style.innerHTML = `
            header, footer, nav, 
            .navbar, .navbar-brand, .nav-menu, .site-header, .site-footer,
            .top-bar, .bottom-bar, .menu-toggle, #header, #footer,
            .links-section, .about-section, .social-links,
            .search-modal, .search-btn {
              display: none !important;
            }
            body {
              padding-top: 0 !important;
              margin-top: 0 !important;
            }
          `;
          document.head.appendChild(style);
        } catch(e) {}

        // 上报标题
        function notifyTitle() {
          if (document.title && window.TitleNotifier) {
            window.TitleNotifier.postMessage(document.title);
          }
        }
        notifyTitle();

        // 监听 title DOM 变动
        try {
          var titleEl = document.querySelector('title');
          if (titleEl && window.MutationObserver) {
            var observer = new MutationObserver(function() {
              notifyTitle();
            });
            observer.observe(titleEl, { subtree: true, characterData: true, childList: true });
          }
        } catch(e) {}
      })();
    ''');
  }

  Future<void> _handleBack() async {
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _openInExternalBrowser() async {
    final targetUrl = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
    final uri = Uri.tryParse(targetUrl);
    if (uri != null) {
      try {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (err) {
        if (!mounted) return;
        ToastHelper.show(context, '无法使用外部浏览器打开: $err', type: ToastType.error);
      }
    }
  }

  Future<void> _copyCurrentUrl() async {
    final targetUrl = _currentUrl.isNotEmpty ? _currentUrl : widget.url;
    await Clipboard.setData(ClipboardData(text: targetUrl));
    if (!mounted) return;
    ToastHelper.show(context, '链接已复制到剪贴板', type: ToastType.success);
  }

  Future<void> _handleSystemPop(bool didPop) async {
    if (didPop) return;
    if (await _controller.canGoBack()) {
      await _controller.goBack();
    } else {
      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) => _handleSystemPop(didPop),
      child: Scaffold(
        backgroundColor: theme.colorScheme.surface,
        appBar: AppBar(
          title: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 22,
                child: AutoScrollingText(
                  text: _currentTitle,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  centerWhenNoScroll: true,
                ),
              ),
              if (_currentSubtitle != null && _currentSubtitle!.isNotEmpty)
                Text(
                  _currentSubtitle!,
                  style: TextStyle(
                    fontSize: 10,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _handleBack,
            tooltip: '返回',
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              tooltip: '刷新',
              onPressed: () => _controller.reload(),
            ),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert_rounded),
              tooltip: '更多选项',
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              onSelected: (value) {
                switch (value) {
                  case 'copy':
                    _copyCurrentUrl();
                    break;
                  case 'open_browser':
                    _openInExternalBrowser();
                    break;
                  case 'close':
                    Navigator.pop(context);
                    break;
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'copy',
                  child: Row(
                    children: [
                      Icon(Icons.copy_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('复制链接', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'open_browser',
                  child: Row(
                    children: [
                      Icon(Icons.open_in_browser_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('在浏览器中打开', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'close',
                  child: Row(
                    children: [
                      Icon(Icons.close_rounded, size: 18),
                      SizedBox(width: 10),
                      Text('关闭页面', style: TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ],
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
        ),
        body: Stack(
          children: [
            if (!_hasError)
              WebViewWidget(controller: _controller),
              
            // Progress bar
            if (_isLoading && _progress < 1.0)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  value: _progress,
                  color: theme.colorScheme.primary,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  minHeight: 2.5,
                ),
              ),

            if (_hasError)
              MoelyErrorWidget(
                message: '页面加载失败，请检查网络',
                icon: Icons.wifi_off_rounded,
                retryText: '重试',
                onRetry: () {
                  setState(() {
                    _hasError = false;
                    _isLoading = true;
                  });
                  _controller.reload();
                },
              ),
          ],
        ),
      ),
    );
  }
}
