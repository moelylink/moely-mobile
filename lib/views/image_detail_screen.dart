import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/image_item.dart';
import '../models/image_details.dart';
import '../services/image_details_parser.dart';
import '../services/translation_service.dart';
import '../utils/download_helper.dart';
import 'denoised_web_screen.dart';
import '../services/wallpaper_service.dart';
import '../services/settings_service.dart';
import '../services/user_agent_service.dart';
import '../services/url_handler_service.dart';
import 'tag_grid_screen.dart';
import 'category_grid_screen.dart';
import 'package:share_plus/share_plus.dart';

class ImageDetailScreen extends StatefulWidget {
  final MoelyImage image;

  const ImageDetailScreen({
    super.key,
    required this.image,
  });

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> with SingleTickerProviderStateMixin {
  ImageDetails? _details;
  bool _isLoadingDetails = true;
  bool _isFavorited = false;
  
  // Translation state
  bool _isTranslating = false;
  bool _isTranslated = false;
  String _translatedTags = '';
  String _translatedDescription = '';

  // Animation controller for heart scale effect
  late final AnimationController _heartController;
  late final Animation<double> _heartScaleAnimation;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(_heartController);

    _loadDetails();
  }

  String _getDisplayTitle() {
    if (_details != null && _details!.title.isNotEmpty) {
      return _details!.title;
    }
    return 'ID: ${widget.image.id}';
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final details = await ImageDetailsParser.fetchDetails(widget.image.id);
    if (mounted) {
      setState(() {
        _details = details;
        _isLoadingDetails = false;
      });
    }
  }

  String _getHighResUrl(String url) {
    if (url.contains('name=small')) {
      return url.replaceAll('name=small', 'name=large');
    }
    if (url.contains('name=medium')) {
      return url.replaceAll('name=medium', 'name=large');
    }
    return url;
  }

