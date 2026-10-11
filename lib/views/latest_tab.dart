import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/image_item.dart';
import '../models/promo_item.dart';
import '../services/html_parser_service.dart';
import '../services/promo_service.dart';
import '../widgets/promo_card.dart';
import '../widgets/moely_image_card.dart';
import '../widgets/moely_waterfall_view.dart';

class LatestTab extends StatefulWidget {
  static final GlobalKey<LatestTabState> latestTabKey = GlobalKey<LatestTabState>();
  static int initialPage = 1;

  LatestTab() : super(key: latestTabKey);

  @override
  State<LatestTab> createState() => LatestTabState();
}

class LatestTabState extends State<LatestTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  List<dynamic> _images = [];
  bool _isLoading = true;
  bool _hasError = false;
  int _currentPage = 1;
  int _totalPages = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  Future<void> _fetchNextPage() async {
    if (_isLoadingMore || !_hasMore || _currentPage >= _totalPages) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final nextPage = _currentPage + 1;
      final result = await HtmlParserService.fetchHomeImages(nextPage);
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

  void jumpToPage(int page) {
    LatestTab.initialPage = page;
    if (mounted) {
      setState(() {
        _currentPage = page;
        _fetchLatestImages();
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _currentPage = LatestTab.initialPage;
    _fetchLatestImages();
  }

  void refresh() {
    _fetchLatestImages();
  }

  Future<void> _fetchLatestImages() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final result = await HtmlParserService.fetchHomeImages(_currentPage);
      
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
          _images = items;
          _totalPages = result.totalPages;
          _isLoading = false;
          _hasMore = _currentPage < _totalPages;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      appBar: AppBar(
        title: Text(
          '最新速递',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary),
            onPressed: _fetchLatestImages,
          ),
        ],
      ),
      body: MoelyWaterfallView(
        isRootTab: true,
        itemCount: _images.length,
        itemBuilder: (context, index) {
          final item = _images[index];
          if (item is PromoItem) {
            return PromoCard(promo: item);
          } else if (item is MoelyImage) {
            return MoelyImageCard(image: item, heroPrefix: 'latest');
          }
          return const SizedBox.shrink();
        },
        currentPage: _currentPage,
        totalPages: _totalPages,
        isLoading: _isLoading,
        isLoadingMore: _isLoadingMore,
        hasError: _hasError,
        onRefresh: _fetchLatestImages,
        onPageSelected: (page) {
          setState(() {
            _currentPage = page;
          });
          _fetchLatestImages();
        },
        onLoadMore: _fetchNextPage,
      ),
    );
  }
}
