import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../services/user_agent_service.dart';

class DenoisedWebScreen extends StatefulWidget {
  final String url;
  final String title;

  const DenoisedWebScreen({
    super.key,
    required this.url,
    required this.title,
  });

  @override
  State<DenoisedWebScreen> createState() => _DenoisedWebScreenState();
}

class _DenoisedWebScreenState extends State<DenoisedWebScreen> {
  late final WebViewController _controller;
  double _progress = 0.0;
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setUserAgent(UserAgentService.userAgent)
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100.0;
            });
          },
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
              _hasError = false;
            });
          },
          onPageFinished: (String url) {
            setState(() {
              _isLoading = false;
            });
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

  void _injectCSSAndJS() {
    // Aggressive css Injection to remove all website headers and footers
    _controller.runJavaScript('''
      (function() {
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
      })();
    ''');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          widget.title,
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onBackground,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => _controller.reload(),
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
                backgroundColor: theme.colorScheme.surfaceVariant,
                minHeight: 3.0,
              ),
            ),

          if (_hasError)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.wifi_off_rounded,
                      size: 64,
                      color: theme.colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      '页面加载失败，请检查网络',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      onPressed: () => _controller.reload(),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('重试'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primaryContainer,
                        foregroundColor: theme.colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
