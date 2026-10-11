import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/image_item.dart';
import '../models/promo_item.dart';
import '../services/html_parser_service.dart';
import '../services/promo_service.dart';
import '../widgets/auto_scrolling_text.dart';
import '../widgets/promo_card.dart';
import '../widgets/moely_image_card.dart';
import '../widgets/moely_waterfall_view.dart';

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
  bool _isLoadingMore = false;
  bool _hasError = false;

  String get _displayCategoryTitle {
    final title = widget.title.trim();
    if (title.startsWith('分类：') || title.startsWith('分类:')) {
      return title;
    }
    final code = widget.categoryCode.trim().toLowerCase();
    if (code == 'pixiv' || title.toLowerCase().contains('pixiv')) {
      return '分类：Pixiv';
    }
    if (code == 'twitter' || title.toLowerCase().contains('twitter')) {
      return '分类：Twitter';
    }
    return '分类：$title';
  }

  Future<void> _fetchNextPage() async {
    if (_isLoadingMore || !_hasMore || _currentPage >= _totalPages) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await HtmlParserService.fetchCategoryImages(widget.categoryCode, nextPage);
      await PromoService.instance.fetchPromos();
      final items = List<dynamic>.from(result.images);
      if (items.isNotEmpty) {
        final promo = PromoService.instance.getRandomPromo();
        if (promo != null) {
          final insertIdx = math.Random().nextInt(items.length + 1);
          items.insert(insertIdx, promo);
        }
      }

      if (mounted) {
        setState(() {
          _currentPage = nextPage;
          _images.addAll(items);
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
    _fetchCategoryImages();
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
          _images.addAll(items);
          _totalPages = result.totalPages;
          _isLoadingInitial = false;
          _hasMore = _currentPage < _totalPages;
        });
      }
    } catch (e) {
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
            text: _displayCategoryTitle,
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
            onPressed: _fetchCategoryImages,
          ),
        ],
      ),
      body: MoelyWaterfallView(
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final item = _images[index];
          if (item is PromoItem) {
            return PromoCard(promo: item);
          } else if (item is MoelyImage) {
            return MoelyImageCard(image: item, heroPrefix: 'category_${widget.categoryCode}');
          }
          return const SizedBox.shrink();
        },
        currentPage: _currentPage,
        totalPages: _totalPages,
        isLoading: _isLoadingInitial,
        isLoadingMore: _isLoadingMore,
        hasError: _hasError,
        onRefresh: _fetchCategoryImages,
        onPageSelected: (page) {
          setState(() {
            _currentPage = page;
          });
          _fetchCategoryImages();
        },
        onLoadMore: _fetchNextPage,
      ),
    );
  }
}
