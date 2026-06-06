import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/image_item.dart';
import '../models/promo_item.dart';
import '../services/html_parser_service.dart';
import '../services/user_agent_service.dart';
import '../services/promo_service.dart';
import 'image_detail_screen.dart';
import '../utils/toast_helper.dart';
import '../services/url_handler_service.dart';
import '../widgets/smooth_aspect_ratio_image.dart';
import '../widgets/promo_card.dart';

class CategoryGridScreen extends StatefulWidget {
  final String categoryCode; // 'pixiv' or 'twitter'
  final String title;
  final int initialPage;

  const CategoryGridScreen({
    super.key,
    required this.categoryCode,
    required this.title,
    this.initialPage = 1,
  });

  @override
  State<CategoryGridScreen> createState() => _CategoryGridScreenState();
}

class _CategoryGridScreenState extends State<CategoryGridScreen> {
  final List<dynamic> _images = [];
  
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingInitial = true;
  bool _hasMore = true;
  bool _hasError = false;
  final ValueNotifier<bool> _isPaginationVisible = ValueNotifier<bool>(true);
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _fetchCategoryImages();
  }

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _isPaginationVisible.dispose();
    super.dispose();
  }

  void _onScrollStarted() {
    _scrollTimer?.cancel();
    if (_isPaginationVisible.value) {
      _isPaginationVisible.value = false;
    }
  }

  void _onScrollEnded() {
    _scrollTimer?.cancel();
    _scrollTimer = Timer(const Duration(seconds: 1), () {
      if (mounted) {
        _isPaginationVisible.value = true;
      }
    });
  }

  Future<void> _fetchCategoryImages() async {
    setState(() {
      _isLoadingInitial = true;
      _hasError = false;
    });

    try {
      final result = await HtmlParserService.fetchCategoryImages(widget.categoryCode, _currentPage);
      
      await PromoService.instance.fetchPromos();
      final items = List<dynamic>.from(result.images);
      if (items.isNotEmpty) {
        final promo = PromoService.instance.getRandomPromo();
        if (promo != null) {
          final insertIdx = math.Random().nextInt(items.length + 1);
          items.insert(insertIdx, promo);
        }
      }

      setState(() {
        _images.clear();
        _images.addAll(items);
        _totalPages = result.totalPages;
        _isLoadingInitial = false;
        _hasMore = _currentPage < _totalPages;
      });
    } catch (_) {
      setState(() {
        _isLoadingInitial = false;
        _hasError = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;

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
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchCategoryImages,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCategoryImages,
        color: brandColor,
        child: _buildBody(theme, brandColor),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, Color brandColor) {
    if (_isLoadingInitial) {
      return Center(
        child: CircularProgressIndicator(color: brandColor),
      );
    }

    if (_hasError) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded,
                size: 64,
                color: theme.colorScheme.error,
              ),
              const SizedBox(height: 16),
              Text(
                '数据加载失败，请检查网络',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchCategoryImages,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新加载'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primaryContainer,
                  foregroundColor: theme.colorScheme.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_images.isEmpty) {
      return const Center(
        child: Text('在此分类下未找到插画'),
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              if (scrollNotification is ScrollStartNotification) {
                _onScrollStarted();
              } else if (scrollNotification is ScrollUpdateNotification) {
                if (_isPaginationVisible.value) {
                  _onScrollStarted();
                }
              } else if (scrollNotification is ScrollEndNotification) {
                _onScrollEnded();
              }
              return false;
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0),
              child: MasonryGridView.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                itemCount: _images.length,
                padding: const EdgeInsets.only(top: 8.0, bottom: 100.0),
                itemBuilder: (context, index) {
                  final item = _images[index];
                  if (item is PromoItem) {
                    return PromoCard(promo: item);
                  } else if (item is MoelyImage) {
                    return _buildImageCard(theme, item, brandColor);
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: ValueListenableBuilder<bool>(
            valueListenable: _isPaginationVisible,
            builder: (context, visible, child) {
              return IgnorePointer(
                ignoring: !visible,
                child: AnimatedOpacity(
                  opacity: visible ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: AnimatedSlide(
                    offset: visible ? Offset.zero : const Offset(0.0, 1.5),
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: _buildPaginationBar(theme),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPaginationBar(ThemeData theme) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 24), // Safe bottom padding since there's no floating bottom bar here
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface.withOpacity(0.85),
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.08),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton.filledTonal(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                      _fetchCategoryImages();
                    });
                  }
                : null,
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 16),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
          ),
          InkWell(
            onTap: () => _showPageJumpDialog(context, theme),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '第 $_currentPage / $_totalPages 页',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.edit_rounded,
                    size: 14,
                    color: theme.colorScheme.primary.withOpacity(0.8),
                  ),
                ],
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: _hasMore
                ? () {
                    setState(() {
                      _currentPage++;
                      _fetchCategoryImages();
                    });
                  }
                : null,
            icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16),
            style: IconButton.styleFrom(
              padding: const EdgeInsets.all(12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16.0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showPageJumpDialog(BuildContext context, ThemeData theme) {
    final controller = TextEditingController(text: _currentPage.toString());
    String? errorMessage;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24.0)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: Text(
            '跳转到指定页',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '可输入范围：1 ~ $_totalPages',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withOpacity(0.04),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: errorMessage != null
                          ? Colors.redAccent
                          : theme.colorScheme.primary.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: errorMessage != null ? Colors.redAccent : theme.colorScheme.primary,
                    ),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                if (errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMessage!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ],
            ),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actionsPadding: const EdgeInsets.only(bottom: 20, left: 16, right: 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                '取消',
                style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6)),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text);
                if (val != null && val >= 1 && val <= _totalPages) {
                  Navigator.pop(context);
                  setState(() {
                    _currentPage = val;
                    _fetchCategoryImages();
                  });
                } else {
                  setDialogState(() {
                    errorMessage = '页码范围错误，请输入 1 ~ $_totalPages';
                  });
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: theme.colorScheme.onPrimary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text('确认', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageCard(ThemeData theme, MoelyImage image, Color brandColor) {
    return Card(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.0),
      ),
      elevation: 3,
      shadowColor: theme.colorScheme.shadow.withOpacity(0.1),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ImageDetailScreen(image: image),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            Hero(
              tag: 'img_${image.id}',
              child: SmoothAspectRatioImage(
                imageUrl: image.urls,
                httpHeaders: {'User-Agent': UserAgentService.userAgent},
                builder: (context, isLoading) => CachedNetworkImage(
                  imageUrl: image.urls,
                  httpHeaders: {'User-Agent': UserAgentService.userAgent},
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    color: theme.colorScheme.surfaceVariant,
                    child: const Center(
                      child: Icon(Icons.broken_image_rounded),
                    ),
                  ),
                ),
              ),
            ),
            
            // Metadata Section
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row for Category Badge & Multi-image Badge
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: brandColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: brandColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          image.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: brandColor,
                          ),
                        ),
                      ),
                      if (image.total != null && image.total != '1')
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.collections_rounded,
                              size: 12,
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              image.total!,
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  
                  // Image ID
                  Text(
                    'ID: ${image.id}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  
                  // Author Name
                  Row(
                    children: [
                      Icon(
                        Icons.alternate_email_rounded,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          image.cleanUser,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
