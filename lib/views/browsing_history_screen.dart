import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/history_helper.dart';
import '../utils/toast_helper.dart';
import 'image_detail_screen.dart';
import '../models/image_item.dart';
import '../services/user_agent_service.dart';
import '../services/url_handler_service.dart';

class BrowsingHistoryScreen extends StatefulWidget {
  const BrowsingHistoryScreen({super.key});

  @override
  State<BrowsingHistoryScreen> createState() => _BrowsingHistoryScreenState();
}

class _BrowsingHistoryScreenState extends State<BrowsingHistoryScreen> {
  List<HistoryItem> _historyItems = [];
  bool _isLoading = true;
  String? _historyImagesDirPath;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final list = await HistoryHelper.getHistory();
    final imgDir = await HistoryHelper.getHistoryImagesDir();
    if (mounted) {
      setState(() {
        _historyItems = list;
        _historyImagesDirPath = imgDir.path;
        _isLoading = false;
      });
    }
  }

  Future<void> _deleteItem(HistoryItem item, int index) async {
    // 1. Remove from local file storage immediately
    await HistoryHelper.deleteHistoryItem(item.id);

    // 2. Remove from local UI list
    setState(() {
      _historyItems.removeAt(index);
    });

    if (!mounted) return;
    
    // 3. Show premium custom toast with undo countdown and Springy Slide animation!
    final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
    ToastHelper.showCustom(
      rootContext,
      duration: const Duration(seconds: 5),
      builder: (dismiss) => _HistoryUndoSnackBarContent(
        onUndo: () async {
          dismiss();
          
          // Wait for the exit slide-down animation to complete smoothly (350ms)
          await Future.delayed(const Duration(milliseconds: 350));
          
          // Restore in UI
          setState(() {
            _historyItems.insert(index, item);
          });
          
          // Save the restored history
          await HistoryHelper.saveHistory(_historyItems);
        },
      ),
    );
  }

  Future<void> _clearAllHistory() async {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: const Text('清空历史记录', style: TextStyle(fontWeight: FontWeight.bold)),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: const Text('确定要清除您所有的图片浏览记录吗？此操作无法撤销。'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              onPressed: () async {
                Navigator.pop(context);
                await HistoryHelper.clearHistory();
                await _loadHistory();
                if (mounted) {
                  final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                  ToastHelper.show(rootContext, '浏览历史记录已全部清空', type: ToastType.success);
                }
              },
              child: const Text('全部清空'),
            ),
          ],
        );
      },
    );
  }

  void _navigateToDetail(HistoryItem item) {
    // Reconstruct temporary MoelyImage model to open details view
    final moelyImage = MoelyImage(
      id: item.id,
      user: 'History',
      category: 'Recent',
      urls: item.thumbnailUrl,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageDetailScreen(image: moelyImage),
      ),
    ).then((_) => _loadHistory()); // Reload history on back
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('浏览历史', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (_historyItems.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.delete_sweep_rounded),
              tooltip: '清空全部',
              onPressed: _clearAllHistory,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _historyItems.isEmpty
              ? _buildEmptyState(theme)
              : _buildHistoryList(theme),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            '没有浏览过图片哦',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              '在主页或探索界面点击图片详情页，系统将会自动为您保留最近浏览过的 100 张精美图片。',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList(ThemeData theme) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _historyItems.length,
      itemBuilder: (context, index) {
        final item = _historyItems[index];
        final timeStr = "${item.timestamp.month.toString().padLeft(2, '0')}-${item.timestamp.day.toString().padLeft(2, '0')} ${item.timestamp.hour.toString().padLeft(2, '0')}:${item.timestamp.minute.toString().padLeft(2, '0')}";

        return Dismissible(
          key: Key(item.id + item.timestamp.millisecondsSinceEpoch.toString()),
          direction: DismissDirection.endToStart,
          onDismissed: (direction) => _deleteItem(item, index),
          background: Container(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.9),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.delete_forever_rounded, color: Colors.white),
          ),
          child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => _navigateToDetail(item),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 60,
                        height: 60,
                        child: _buildItemThumbnail(item, theme),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'ID: ${item.id}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '浏览时间: $timeStr',
                            style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      padding: const EdgeInsets.all(6),
                      constraints: const BoxConstraints(),
                      icon: Icon(Icons.close_rounded, color: theme.colorScheme.onSurface.withOpacity(0.4), size: 18),
                      onPressed: () => _deleteItem(item, index),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildItemThumbnail(HistoryItem item, ThemeData theme) {
    final id = item.id;
    final localFile = _historyImagesDirPath != null
        ? File('$_historyImagesDirPath/$id.jpg')
        : null;

    if (localFile != null && localFile.existsSync()) {
      return Image.file(
        localFile,
        fit: BoxFit.cover,
      );
    } else {
      return CachedNetworkImage(
        imageUrl: item.thumbnailUrl,
        httpHeaders: {'User-Agent': UserAgentService.userAgent},
        fit: BoxFit.cover,
        placeholder: (context, url) => Container(
          color: theme.colorScheme.onSurface.withOpacity(0.05),
        ),
        errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded),
      );
    }
  }
}

class _HistoryUndoSnackBarContent extends StatelessWidget {
  final VoidCallback onUndo;
  const _HistoryUndoSnackBarContent({required this.onUndo});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        const Icon(Icons.delete_outline_rounded, color: Colors.amber, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            '已移出浏览记录',
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
        TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 5.0, end: 0.0),
          duration: const Duration(seconds: 5),
          builder: (context, value, child) {
            final displaySeconds = value.ceil() == 0 ? 1 : value.ceil();
            final progress = value / 5.0;
            return SizedBox(
              height: 26,
              width: 26,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 2.2,
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.12),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                  ),
                  Text(
                    '$displaySeconds',
                    style: TextStyle(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w800,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(width: 12),
        TextButton.icon(
          onPressed: onUndo,
          icon: Icon(Icons.undo_rounded, size: 16, color: theme.colorScheme.primary),
          label: Text(
            '撤销',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
      ],
    );
  }
}
