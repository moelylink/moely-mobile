import 'dart:async';
import 'package:flutter/material.dart';
import '../models/image_item.dart';
import '../services/html_parser_service.dart';
import '../widgets/auto_scrolling_text.dart';
import '../widgets/moely_waterfall_view.dart';

class TagGridScreen extends StatefulWidget {
  final String tag;
  final String? displayName;
  final int initialPage;

  const TagGridScreen({
    super.key,
    required this.tag,
    this.displayName,
    this.initialPage = 1,
  });

  @override
  State<TagGridScreen> createState() => _TagGridScreenState();
}

class _TagGridScreenState extends State<TagGridScreen> {
  final List<MoelyImage> _images = [];
  
  int _currentPage = 1;
  int _totalPages = 1;
  bool _isLoadingInitial = true;
  bool _hasMore = true;
  bool _isLoadingMore = false;
  bool _hasError = false;

  String get _displayTagTitle {
    final rawTag = widget.displayName ?? Uri.decodeComponent(widget.tag);
    final cleanTag = rawTag.startsWith('#') ? rawTag.substring(1).trim() : rawTag.trim();
    if (cleanTag.startsWith('标签：') || cleanTag.startsWith('标签:')) {
      return cleanTag;
    }
    return '标签：$cleanTag';
  }

  Future<void> _fetchNextPage() async {
    if (_isLoadingMore || !_hasMore || _currentPage >= _totalPages) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await HtmlParserService.fetchTagImages(widget.tag, nextPage);
      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _images.addAll(result.images);
          _totalPages = result.totalPages;
          _hasMore = _currentPage < _totalPages;
          _isLoadingMore = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoadingMore = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _currentPage = widget.initialPage;
    _fetchTagImages();
  }

  Future<void> _fetchTagImages() async {
    setState(() {
      _isLoadingInitial = true;
      _hasError = false;
    });

    try {
      final result = await HtmlParserService.fetchTagImages(widget.tag, _currentPage);
      if (mounted) {
        if (result.images.isEmpty) {
          setState(() {
            _isLoadingInitial = false;
            _hasError = true;
          });
          return;
        }

        setState(() {
          _images.clear();
          _images.addAll(result.images);
          _totalPages = result.totalPages;
          _isLoadingInitial = false;
          _hasMore = _currentPage < _totalPages;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: SizedBox(
          height: 28,
          child: AutoScrollingText(
            text: _displayTagTitle,
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
            onPressed: _fetchTagImages,
          ),
        ],
      ),
      body: MoelyWaterfallView(
        images: _images,
        currentPage: _currentPage,
        totalPages: _totalPages,
        isLoading: _isLoadingInitial,
        isLoadingMore: _isLoadingMore,
        hasError: _hasError,
        onRefresh: _fetchTagImages,
        onPageSelected: (page) {
          setState(() {
            _currentPage = page;
          });
          _fetchTagImages();
        },
        onLoadMore: _fetchNextPage,
        heroPrefix: 'tag_${widget.tag}',
      ),
    );
  }
}
