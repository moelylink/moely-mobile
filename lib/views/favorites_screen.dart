import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/auth_service.dart';
import '../services/user_agent_service.dart';
import '../utils/cache_helper.dart';
import 'image_detail_screen.dart';
import '../models/image_item.dart';
import '../utils/toast_helper.dart';
import '../services/url_handler_service.dart';
import '../services/settings_service.dart';
import '../widgets/smooth_aspect_ratio_image.dart';
import '../widgets/floating_pagination_pill.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final _supabase = Supabase.instance.client;
  List<dynamic> _bookmarks = [];
  bool _isLoading = true;
  bool _isSyncing = false;
  String _syncProgressText = '';
  
  bool _isAscending = false;
  int _currentPage = 1;
  static const int _itemsPerPage = 20;
  
  final ValueNotifier<bool> _isPaginationVisible = ValueNotifier<bool>(true);
  Timer? _scrollTimer;

  @override
  void initState() {
    super.initState();
    _loadLocalAndSync();
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

  Future<File> _getFavoritesJsonFile() async {
    final favDir = await CacheHelper.getFavoritesCacheDir();
    return File('${favDir.path}/favorites.json');
  }

  Future<Directory> _getFavoritesImagesDir() async {
    final favDir = await CacheHelper.getFavoritesCacheDir();
    final imgDir = Directory('${favDir.path}/images');
    if (!imgDir.existsSync()) {
      imgDir.createSync(recursive: true);
    }
    return imgDir;
  }

  /// Load from local JSON cache first, then trigger background sync with Supabase
  Future<void> _loadLocalAndSync() async {
    setState(() => _isLoading = true);

    // 1. Load locally cached bookmarks first
    try {
      final jsonFile = await _getFavoritesJsonFile();
      if (jsonFile.existsSync()) {
        final content = await jsonFile.readAsString();
        final list = json.decode(content) as List;
        setState(() {
          _bookmarks = list;
          _isLoading = false;
        });
      }
    } catch (_) {}

    // 2. If logged in, trigger cloud sync
    if (AuthService.instance.isLoggedIn) {
      _syncWithCloud();
    } else {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _syncWithCloud() async {
    if (_isSyncing) return;
    setState(() {
      _isSyncing = true;
      _syncProgressText = '正在从云端拉取收藏...';
    });

    try {
      final userId = _supabase.auth.currentUser?.id;
      if (userId == null) return;

      // 1. Pull from Supabase
      final response = await _supabase
          .from('bookmarks')
          .select('id, url, image, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final List<dynamic> cloudBookmarks = response as List;

      // 2. Write to local metadata json
      final jsonFile = await _getFavoritesJsonFile();
      await jsonFile.writeAsString(json.encode(cloudBookmarks));

      setState(() {
        _bookmarks = cloudBookmarks;
        _isLoading = false;
        _syncProgressText = '元数据同步完成，正在缓存图片...';
      });

      // 3. Background download bookmark images for true offline capability
      final imagesDir = await _getFavoritesImagesDir();
      final dio = UserAgentService.createDio();

      int cachedCount = 0;
      for (final item in cloudBookmarks) {
        final id = item['id'].toString();
        final imageUrl = item['image'].toString();
        final localFile = File('${imagesDir.path}/$id.jpg');

        if (!localFile.existsSync()) {
          try {
            setState(() {
              _syncProgressText = '正在缓存第 ${cachedCount + 1}/${cloudBookmarks.length} 张图片';
            });
            await dio.download(imageUrl, localFile.path);
          } catch (e) {
            debugPrint('Failed to download collection image $id: $e');
            // If failed, delete incomplete file
            if (localFile.existsSync()) {
              localFile.deleteSync();
            }
          }
        }
        cachedCount++;
      }

    } catch (e) {
      debugPrint('Cloud sync failed: $e');
      if (mounted && _bookmarks.isEmpty) {
        final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
        ToastHelper.show(rootContext, '同步云端收藏失败: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _deleteBookmark(String id) async {
    setState(() {
      _syncProgressText = '正在删除云端数据...';
      _isSyncing = true;
    });

    try {
      // 1. Delete from Supabase
      if (AuthService.instance.isLoggedIn) {
        await _supabase.from('bookmarks').delete().eq('id', id);
      }

      // 2. Remove from local list
      setState(() {
        _bookmarks.removeWhere((item) => item['id'].toString() == id);
      });

      // 3. Update local json
      final jsonFile = await _getFavoritesJsonFile();
      await jsonFile.writeAsString(json.encode(_bookmarks));

      // 4. Delete local downloaded image
      final imagesDir = await _getFavoritesImagesDir();
      final localFile = File('${imagesDir.path}/$id.jpg');
      if (localFile.existsSync()) {
        localFile.deleteSync();
      }

      if (mounted) {
        final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
        ToastHelper.show(rootContext, '已从收藏夹移出', type: ToastType.success);
      }
    } catch (e) {
      if (mounted) {
        final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
        ToastHelper.show(rootContext, '移出失败: $e', type: ToastType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSyncing = false;
        });
      }
    }
  }

  String _extractWorkId(dynamic item) {
    final urlStr = item['url']?.toString() ?? '';
    // 匹配类似 /img/123456/ 里的数字部分
    final regExp = RegExp(r'/img/(\d+)');
    final match = regExp.firstMatch(urlStr);
    if (match != null) {
      return match.group(1)!;
    }
    
    // 降级：如果只有纯数字
    final digitsMatch = RegExp(r'(\d+)').firstMatch(urlStr);
    if (digitsMatch != null) {
      return digitsMatch.group(1)!;
    }
    
    // 最终降级：收藏记录ID
    return item['id'].toString();
  }

  void _navigateToDetail(dynamic item) {
    final workId = _extractWorkId(item);
    
    // Construct a temporary MoelyImage to load detail page using actual work ID
    final imageItem = MoelyImage(
      id: workId,
      user: 'Collection',
      category: 'Star',
      urls: item['image'].toString(),
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ImageDetailScreen(image: imageItem),
      ),
    ).then((_) => _loadLocalAndSync()); // Refresh on back
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('美图收藏', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (AuthService.instance.isLoggedIn)
            IconButton(
              icon: _isSyncing 
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.sync_rounded),
              onPressed: _loadLocalAndSync,
            ),
        ],
      ),
      body: Column(
        children: [
          if (_isSyncing)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: theme.colorScheme.primaryContainer.withOpacity(0.4),
              width: double.infinity,
              child: Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _syncProgressText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _bookmarks.isEmpty
                    ? _buildEmptyState(theme)
                    : _buildGrid(theme),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.favorite_border_rounded,
            size: 80,
            color: theme.colorScheme.onSurface.withOpacity(0.2),
          ),
          const SizedBox(height: 16),
          const Text(
            '这里空空如也呢',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              AuthService.instance.isLoggedIn
                  ? '去主页逛逛，把心仪的二次元美图收藏起来吧！'
                  : '您尚未登录萌哩。登录后即可与云端同步您的美图收藏夹。',
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

  Widget _buildGrid(ThemeData theme) {
    // 1. Sort bookmarks based on time and _isAscending
    final sorted = List.from(_bookmarks);
    sorted.sort((a, b) {
      final tA = DateTime.tryParse(a['created_at'].toString()) ?? DateTime.now();
      final tB = DateTime.tryParse(b['created_at'].toString()) ?? DateTime.now();
      return _isAscending ? tA.compareTo(tB) : tB.compareTo(tA);
    });

    final enableInfinite = AppSettings.instance.enableInfiniteScroll;

    // 2. Paginate / Slice
    final totalItems = sorted.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();

    final List<dynamic> pageItems;
    if (enableInfinite) {
      final maxDisplay = _currentPage * _itemsPerPage;
      final endIndex = maxDisplay > totalItems ? totalItems : maxDisplay;
      pageItems = sorted.sublist(0, endIndex);
    } else {
      if (_currentPage > totalPages && totalPages > 0) {
        _currentPage = totalPages;
      }
      final startIndex = (_currentPage - 1) * _itemsPerPage;
      final endIndex = startIndex + _itemsPerPage > totalItems ? totalItems : startIndex + _itemsPerPage;
      pageItems = sorted.sublist(startIndex, endIndex);
    }

    final bool hasMoreInfinite = enableInfinite && pageItems.length < totalItems;

    return Stack(
      children: [
        // A. Scrollable Grid Container
        Positioned.fill(
          child: NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              final metrics = scrollNotification.metrics;
              final bool isAtBottom = metrics.maxScrollExtent > 0 && metrics.pixels >= metrics.maxScrollExtent - 1.0;

              if (isAtBottom) {
                _scrollTimer?.cancel();
                if (!_isPaginationVisible.value) {
                  _isPaginationVisible.value = true;
                }
              } else if (scrollNotification is ScrollStartNotification) {
                _onScrollStarted();
              } else if (scrollNotification is ScrollUpdateNotification) {
                if (_isPaginationVisible.value) {
                  _onScrollStarted();
                }
              } else if (scrollNotification is ScrollEndNotification) {
                _onScrollEnded();
              }

              if (scrollNotification is ScrollUpdateNotification || scrollNotification is ScrollEndNotification) {
                if (enableInfinite && metrics.extentAfter < 500) {
                  if (pageItems.length < totalItems) {
                    setState(() {
                      _currentPage++;
                    });
                  }
                }
              }
              return false;
            },
            child: Column(
              children: [
                // Sort & Summary Info Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        enableInfinite
                            ? '共 $totalItems 张美图'
                            : '共 $totalItems 张美图 | 第 $_currentPage/$totalPages 页',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _isAscending = !_isAscending;
                            _currentPage = 1; // Reset to page 1 on resort
                          });
                        },
                        icon: Icon(
                          _isAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                          size: 16,
                        ),
                        label: Text(
                          _isAscending ? '时间升序' : '时间降序',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ),

                // Grid itself
                Expanded(
                  child: MasonryGridView.count(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    padding: const EdgeInsets.only(left: 12, right: 12, top: 4, bottom: 90.0),
                    itemCount: pageItems.length + (hasMoreInfinite ? 1 : 0),
                    itemBuilder: (context, index) {
                      if (index >= pageItems.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24.0),
                          child: Center(
                            child: SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                        );
                      }
                      final item = pageItems[index];
                      final id = item['id'].toString();
                      final workId = _extractWorkId(item);
                      final imageUrl = item['image'].toString();
                      
                      // Formatting the timestamp below the image
                      String timeStr = '未知时间';
                      try {
                        if (item['created_at'] != null) {
                          final dt = DateTime.parse(item['created_at'].toString()).toLocal();
                          timeStr = "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
                        }
                      } catch (_) {}

                      return FutureBuilder<Directory>(
                        future: _getFavoritesImagesDir(),
                        builder: (context, snapshot) {
                          final isOfflineFileExists = snapshot.hasData && 
                              File('${snapshot.data!.path}/$id.jpg').existsSync();
                          final localFile = isOfflineFileExists ? File('${snapshot.data!.path}/$id.jpg') : null;

                          final imageWidget = SmoothAspectRatioImage(
                            imageUrl: localFile == null ? imageUrl : null,
                            localFile: localFile,
                            builder: (context, isLoading) {
                              if (localFile != null) {
                                return Image.file(
                                  localFile,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                );
                              } else {
                                return CachedNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  placeholder: (context, url) => Container(
                                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                                    child: const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: theme.colorScheme.onSurface.withOpacity(0.05),
                                    child: const Center(
                                      child: Icon(Icons.broken_image_rounded, size: 32),
                                    ),
                                  ),
                                );
                              }
                            },
                          );

                          return Card(
                            clipBehavior: Clip.antiAlias,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Stack(
                                  children: [
                                    InkWell(
                                      onTap: () => _navigateToDetail(item),
                                      child: imageWidget,
                                    ),
                                    
                                    // Delete overlay button (top right)
                                    Positioned(
                                      top: 6,
                                      right: 6,
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.4),
                                          shape: BoxShape.circle,
                                        ),
                                        child: IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.white, size: 18),
                                          onPressed: () {
                                            showDialog(
                                              context: context,
                                              builder: (context) => AlertDialog(
                                                backgroundColor: theme.colorScheme.surface,
                                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                                                insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
                                                title: const Text('删除收藏', style: TextStyle(fontWeight: FontWeight.bold)),
                                                content: SizedBox(
                                                  width: MediaQuery.of(context).size.width * 0.85,
                                                  child: const Text('确定要把这张心仪的美图移出您的收藏夹吗？'),
                                                ),
                                                actions: [
                                                  TextButton(
                                                    onPressed: () => Navigator.pop(context),
                                                    child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
                                                  ),
                                                  FilledButton(
                                                    style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                                                    onPressed: () {
                                                      Navigator.pop(context);
                                                      _deleteBookmark(id);
                                                    },
                                                    child: const Text('确认移出'),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                // Metadata card footer displaying details & time
                                Padding(
                                  padding: const EdgeInsets.all(8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'ID: $workId',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 11,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.access_time_rounded,
                                            size: 10,
                                            color: theme.colorScheme.onSurface.withOpacity(0.4),
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              timeStr,
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: theme.colorScheme.onSurface.withOpacity(0.4),
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
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),

        FloatingPaginationPill(
          currentPage: _currentPage,
          totalPages: totalPages,
          isLoading: _isLoading,
          isVisibleNotifier: _isPaginationVisible,
          onPageSelected: (page) {
            setState(() {
              _currentPage = page;
            });
          },
        ),
      ],
    );
  }
}
