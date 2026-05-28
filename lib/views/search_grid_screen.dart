import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/image_item.dart';
import '../services/html_parser_service.dart';
import '../services/user_agent_service.dart';
import 'image_detail_screen.dart';

class SearchGridScreen extends StatefulWidget {
  final String query;

  const SearchGridScreen({
    super.key,
    required this.query,
  });

  @override
  State<SearchGridScreen> createState() => _SearchGridScreenState();
}

class _SearchGridScreenState extends State<SearchGridScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<MoelyImage> _images = [];
  final List<MoelyImage> _allFetchedImages = [];
  
  late String _currentQuery;
  late TextEditingController _searchController;
  
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
    _searchController = TextEditingController(text: _currentQuery);
    _fetchInitialImages();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _fetchInitialImages() async {
    setState(() {
      _isLoadingInitial = true;
      _hasError = false;
      _images.clear();
      _allFetchedImages.clear();
      _hasMore = true;
    });

    try {
      final items = await HtmlParserService.fetchSearchImages(_currentQuery, 1, limit: 100);
      setState(() {
        _allFetchedImages.addAll(items);
        final initialBatch = _allFetchedImages.take(20).toList();
        _images.addAll(initialBatch);
        _isLoadingInitial = false;
        if (_allFetchedImages.length <= _images.length) {
          _hasMore = false;
        }
      });
    } catch (_) {
      setState(() {
        _isLoadingInitial = false;
        _hasError = true;
      });
    }
  }

  void _fetchMoreImages() {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      setState(() {
        final currentLen = _images.length;
        final nextBatch = _allFetchedImages.skip(currentLen).take(20).toList();
        _images.addAll(nextBatch);
        _isLoadingMore = false;
        if (_allFetchedImages.length <= _images.length) {
          _hasMore = false;
        }
      });
    });
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
        title: const Text(
          '搜索美图',
          style: TextStyle(
            fontWeight: FontWeight.bold,
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
      body: Column(
        children: [
          // Sticky top search bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16.0, 4.0, 16.0, 12.0),
            child: Container(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(20.0),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.shadow.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextField(
                controller: _searchController,
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    setState(() {
                      _currentQuery = val.trim();
                    });
                    _fetchInitialImages();
                  }
                },
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: '搜索插画、画师、标签...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            setState(() {
                              _searchController.clear();
                            });
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20.0,
                    vertical: 14.0,
                  ),
                ),
                onChanged: (val) {
                  setState(() {});
                },
              ),
            ),
          ),
          // Scrollable grid
          Expanded(
            child: RefreshIndicator(
              onRefresh: _fetchInitialImages,
              color: primaryColor,
              child: _buildBody(theme, primaryColor),
            ),
          ),
        ],
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
                '搜索出错，请检查网络',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: _fetchInitialImages,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('重新尝试'),
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
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.search_off_rounded,
                size: 64,
                color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                '未找到与 "$_currentQuery" 相关的插画',
                style: TextStyle(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
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
      final isLimitReached = _allFetchedImages.length >= 100;
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Text(
            isLimitReached ? '只展示前100条结果' : '已加载全部搜索结果 ~',
            style: const TextStyle(
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
    final platformColor = theme.colorScheme.primary;

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
              child: CachedNetworkImage(
                imageUrl: image.urls,
                httpHeaders: {'User-Agent': UserAgentService.userAgent},
                fit: BoxFit.fitWidth,
                placeholder: (context, url) => Container(
                  height: 200,
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
                  height: 200,
                  color: theme.colorScheme.surfaceVariant,
                  child: const Center(
                    child: Icon(Icons.broken_image_rounded),
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
                  
                  // Image ID
                  Row(
                    children: [
                      Icon(
                        Icons.tag_rounded,
                        size: 12,
                        color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'ID: ${image.id}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurfaceVariant.withOpacity(0.8),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
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
