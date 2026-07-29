import 'dart:io';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/user_agent_service.dart';
import 'my_widgets_screen.dart';

class WidgetImageViewerScreen extends StatelessWidget {
  final String imageUrl;
  final int? widgetId;

  const WidgetImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.widgetId,
  });

  bool get _isLocal => !imageUrl.startsWith('http');

  void _shareImage(BuildContext context) async {
    try {
      if (_isLocal) {
        final file = File(imageUrl);
        if (await file.exists()) {
          await Share.shareXFiles([XFile(imageUrl)], text: '来自萌哩桌面小组件的分享');
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('文件不存在，无法分享')),
            );
          }
        }
      } else {
        // Share link
        await Share.share(imageUrl, subject: '分享图片');
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('分享失败: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Center interactive image viewer
          Positioned.fill(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 4.0,
                child: _isLocal
                    ? Image.file(
                        File(imageUrl),
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white24,
                          size: 64,
                        ),
                      )
                    : CachedNetworkImage(
                        imageUrl: imageUrl,
                        httpHeaders: UserAgentService.headers,
                        fit: BoxFit.contain,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(color: Colors.white70),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image_rounded,
                          color: Colors.white24,
                          size: 64,
                        ),
                      ),
              ),
            ),
          ),

          // Translucent top navigation overlay
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                _buildCircularButton(
                  context,
                  icon: Icons.arrow_back_rounded,
                  onTap: () => Navigator.pop(context),
                ),
                
                // Actions
                Row(
                  children: [
                    // Share/Export button
                    _buildCircularButton(
                      context,
                      icon: Icons.share_rounded,
                      onTap: () => _shareImage(context),
                    ),
                    const SizedBox(width: 12),
                    
                    // Widget settings shortcut
                    if (widgetId != null)
                      _buildCircularButton(
                        context,
                        icon: Icons.settings_rounded,
                        onTap: () {
                          // Close viewer first
                          Navigator.pop(context);
                          // Open widget settings in app
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => MyWidgetsScreen(
                                initialConfigureWidgetId: widgetId,
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.15), width: 0.8),
      ),
      child: ClipOval(
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(
                icon,
                color: Colors.white,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
