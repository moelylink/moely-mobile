import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import '../models/image_item.dart';
import '../services/settings_service.dart';
import 'floating_pagination_pill.dart';
import 'moely_image_card.dart';

import 'moely_error_widget.dart';

class MoelyWaterfallView extends StatefulWidget {
  final List<MoelyImage> images;
  final int currentPage;
  final int totalPages;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasError;
  final Future<void> Function()? onRefresh;
  final Function(int page)? onPageSelected;
  final VoidCallback? onLoadMore;
  final List<Widget>? headerSlivers;
  final String? heroPrefix;
  final EdgeInsetsGeometry? padding;
  final Widget? emptyWidget;
  final Widget Function(BuildContext context, int index)? itemBuilder;
  final int? itemCount;
  final double? bottomOffset;
  final bool isRootTab;

  const MoelyWaterfallView({
    super.key,
    this.images = const [],
    required this.currentPage,
    required this.totalPages,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasError = false,
    this.onRefresh,
    this.onPageSelected,
    this.onLoadMore,
    this.headerSlivers,
    this.heroPrefix,
    this.padding,
    this.emptyWidget,
    this.itemBuilder,
    this.itemCount,
    this.bottomOffset,
    this.isRootTab = false,
  });

  @override
  State<MoelyWaterfallView> createState() => _MoelyWaterfallViewState();
}

class _MoelyWaterfallViewState extends State<MoelyWaterfallView> {
  final ValueNotifier<bool> _isPaginationVisible = ValueNotifier<bool>(true);
  Timer? _scrollTimer;

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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final brandColor = theme.colorScheme.primary;
    final totalCount = widget.itemCount ?? widget.images.length;

    final effectiveBottomOffset = widget.bottomOffset ?? (widget.isRootTab ? 104.0 : 24.0);
    final effectivePadding = widget.padding ?? EdgeInsets.fromLTRB(16, 0, 16, widget.isRootTab ? 160.0 : 90.0);

    if (widget.isLoading && totalCount == 0) {
      return Center(
        child: CircularProgressIndicator(color: brandColor),
      );
    }

    if (widget.hasError && totalCount == 0) {
      if (widget.headerSlivers != null && widget.headerSlivers!.isNotEmpty) {
        return CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            ...widget.headerSlivers!,
            SliverFillRemaining(
              hasScrollBody: false,
              child: MoelyErrorWidget(
                message: '数据加载失败，请检查网络',
                onRetry: widget.onRefresh,
              ),
            ),
          ],
        );
      }
      return MoelyErrorWidget(
        message: '数据加载失败，请检查网络',
        onRetry: widget.onRefresh,
      );
    }

    Widget content = NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        final bool isAtBottom = metrics.maxScrollExtent > 0 && metrics.pixels >= metrics.maxScrollExtent - 1.0;

        if (isAtBottom) {
          _scrollTimer?.cancel();
          if (!_isPaginationVisible.value) {
            _isPaginationVisible.value = true;
          }
        } else if (notification is ScrollStartNotification) {
          _onScrollStarted();
        } else if (notification is ScrollEndNotification) {
          _onScrollEnded();
        } else if (notification is ScrollUpdateNotification) {
          if (_isPaginationVisible.value) {
            _onScrollStarted();
          }
        }

        if (notification is ScrollUpdateNotification) {
          if (AppSettings.instance.enableInfiniteScroll) {
            if (metrics.pixels >= metrics.maxScrollExtent - 400) {
              if (widget.onLoadMore != null) {
                widget.onLoadMore!();
              }
            }
          }
        }
        return false;
      },
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // 1. Header Slivers (if any)
          if (widget.headerSlivers != null) ...widget.headerSlivers!,

          // 2. Main Waterfall Grid
          if (totalCount == 0)
            SliverFillRemaining(
              child: widget.emptyWidget ??
                  const Center(
                    child: Text('暂无插画作品'),
                  ),
            )
          else
            SliverPadding(
              padding: effectivePadding,
              sliver: SliverMasonryGrid.count(
                crossAxisCount: 2,
                mainAxisSpacing: 12.0,
                crossAxisSpacing: 12.0,
                itemBuilder: (context, index) {
                  if (widget.itemBuilder != null) {
                    return widget.itemBuilder!(context, index);
                  }
                  final image = widget.images[index];
                  return MoelyImageCard(
                    image: image,
                    heroPrefix: widget.heroPrefix,
                  );
                },
                childCount: totalCount,
              ),
            ),

          // 3. Infinite Loading Footer Indicator
          if (widget.isLoadingMore)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 90),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: brandColor,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );

    if (widget.onRefresh != null) {
      content = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        color: brandColor,
        child: content,
      );
    }

    return Stack(
      children: [
        content,
        FloatingPaginationPill(
          currentPage: widget.currentPage,
          totalPages: widget.totalPages,
          isLoading: widget.isLoading,
          hasError: widget.hasError,
          isVisibleNotifier: _isPaginationVisible,
          bottomOffset: effectiveBottomOffset,
          onPageSelected: widget.onPageSelected ?? (_) {},
        ),
      ],
    );
  }
}
