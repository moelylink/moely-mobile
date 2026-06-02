import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

class TurnstileVerifierDialog extends StatefulWidget {
  const TurnstileVerifierDialog({super.key});

  /// Static helper to show the verifier dialog and return the solved Turnstile token.
  static Future<String?> show(BuildContext context) async {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (context) => const TurnstileVerifierDialog(),
    );
  }

  @override
  State<TurnstileVerifierDialog> createState() => _TurnstileVerifierDialogState();
}

class _TurnstileVerifierDialogState extends State<TurnstileVerifierDialog> {
  late final WebViewController _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("Mozilla/5.0 (Linux; Android 10; K) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Mobile Safari/537.36")
      ..setBackgroundColor(Colors.transparent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (url) {
            if (mounted) {
              setState(() {
                _isLoading = false;
              });
            }
          },
          onWebResourceError: (error) {
            debugPrint("WebView Turnstile Resource Error: ${error.description}");
            if (mounted) {
              setState(() {
                _errorMessage = "验证组件加载失败，请检查网络";
                _isLoading = false;
              });
            }
          },
        ),
      )
      ..addJavaScriptChannel(
        'TurnstileChannel',
        onMessageReceived: (JavaScriptMessage message) {
          final result = message.message;
          debugPrint("Turnstile Native Bridge received: $result");
          if (result == 'error' || result == 'expired') {
            Navigator.of(context).pop(null);
          } else {
            // Return solved Turnstile Captcha token to caller
            Navigator.of(context).pop(result);
          }
        },
      )
      ..loadRequest(Uri.parse('https://user.moely.link/captcha/'));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Container(
      height: 230, // Fixed compact height for perfect Turnstile framing
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(32),
          topRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Slide Bar / Drag Handle
            const SizedBox(height: 12),
            Container(
              width: 48,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.4),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            // Header Title
            Text(
              "安全校验",
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              "为保障您的账户安全，请进行人机验证",
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 16),

            // Content Area (WebView or Loading Spinner)
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.error_outline_rounded, size: 48, color: theme.colorScheme.error),
                          const SizedBox(height: 12),
                          Text(
                            _errorMessage!,
                            style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 16),
                          FilledButton.tonal(
                            onPressed: () {
                              setState(() {
                                _errorMessage = null;
                                _isLoading = true;
                              });
                              _webViewController.reload();
                            },
                            child: const Text("重试"),
                          ),
                        ],
                      ),
                    )
                  else
                    WebViewWidget(controller: _webViewController),
                  
                  if (_isLoading && _errorMessage == null)
                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CircularProgressIndicator(
                          strokeWidth: 3,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "安全环境加载中...",
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