  void _toggleFavorite() {
    setState(() {
      _isFavorited = !_isFavorited;
    });
    _heartController.forward(from: 0.0);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isFavorited ? '已添加收藏' : '已取消收藏'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 150,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Future<void> _handleDownload(int index) async {
    String downloadUrl = '';
    if (_details != null && _details!.downloadUrls.length > index) {
      downloadUrl = _details!.downloadUrls[index];
    } else if (index == 0) {
      downloadUrl = _getHighResUrl(widget.image.urls);
    } else {
      return;
    }

    final extension = downloadUrl.contains('.png') ? 'png' : 'jpg';
    final totalPages = int.tryParse(widget.image.total ?? '') ?? (_details?.downloadUrls.length ?? 1);
    final filename = totalPages > 1
        ? '${widget.image.id}_p$index.$extension'
        : '${widget.image.id}.$extension';

    double progress = 0.0;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('正在下载原图', style: TextStyle(fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  CircularProgressIndicator(value: progress > 0.0 ? progress : null),
                  const SizedBox(height: 16),
                  Text('${(progress * 100).toStringAsFixed(0)}% 下载中...'),
                ],
              ),
            );
          },
        );
      },
    );

    try {
      final savedPath = await DownloadHelper.downloadImage(
        downloadUrl,
        filename,
        onProgress: (received, total) {
          if (total > 0) {
            if (mounted) {
              Navigator.of(context, rootNavigator: true).setState(() {
                progress = received / total;
              });
            }
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.green, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '保存成功！路径: $savedPath',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.surface,
            elevation: 4,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        final theme = Theme.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '下载失败: $e',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            backgroundColor: theme.colorScheme.surface,
            elevation: 4,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: theme.colorScheme.onSurface.withOpacity(0.08),
                width: 1,
              ),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleTranslation() async {
    if (_isTranslated) {
      setState(() {
        _isTranslated = false;
      });
      return;
    }

    if (_details == null) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      // 1. Prepare parallel translation futures
      Future<String> tagsFuture = Future.value('');
      if (_details!.tags.isNotEmpty) {
        final sourceTags = _details!.tags.map((tag) {
          var clean = tag.replaceAll('|nolink', '');
          if (clean.contains('|slug:')) {
            clean = clean.split('|slug:').first;
          }
          return clean;
        }).join(', ');
        tagsFuture = TranslationService.translate(sourceTags).catchError((err) {
          debugPrint('Tags translation failed: $err');
          return '';
        });
      }

      Future<String> descFuture = Future.value('');
      final hasDescription = _details!.description.isNotEmpty && 
          _details!.description != '暂无描述' && 
          _details!.description != '获取描述中...';
      if (hasDescription) {
        descFuture = TranslationService.translate(_details!.description).catchError((err) {
          debugPrint('Description translation failed: $err');
          return '';
        });
      }

      // 2. Wait for both in parallel
      final results = await Future.wait([tagsFuture, descFuture]);
      final translatedTags = results[0];
      final translatedDesc = results[1];

      setState(() {
        _translatedTags = translatedTags;
        _translatedDescription = translatedDesc;
        _isTranslated = true;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('翻译失败，请检查网络后重试')),
        );
      }
    }
  }

  void _showWallpaperOptions(int index) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    '设为原生壁纸 (第 ${index + 1} 张)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWallpaperOptionTile(
                  icon: Icons.wallpaper_rounded,
                  title: '设置为桌面壁纸',
                  onTap: () {
                    Navigator.pop(context);
                    _applyWallpaper(index, 1);
                  },
                  theme: theme,
                ),
                _buildWallpaperOptionTile(
                  icon: Icons.lock_rounded,
                  title: '设置为锁屏壁纸',
                  onTap: () {
                    Navigator.pop(context);
                    _applyWallpaper(index, 2);
                  },
                  theme: theme,
                ),
                _buildWallpaperOptionTile(
                  icon: Icons.phonelink_setup_rounded,
                  title: '同时设置为桌面与锁屏',
                  onTap: () {
                    Navigator.pop(context);
                    _applyWallpaper(index, 3);
                  },
                  theme: theme,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWallpaperOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }

  Future<void> _applyWallpaper(int index, int type) async {
    String downloadUrl = '';
    if (_details != null && _details!.downloadUrls.length > index) {
      downloadUrl = _details!.downloadUrls[index];
    } else if (index == 0) {
      downloadUrl = _getHighResUrl(widget.image.urls);
    } else {
      return;
    }

    final extension = downloadUrl.contains('.png') ? 'png' : 'jpg';
    final totalPages = int.tryParse(widget.image.total ?? '') ?? (_details?.downloadUrls.length ?? 1);
    final filename = totalPages > 1
        ? '${widget.image.id}_p$index.$extension'
        : '${widget.image.id}.$extension';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                '正在下载并应用壁纸...',
                style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
          ],
        ),
      ),
    );

    try {
      final savedPath = await DownloadHelper.downloadImage(
        downloadUrl,
        filename,
        onProgress: (received, total) {},
      );

      final success = await WallpaperService.setWallpaper(savedPath, type);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle_rounded, color: Colors.green),
                  const SizedBox(width: 8),
                  const Expanded(child: Text('壁纸设置成功！')),
                ],
              ),
              backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('设置壁纸失败: $e')),
              ],
            ),
            backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    }
  }

  void _handleShare(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final String shareText = '分享二次元插画 (ID: ${widget.image.id}) By ${widget.image.category} @${widget.image.cleanUser}\n网页链接: https://www.moely.link/img/${widget.image.id}/';
    Share.share(
      shareText,
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  void _openFullscreenViewer(List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPixiv = widget.image.category.toLowerCase() == 'pixiv';
    final platformColor = theme.colorScheme.primary;

    // List of previews to display
    final List<String> previewsToDisplay = [];
    if (_isLoadingDetails || _details == null || _details!.previewUrls.isEmpty) {
      previewsToDisplay.add(_getHighResUrl(widget.image.urls));
    } else {
      previewsToDisplay.addAll(_details!.previewUrls);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          // Dynamic scrolling view containing all illustrations and then metadata at the end (Pixiv-Style)
          Positioned.fill(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 60,
                bottom: 100, // Room for FAB share and bottom spacing
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. List of illustrations stacked vertically (前面展示图片)
                  ...List.generate(previewsToDisplay.length, (index) {
                    final imgUrl = previewsToDisplay[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Stack(
                        children: [
                          // Tap image to trigger immersive zoom view
                          GestureDetector(
                            onTap: () => _openFullscreenViewer(previewsToDisplay, index),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Hero(
                                  tag: index == 0 ? 'img_${widget.image.id}' : 'img_${widget.image.id}_p$index',
                                  child: imgUrl.isEmpty
                                      ? Container(
                                          height: 250,
                                          color: theme.colorScheme.surfaceVariant,
                                          alignment: Alignment.center,
                                          child: CircularProgressIndicator(color: platformColor),
                                        )
                                      : CachedNetworkImage(
                                          imageUrl: imgUrl,
                                          httpHeaders: {'User-Agent': UserAgentService.userAgent},
                                          fit: BoxFit.fitWidth,
                                          placeholder: (context, url) => Container(
                                            height: 250,
                                            color: theme.colorScheme.surfaceVariant,
                                            alignment: Alignment.center,
                                            child: CircularProgressIndicator(color: platformColor),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            height: 250,
                                            color: theme.colorScheme.surfaceVariant,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.broken_image_rounded, size: 48),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          // 2. Action overlay on TOP-RIGHT of EACH image: Frosted Glass download/favorite/wallpaper capsule
                          Positioned(
                            top: 14,
                            right: 14,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  color: Colors.black.withOpacity(0.45),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Favorite Action
                                      GestureDetector(
                                        onTap: _toggleFavorite,
                                        child: ScaleTransition(
                                          scale: _heartScaleAnimation,
                                          child: Icon(
                                            _isFavorited ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                            color: _isFavorited ? Colors.pinkAccent : Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Download Action
                                      GestureDetector(
                                        onTap: () => _handleDownload(index),
                                        child: const Icon(
                                          Icons.download_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Wallpaper Action
                                      GestureDetector(
                                        onTap: () => _showWallpaperOptions(index),
                                        child: const Icon(
                                          Icons.wallpaper_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. Resolution overlay on BOTTOM-RIGHT of EACH image: Frosted Glass resolution badge
                          if (!_isLoadingDetails && _details != null && _details!.resolution.isNotEmpty)
                            Positioned(
                              bottom: 14,
                              right: 14,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    color: Colors.black.withOpacity(0.45),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.aspect_ratio_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _details!.resolution.replaceAll('原图尺寸：', ''),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Multi-image Page indicator text helper if total > 1
                  if (previewsToDisplay.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
                      child: Text(
                        '共 ${previewsToDisplay.length} 张图片，滑动浏览，轻触图片可全屏双击缩放',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 3. Metadata details & descriptions section at the end (最后显示描述，类似Pixiv)
                  _buildPixivDetailsCard(theme, platformColor),
                ],
              ),
            ),
          ),

          // Status bar background shield (so content doesn't bleed into status bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top,
            child: Container(
              color: theme.colorScheme.background,
            ),
          ),

          // 4. Custom Sleek Transparent App Bar Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back Button
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: theme.colorScheme.surface.withOpacity(0.6),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: theme.colorScheme.surface.withOpacity(0.6),
                        child: Text(
                          _getDisplayTitle(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Floating Share Button (右下角显示一个悬浮的分享按钮)
          Positioned(
            right: 20,
            bottom: 24,
            child: FloatingActionButton(
              onPressed: () => _handleShare(context),
              backgroundColor: platformColor,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 6,
              child: const Icon(Icons.share_rounded),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPixivDetailsCard(ThemeData theme, Color platformColor) {
    const Map<String, String> languageNames = {
      'zh-CN': '中文(简体)',
      'zh-TW': '中文(繁体)',
      'en': '英语',
      'ja': '日语',
      'ko': '韩语',
    };

    final targetLangName = languageNames[AppSettings.instance.translationLanguage] ?? '中文';
    final engineName = AppSettings.instance.translationEngine == 'google' ? '谷歌翻译' : '微软翻译';

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ID Title & Source Launch Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _getDisplayTitle(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isLoadingDetails && _details != null && _details!.sourceUrl.isNotEmpty)
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DenoisedWebScreen(
                          url: _details!.sourceUrl,
                          title: '原始出处',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.launch_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: platformColor,
                    backgroundColor: platformColor.withOpacity(0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Creator & Platform badges row
          Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  widget.image.cleanUser,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryGridScreen(
                        categoryCode: widget.image.category.toLowerCase(),
                        title: widget.image.category,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: platformColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: platformColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    widget.image.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: platformColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          // Illustration Description (直接渲染文本，去掉多余卡片)
          Text(
            '作品描述',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingDetails 
              ? Text(
                  '获取描述中...',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                  ),
                )
              : _buildClickableDescription(
                  (_isTranslated && _translatedDescription.isNotEmpty)
                      ? _translatedDescription
                      : _details?.description ?? '暂无描述',
                  theme,
                ),

          // Twitter-Style Minimalist Translation Trigger
          if (!_isLoadingDetails && 
              _details != null && 
              AppSettings.instance.enableTranslation) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _isTranslating
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在翻译...',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: _handleTranslation,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isTranslated ? '显示原文' : '翻译简介和标签为$targetLangName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (_isTranslated) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(由$engineName提供)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],

          const SizedBox(height: 20),

          // Illustration Tags List
          Text(
            '插画标签',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _isLoadingDetails
              ? const Center(child: CircularProgressIndicator())
              : _buildTagsChipCloud(theme),
        ],
      ),
    );
  }

  Widget _buildClickableDescription(String text, ThemeData theme) {
    if (text.isEmpty) return const SizedBox.shrink();

    final List<InlineSpan> spans = [];
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    
    int lastIdx = 0;
    final matches = linkRegex.allMatches(text);
    
    for (final match in matches) {
      // 1. Add plain text before match
      if (match.start > lastIdx) {
        spans.add(TextSpan(
          text: text.substring(lastIdx, match.start),
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: theme.colorScheme.onSurface.withOpacity(0.85),
          ),
        ));
      }
      
      // 2. Add clickable link
      final linkText = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      
      spans.add(TextSpan(
        text: linkText,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            UrlHandlerService.handleUrl(context, url);
          },
      ));
      
      lastIdx = match.end;
    }
    
    // 3. Add remaining text
    if (lastIdx < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIdx),
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: theme.colorScheme.onSurface.withOpacity(0.85),
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildTagsChipCloud(ThemeData theme) {
    if (_details == null || _details!.tags.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TagGridScreen(tag: '暂无标签'),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
            ),
            child: Text(
              '#暂无标签',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final List<String> translatedTagList = _isTranslated && _translatedTags.isNotEmpty
        ? _translatedTags.split(RegExp(r'[,，、]+')).map((s) => s.trim()).toList()
        : [];

    int index = 0;

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _details!.tags.map((tag) {
        final isClickable = !tag.endsWith('|nolink');
        final currentIdx = index++;

        // Determine the display tag text
        String displayTag;
        if (_isTranslated && translatedTagList.length > currentIdx && translatedTagList[currentIdx].isNotEmpty) {
          final translatedText = translatedTagList[currentIdx];
          displayTag = translatedText.startsWith('#') ? translatedText : '#$translatedText';
        } else {
          if (tag.contains('|slug:')) {
            displayTag = tag.split('|slug:').first;
          } else {
            displayTag = tag.replaceAll('|nolink', '');
          }
        }

        final cleanTag = displayTag.replaceAll('#', '');
        
        String targetSlug;
        if (tag.contains('|slug:')) {
          targetSlug = tag.split('|slug:').last;
        } else {
          targetSlug = cleanTag;
        }

        if (isClickable) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TagGridScreen(tag: targetSlug, displayName: cleanTag),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                ),
                child: Text(
                  displayTag,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        } else {
          // Muted non-clickable style
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: Text(
              displayTag,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
      }).toList(),
    );
  }
}


/// Fully Immersive fullscreen swipeable & zoomable view for illustration lists
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pager with zoomable interactive viewer for each image
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      httpHeaders: {'User-Agent': UserAgentService.userAgent},
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white70),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                    ),
                  ),
                );
              },
            ),
          ),

          // Fullscreen Header: Back button & Page Indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ClipOval(
                  child: Container(
                    color: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                if (widget.imageUrls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 48), // spacer balance
              ],
            ),
          ),
        ],
      ),
    );
  }
}
