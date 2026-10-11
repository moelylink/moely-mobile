import 'package:flutter/material.dart';
import '../models/image_item.dart';
import '../services/html_parser_service.dart';
import '../widgets/auto_scrolling_text.dart';
import '../widgets/moely_waterfall_view.dart';

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
  final List<MoelyImage> _images = [];
  final List<MoelyImage> _allFetchedImages = [];
  
  late String _currentQuery;
  late TextEditingController _searchController;
  
  bool _isLoadingInitial = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  bool _hasError = false;

  String get _displaySearchTitle {
    final q = _currentQuery.trim();
    if (q.isEmpty) {
      return '搜索美图';
    }
    if (q.startsWith('搜索：') || q.startsWith('搜索:')) {
      return q;
    }
    return '搜索：$q';
  }

  @override
  void initState() {
    super.initState();
    _currentQuery = widget.query;
    _searchController = TextEditingController(text: _currentQuery);
    _fetchInitialImages();
  }

  @override
  void dispose() {
    _searchController.dispose();
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
      if (mounted) {
        setState(() {
          _allFetchedImages.addAll(items);
          final initialBatch = _allFetchedImages.take(20).toList();
          _images.addAll(initialBatch);
          _isLoadingInitial = false;
          if (_allFetchedImages.length <= _images.length) {
            _hasMore = false;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingInitial = false;
          _hasError = true;
        });
      }
    }
  }

  void _fetchMoreImages() {
    if (_isLoadingMore || !_hasMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    Future.delayed(const Duration(milliseconds: 250), () {
      if (!mounted) return;
      final currentLen = _images.length;
      final nextBatch = _allFetchedImages.skip(currentLen).take(20).toList();

      setState(() {
        _images.addAll(nextBatch);
        _isLoadingMore = false;
        if (_images.length >= _allFetchedImages.length) {
          _hasMore = false;
        }
      });
    });
  }

  void _performNewSearch(String query) {
    final cleanQ = query.trim();
    if (cleanQ.isEmpty) return;

    setState(() {
      _currentQuery = cleanQ;
    });
    _fetchInitialImages();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: SizedBox(
          height: 28,
          child: AutoScrollingText(
            text: _displaySearchTitle,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 18,
              color: theme.colorScheme.onSurface,
            ),
            centerWhenNoScroll: true,
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
          // Top Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withOpacity(0.5),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.colorScheme.onSurface.withOpacity(0.08),
                ),
              ),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: _performNewSearch,
                decoration: InputDecoration(
                  hintText: '输入关键词搜索插画...',
                  hintStyle: TextStyle(
                    fontSize: 14,
                    color: theme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: theme.colorScheme.primary,
                  ),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 20),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                        )
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ),

          // Main Waterfall Result View
          Expanded(
            child: MoelyWaterfallView(
              images: _images,
              currentPage: 1,
              totalPages: 1,
              isLoading: _isLoadingInitial,
              isLoadingMore: _isLoadingMore,
              hasError: _hasError,
              onRefresh: _fetchInitialImages,
              onLoadMore: _fetchMoreImages,
              heroPrefix: 'search',
              emptyWidget: const Center(
                child: Text('没有找到相关搜索结果'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
