import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/image_item.dart';
import '../services/html_parser_service.dart';
import '../services/user_agent_service.dart';
import 'image_detail_screen.dart';

class TagGridScreen extends StatefulWidget {
  final String tag;

  const TagGridScreen({
    super.key,
    required this.tag,
  });

  @override
  State<TagGridScreen> createState() => _TagGridScreenState();
}

class _TagGridScreenState extends State<TagGridScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<MoelyImage> _images = [];
  
  int _currentPage = 1;
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialImages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialImages() async {
    setState(() {
      _isLoadingInitial = true;
      _hasError = false;
      _currentPage = 1;
      _images.clear();
      _hasMore = true;
    });

    try {
      final items = await HtmlParserService.fetchTagImages(widget.tag, _currentPage);
      setState(() {
        _images.addAll(items);
        _isLoadingInitial = false;
        if (items.length < 30) {
          _hasMore = false; // Usually pages have 30 items
        }
      });
    } catch (_) {
      setState(() {
        _isLoadingInitial = false;
        _hasError = true;
      });
    }
  }

  Future<void> _fetchMoreImages() async {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final items = await HtmlParserService.fetchTagImages(widget.tag, nextPage);
      
      setState(() {
        if (items.isEmpty) {
          _hasMore = false;
        } else {
          _images.addAll(items);
          _currentPage = nextPage;
          if (items.length < 30) {
            _hasMore = false;
          }
        }
        _isLoadingMore = false;
      });
    } catch (_) {
      setState(() {
        _isLoadingMore = false;
      });
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final threshold = MediaQuery.of(context).size.height * 0.4;
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - threshold) {
      _fetchMoreImages();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: Text(
          '# ${widget.tag}',
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
            onPressed: _fetchInitialImages,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchInitialImages,
        color: primaryColor,
        child: _buildBody(theme, primaryColor),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, Color primaryColor) {
    if (_isLoadingInitial) {
      return Center(
        child: CircularProgressIndicator(color: primaryColor),
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
                '标签内容加载失败，请检查网络',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchInitialImages,
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
        child: Text('在此标签下未找到任何插画'),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: MasonryGridView.count(
        controller: _scrollController,
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: _images.length + 1,
        padding: const EdgeInsets.only(bottom: 40.0),
        itemBuilder: (context, index) {
          if (index == _images.length) {
            return _buildLoaderTile(primaryColor);
          }
          final image = _images[index];
          return _buildImageCard(theme, image);
        },
      ),
    );
  }

  Widget _buildLoaderTile(Color primaryColor) {
    if (!_hasMore) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            '已加载全部插画 ~',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey,
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      );
    }
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20.0),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: primaryColor,
          ),
        ),
      ),
    );
  }

  Widget _buildImageCard(ThemeData theme, MoelyImage image) {
    final isPixiv = image.category.toLowerCase() == 'pixiv';
    final platformColor = isPixiv 
        ? const Color(0xFF0096FA) // Pixiv Blue
        : const Color(0xFF1DA1F2); // Twitter Sky Blue

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
            AspectRatio(
              aspectRatio: _getAspectRatioForId(image.id),
              child: Hero(
                tag: 'img_${image.id}',
                child: CachedNetworkImage(
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
                          color: platformColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: platformColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Text(
                          image.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: platformColor,
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
                          image.user,
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

  double _getAspectRatioForId(String id) {
    final code = id.hashCode.abs();
    return 0.75 + (code % 58) / 100.0;
  }
}
