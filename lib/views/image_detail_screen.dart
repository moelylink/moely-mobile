import 'dart:io';
import 'dart:ui';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:path_provider/path_provider.dart';
import '../models/image_item.dart';
import '../models/image_details.dart';
import '../services/image_details_parser.dart';
import '../services/translation_service.dart';
import '../utils/download_helper.dart';
import '../utils/cache_helper.dart';
import 'denoised_web_screen.dart';
import '../services/wallpaper_service.dart';
import '../services/settings_service.dart';
import '../services/user_agent_service.dart';
import '../services/url_handler_service.dart';
import 'tag_grid_screen.dart';
import 'category_grid_screen.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_filex/open_filex.dart';
import '../utils/history_helper.dart';
import '../utils/toast_helper.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

class ImageDetailScreen extends StatefulWidget {
  final MoelyImage image;

  const ImageDetailScreen({
    super.key,
    required this.image,
  });

  @override
  State<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends State<ImageDetailScreen> with SingleTickerProviderStateMixin {
  late MoelyImage _currentImage;
  ImageDetails? _details;
  bool _isLoadingDetails = true;
  Set<String> _favoritedImageUrls = {};
  bool _isThumbnailCached = false;
  
  // Translation state
  bool _isTranslating = false;
  bool _isTranslated = false;
  String _translatedTags = '';
  String _translatedDescription = '';

  // Animation controller for heart scale effect
  late final AnimationController _heartController;
  late final Animation<double> _heartScaleAnimation;

  // Overscroll scroll controller and tracking state
  final ScrollController _scrollController = ScrollController();
  double _overscrollBottom = 0.0;
  double _overscrollTop = 0.0;
  bool _hasPrevImage = false;

  static List<MoelyImage>? _globalIndexList;

  // Preloading state and cached variables for instant transitions
  MoelyImage? _preloadedNextImage;
  ImageDetails? _preloadedNextDetails;
  bool _isPreloadingNext = false;

  // Track all randomly swiped or preloaded images and their URLs for surgical cache eviction on exit
  final Set<String> _randomImageIds = {};
  final Set<String> _randomImageUrlsToEvict = {};

  @override
  void initState() {
    super.initState();
    _currentImage = widget.image;
    _heartController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _heartScaleAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.4), weight: 50),
      TweenSequenceItem(tween: Tween(begin: 1.4, end: 1.0), weight: 50),
    ]).animate(_heartController);

    _scrollController.addListener(_onScroll);
    _checkHistoryStatus();
    _checkThumbnailCache();
    _loadDetails();
    _checkFavoriteStatus();
    HistoryHelper.addToHistory(_currentImage.id, _currentImage.urls);
    if (AppSettings.instance.enableOverscrollRandom) {
      _preloadNextImage();
    }
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    
    final offset = _scrollController.offset;
    final maxScroll = _scrollController.position.maxScrollExtent;
    
    // Detect overscroll at the bottom
    if (AppSettings.instance.enableOverscrollRandom && offset > maxScroll) {
      final overscroll = offset - maxScroll;
      if (overscroll != _overscrollBottom) {
        setState(() {
          _overscrollBottom = overscroll;
        });
      }
    } else {
      if (_overscrollBottom != 0.0) {
        setState(() {
          _overscrollBottom = 0.0;
        });
      }
    }
    
    // Detect overscroll at the top
    if (offset < 0) {
      final overscroll = -offset;
      if (overscroll != _overscrollTop) {
        setState(() {
          _overscrollTop = overscroll;
        });
      }
    } else {
      if (_overscrollTop != 0.0) {
        setState(() {
          _overscrollTop = 0.0;
        });
      }
    }
  }

  Future<void> _checkThumbnailCache() async {
    try {
      final fileInfo = await DefaultCacheManager().getFileFromCache(_currentImage.urls);
      if (mounted) {
        setState(() {
          _isThumbnailCached = fileInfo != null;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isThumbnailCached = false;
        });
      }
    }
  }

  Widget _buildPlaceholder(BuildContext context, String url, int index, ThemeData theme, Color platformColor) {
    final plainPlaceholder = Container(
      height: 250,
      color: theme.colorScheme.surfaceVariant,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: platformColor),
          const SizedBox(height: 12),
          Text(
            '正在加载',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
              fontSize: 12,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ),
    );

    if (index == 0) {
      final blurredThumbnailPlaceholder = Stack(
        alignment: Alignment.center,
        children: [
          CachedNetworkImage(
            imageUrl: _currentImage.urls,
            httpHeaders: {'User-Agent': UserAgentService.userAgent},
            fit: BoxFit.fitWidth,
            width: double.infinity,
          ),
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: Colors.black.withOpacity(0.4),
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 3,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      '正在加载',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

      return Material(
        type: MaterialType.transparency,
        child: AnimatedCrossFade(
          firstChild: plainPlaceholder,
          secondChild: blurredThumbnailPlaceholder,
          crossFadeState: _isThumbnailCached ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
          firstCurve: Curves.easeInOut,
          secondCurve: Curves.easeInOut,
          sizeCurve: Curves.easeInOut,
        ),
      );
    }

    return Material(
      type: MaterialType.transparency,
      child: plainPlaceholder,
    );
  }

  Future<void> _checkHistoryStatus() async {
    final status = await _hasHistory();
    if (mounted) {
      setState(() {
        _hasPrevImage = status;
      });
    }
  }

  Future<List<MoelyImage>> _getOrFetchIndexList() async {
    if (_globalIndexList != null && _globalIndexList!.isNotEmpty) {
      return _globalIndexList!;
    }
    
    final tempDir = await getTemporaryDirectory();
    final cacheFile = File('${tempDir.path}/global_index_cache.json');
    
    if (await cacheFile.exists()) {
      try {
        final content = await cacheFile.readAsString();
        final List<dynamic> listData = json.decode(content);
        _globalIndexList = listData.map((e) => MoelyImage.fromJson(e)).toList();
        if (_globalIndexList!.isNotEmpty) {
          _fetchIndexAndSaveBackground(cacheFile);
          return _globalIndexList!;
        }
      } catch (_) {}
    }
    
    try {
      final dio = UserAgentService.createDio();
      final response = await dio.get('https://www.moely.link/index.json');
      if (response.statusCode == 200 && response.data is List) {
        final List<dynamic> listData = response.data;
        _globalIndexList = listData.map((e) => MoelyImage.fromJson(e)).toList();
        await cacheFile.writeAsString(json.encode(response.data));
        return _globalIndexList!;
      }
    } catch (_) {}
    
    return _globalIndexList ?? [];
  }

  void _fetchIndexAndSaveBackground(File cacheFile) {
    Future.microtask(() async {
      try {
        final dio = UserAgentService.createDio();
        final response = await dio.get('https://www.moely.link/index.json');
        if (response.statusCode == 200 && response.data is List) {
          _globalIndexList = (response.data as List).map((e) => MoelyImage.fromJson(e)).toList();
          await cacheFile.writeAsString(json.encode(response.data));
        }
      } catch (_) {}
    });
  }

  Future<File> _getHistoryFile() async {
    final tempDir = await getTemporaryDirectory();
    return File('${tempDir.path}/detail_history.json');
  }

  Future<void> _pushToHistory(MoelyImage image) async {
    try {
      final file = await _getHistoryFile();
      List<dynamic> historyJson = [];
      if (await file.exists()) {
        final content = await file.readAsString();
        historyJson = json.decode(content) as List;
      }
      historyJson.add(image.toJson());
      await file.writeAsString(json.encode(historyJson));
    } catch (e) {
      debugPrint('Error pushing to history: $e');
    }
  }

  Future<MoelyImage?> _popFromHistory() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) return null;
      final content = await file.readAsString();
      final List<dynamic> historyJson = json.decode(content) as List;
      if (historyJson.isEmpty) return null;
      
      final poppedItemJson = historyJson.removeLast();
      if (historyJson.isEmpty) {
        await file.delete();
      } else {
        await file.writeAsString(json.encode(historyJson));
      }
      return MoelyImage.fromJson(poppedItemJson);
    } catch (e) {
      debugPrint('Error popping from history: $e');
      return null;
    }
  }

  Future<bool> _hasHistory() async {
    try {
      final file = await _getHistoryFile();
      if (!await file.exists()) return false;
      final content = await file.readAsString();
      final List<dynamic> historyJson = json.decode(content) as List;
      return historyJson.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _clearHistory() async {
    try {
      final file = await _getHistoryFile();
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<void> _preloadNextImage() async {
    if (!AppSettings.instance.enableOverscrollRandom) return;
    if (_isPreloadingNext || _preloadedNextImage != null) return;
    _isPreloadingNext = true;
    
    try {
      final indexList = await _getOrFetchIndexList();
      if (indexList.isEmpty) return;
      
      final random = math.Random();
      MoelyImage randomImage = indexList[random.nextInt(indexList.length)];
      int retries = 5;
      while (randomImage.id == _currentImage.id && retries > 0) {
        randomImage = indexList[random.nextInt(indexList.length)];
        retries--;
      }
      
      final details = await ImageDetailsParser.fetchDetails(randomImage.id);
      
      _preloadedNextImage = randomImage;
      _preloadedNextDetails = details;
      
      // Track random image ID and preview URLs for cache eviction
      _randomImageIds.add(randomImage.id);
      if (details != null && details.previewUrls.isNotEmpty) {
        _randomImageUrlsToEvict.addAll(details.previewUrls);
      } else if (randomImage.urls.isNotEmpty) {
        _randomImageUrlsToEvict.add(_getHighResUrl(randomImage.urls));
      }
      
      if (mounted && details != null && details.previewUrls.isNotEmpty) {
        final firstImgUrl = details.previewUrls.first;
        precacheImage(
          CachedNetworkImageProvider(
            firstImgUrl,
            headers: {'User-Agent': UserAgentService.userAgent},
          ),
          context,
        );
      } else if (mounted && randomImage.urls.isNotEmpty) {
        final fallbackUrl = _getHighResUrl(randomImage.urls);
        precacheImage(
          CachedNetworkImageProvider(
            fallbackUrl,
            headers: {'User-Agent': UserAgentService.userAgent},
          ),
          context,
        );
      }
    } catch (e) {
      debugPrint('Error preloading next image: $e');
    } finally {
      _isPreloadingNext = false;
    }
  }

  Future<void> _loadRandomImage() async {
    setState(() {
      _isLoadingDetails = true;
    });
    
    try {
      if (_preloadedNextImage != null && _preloadedNextDetails != null) {
        final nextImage = _preloadedNextImage!;
        final nextDetails = _preloadedNextDetails!;
        
        await _pushToHistory(_currentImage);
        
        setState(() {
          _currentImage = nextImage;
          _details = nextDetails;
          _isLoadingDetails = false;
          _favoritedImageUrls.clear();
          _isTranslating = false;
          _isTranslated = false;
          _translatedTags = '';
          _translatedDescription = '';
          _overscrollBottom = 0.0;
          _overscrollTop = 0.0;
          _isThumbnailCached = false;
          
          _preloadedNextImage = null;
          _preloadedNextDetails = null;
        });
        
        _checkThumbnailCache();
        _checkFavoriteStatus();
        HistoryHelper.addToHistory(nextImage.id, nextImage.urls);
        
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(0.0);
        }
        
        _checkHistoryStatus();
        _preloadNextImage();
        return;
      }
      
      final indexList = await _getOrFetchIndexList();
      if (indexList.isEmpty) {
        throw Exception('Empty index list');
      }
      
      final random = math.Random();
      MoelyImage randomImage = indexList[random.nextInt(indexList.length)];
      int retries = 5;
      while (randomImage.id == _currentImage.id && retries > 0) {
        randomImage = indexList[random.nextInt(indexList.length)];
        retries--;
      }

      await _pushToHistory(_currentImage);
      
      // Track random image ID and preview URLs for cache eviction
      _randomImageIds.add(randomImage.id);
      if (randomImage.urls.isNotEmpty) {
        _randomImageUrlsToEvict.add(_getHighResUrl(randomImage.urls));
      }
      
      setState(() {
        _currentImage = randomImage;
        _details = null;
        _isLoadingDetails = true;
        _favoritedImageUrls.clear();
        _isTranslating = false;
        _isTranslated = false;
        _translatedTags = '';
        _translatedDescription = '';
        _overscrollBottom = 0.0;
        _overscrollTop = 0.0;
        _isThumbnailCached = false;
      });
      
      _checkThumbnailCache();
      _checkFavoriteStatus();
      HistoryHelper.addToHistory(randomImage.id, randomImage.urls);
      
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      
      _checkHistoryStatus();
      _loadDetails();
      _preloadNextImage();
    } catch (e) {
      debugPrint('Error loading random image: $e');
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  Future<void> _loadPreviousImage() async {
    setState(() {
      _isLoadingDetails = true;
    });
    
    final prevImage = await _popFromHistory();
    if (prevImage != null) {
      setState(() {
        _currentImage = prevImage;
        _details = null;
        _isLoadingDetails = true;
        _favoritedImageUrls.clear();
        _isTranslating = false;
        _isTranslated = false;
        _translatedTags = '';
        _translatedDescription = '';
        _overscrollBottom = 0.0;
        _overscrollTop = 0.0;
        _isThumbnailCached = false;
      });
      
      _checkThumbnailCache();
      _checkFavoriteStatus();
      HistoryHelper.addToHistory(prevImage.id, prevImage.urls);
      
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0.0);
      }
      
      _checkHistoryStatus();
      _loadDetails();
      _preloadNextImage();
    } else {
      setState(() {
        _isLoadingDetails = false;
      });
    }
  }

  Future<void> _handleScrollRelease() async {
    const double threshold = 100.0;
    
    if (_overscrollBottom >= threshold) {
      _loadRandomImage();
    } else if (_overscrollTop >= threshold && _hasPrevImage) {
      _loadPreviousImage();
    }
  }

  String _getDisplayTitle() {
    if (_details != null && _details!.title.isNotEmpty) {
      return _details!.title;
    }
    return 'ID: ${_currentImage.id}';
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _heartController.dispose();
    _clearHistory();
    
    // Evict all random and preloaded image and details cache dynamically upon exit
    for (final url in _randomImageUrlsToEvict) {
      try {
        CachedNetworkImage.evictFromCache(url);
      } catch (_) {}
    }
    for (final id in _randomImageIds) {
      try {
        CacheHelper.deleteDetailsFromCache(id);
      } catch (_) {}
    }
    
    super.dispose();
  }

  Future<void> _loadDetails() async {
    final details = await ImageDetailsParser.fetchDetails(_currentImage.id);
    if (mounted) {
      setState(() {
        _details = details;
        if (details != null) {
          _currentImage = MoelyImage(
            id: _currentImage.id,
            user: (details.user.isNotEmpty && details.user != 'Unknown') ? details.user : _currentImage.user,
            category: (details.category.isNotEmpty && details.category != 'Other') ? details.category : _currentImage.category,
            urls: _currentImage.urls.isNotEmpty
                ? _currentImage.urls
                : (details.previewUrls.isNotEmpty ? details.previewUrls.first : ''),
            total: _currentImage.total,
          );
        }
        _isLoadingDetails = false;
      });
      _checkFavoriteStatus();
    }
  }

  String _getHighResUrl(String url) {
    if (url.contains('name=small')) {
      return url.replaceAll('name=small', 'name=large');
    }
    if (url.contains('name=medium')) {
      return url.replaceAll('name=medium', 'name=large');
    }
    return url;
  }

  String _getThumbnailUrl(String rawImgUrl, int index) {
    // If the HTML successfully parsed a star URL for this specific index, use it directly!
    if (_details != null && _details!.starUrls.length > index) {
      return _details!.starUrls[index];
    }
    
    // Otherwise, fall back to our highly reliable string replacement logic!
    if (rawImgUrl.contains('i.moely.link/') && !rawImgUrl.contains('/c/540x540_70/')) {
      return rawImgUrl.replaceFirst('i.moely.link/', 'i.moely.link/c/540x540_70/');
    }
    return rawImgUrl;
  }

  void _showNotification(String message, {String type = 'info'}) {
    if (!mounted) return;
    ToastType toastType;
    switch (type) {
      case 'success':
        toastType = ToastType.success;
        break;
      case 'warning':
        toastType = ToastType.warning;
        break;
      case 'error':
        toastType = ToastType.error;
        break;
      default:
        toastType = ToastType.info;
    }
    final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
    ToastHelper.show(rootContext, message, type: toastType);
  }

  Future<List<dynamic>> _loadLocalFavorites() async {
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) return [];

    try {
      final favDir = await CacheHelper.getFavoritesCacheDir();
      final jsonFile = File('${favDir.path}/favorites.json');
      
      // If local cache doesn't exist, lazily fetch all from Supabase once
      if (!jsonFile.existsSync()) {
        final response = await Supabase.instance.client
            .from('bookmarks')
            .select('id, url, image, created_at')
            .eq('user_id', userId)
            .order('created_at', ascending: false);
            
        final List<dynamic> cloudBookmarks = response as List;
        await jsonFile.writeAsString(json.encode(cloudBookmarks));
        return cloudBookmarks;
      }
      
      final content = await jsonFile.readAsString();
      return json.decode(content) as List;
    } catch (e) {
      debugPrint('Error loading favorites cache: $e');
      return [];
    }
  }

  Future<void> _checkFavoriteStatus() async {
    final userId = AuthService.instance.userId;
    if (userId.isEmpty) {
      if (mounted) {
        setState(() {
          _favoritedImageUrls.clear();
        });
      }
      return;
    }

    final localList = await _loadLocalFavorites();
    final targetUrl = '/img/${_currentImage.id}/';
    
    // Filter bookmarks belonging to this work ID and extract their thumbnail URLs
    final matchingBookmarks = localList.where((item) => item['url'] == targetUrl);
    final favoritedUrls = matchingBookmarks.map((item) => item['image'].toString()).toSet();

    if (mounted) {
      setState(() {
        _favoritedImageUrls = favoritedUrls;
      });
    }
  }

  Future<void> _addFavorite(String userId, String rawImgUrl, int index) async {
    final detailUrl = '/img/${_currentImage.id}/';
    final thumbnailUrl = _getThumbnailUrl(rawImgUrl, index);
    
    setState(() {
      _favoritedImageUrls.add(thumbnailUrl);
    });
    _heartController.forward(from: 0.0);

    try {
      // 1. Insert into Supabase
      final response = await Supabase.instance.client
          .from('bookmarks')
          .insert([{
            'user_id': userId,
            'url': detailUrl,
            'image': thumbnailUrl,
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }])
          .select();

      // 2. Update local JSON cache
      try {
        final favDir = await CacheHelper.getFavoritesCacheDir();
        final jsonFile = File('${favDir.path}/favorites.json');
        if (jsonFile.existsSync()) {
          final content = await jsonFile.readAsString();
          final List<dynamic> localList = json.decode(content);
          if (response is List && response.isNotEmpty) {
            localList.insert(0, response.first);
            await jsonFile.writeAsString(json.encode(localList));
          }
        }
      } catch (e) {
        debugPrint('Error updating local favorites cache: $e');
      }

      _showNotification('已添加到收藏！', type: 'success');
    } catch (error) {
      debugPrint('Error adding to favorites: $error');
      setState(() {
        _favoritedImageUrls.remove(thumbnailUrl);
      });
      
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              title: const Row(
                children: [
                  Icon(Icons.error_outline_rounded, color: Colors.red),
                  SizedBox(width: 10),
                  Text('收藏失败', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: const Text('添加收藏失败，请重试'),
              ),
              actions: [
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      }
    }
  }

  Future<void> _removeFavorite(String userId, String rawImgUrl, int index) async {
    final detailUrl = '/img/${_currentImage.id}/';
    final thumbnailUrl = _getThumbnailUrl(rawImgUrl, index);
    
    setState(() {
      _favoritedImageUrls.remove(thumbnailUrl);
    });

    try {
      // 1. Delete from Supabase
      await Supabase.instance.client
          .from('bookmarks')
          .delete()
          .eq('user_id', userId)
          .eq('url', detailUrl)
          .eq('image', thumbnailUrl);

      // 2. Update local JSON cache
      try {
        final favDir = await CacheHelper.getFavoritesCacheDir();
        final jsonFile = File('${favDir.path}/favorites.json');
        if (jsonFile.existsSync()) {
          final content = await jsonFile.readAsString();
          final List<dynamic> localList = json.decode(content);
          localList.removeWhere((item) => item['url'] == detailUrl && item['image'] == thumbnailUrl);
          await jsonFile.writeAsString(json.encode(localList));
        }
      } catch (e) {
        debugPrint('Error removing from local favorites cache: $e');
      }

      _showNotification('已取消收藏', type: 'info');
    } catch (error) {
      debugPrint('Error removing from favorites: $error');
      setState(() {
        _favoritedImageUrls.add(thumbnailUrl);
      });
      _showNotification('取消收藏失败，请重试', type: 'error');
    }
  }

  void _toggleFavorite(String rawImgUrl, int index) async {
    final userId = AuthService.instance.userId;
    final thumbnailUrl = _getThumbnailUrl(rawImgUrl, index);
    
    if (userId.isEmpty) {
      showDialog(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          return AlertDialog(
            backgroundColor: theme.colorScheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
            title: const Row(
              children: [
                Icon(Icons.login_rounded, color: Colors.amber),
                SizedBox(width: 10),
                Text('需要登录', style: TextStyle(fontWeight: FontWeight.bold)),
              ],
            ),
            content: SizedBox(
              width: MediaQuery.of(context).size.width * 0.85,
              child: const Text('请先登录以使用收藏功能！'),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  _showNotification('用户未登录！', type: 'warning');
                },
                child: Text('取消', style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.6))),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginScreen()),
                  ).then((_) {
                    _checkFavoriteStatus();
                  });
                },
                child: const Text('确定'),
              ),
            ],
          );
        },
      );
      return;
    }

    if (_favoritedImageUrls.contains(thumbnailUrl)) {
      _showNotification('你已经收藏过了', type: 'info');
    } else {
      await _addFavorite(userId, rawImgUrl, index);
    }
  }

  Future<void> _handleDownload(int index) async {
    String downloadUrl = '';
    if (_details != null && _details!.downloadUrls.length > index) {
      downloadUrl = _details!.downloadUrls[index];
    } else if (index == 0) {
      downloadUrl = _getHighResUrl(_currentImage.urls);
    } else {
      return;
    }

    final extension = downloadUrl.contains('.png') ? 'png' : 'jpg';
    final totalPages = int.tryParse(_currentImage.total ?? '') ?? (_details?.downloadUrls.length ?? 1);
    final filename = totalPages > 1
        ? '${_currentImage.id}_p$index.$extension'
        : '${_currentImage.id}.$extension';

    double progress = 0.0;
    StateSetter? dialogStateSetter;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            dialogStateSetter = setDialogState;
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              title: const Text('正在下载原图', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 8),
                    CircularProgressIndicator(value: progress > 0.0 ? progress : null),
                    const SizedBox(height: 16),
                    Text('${(progress * 100).toStringAsFixed(0)}% 下载中...'),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    try {
      final savedPath = await DownloadHelper.downloadImage(
        downloadUrl,
        filename,
        onProgress: (received, total) {
          if (total > 0) {
            if (mounted && dialogStateSetter != null) {
              dialogStateSetter!(() {
                progress = received / total;
              });
            }
          }
        },
      );

      if (mounted) {
        Navigator.pop(context); // Close dialog
        final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
        ToastHelper.show(
          rootContext,
          '图片下载成功',
          type: ToastType.success,
          actionLabel: '打开',
          onActionTap: () async {
            try {
              await OpenFilex.open(savedPath);
            } catch (e) {
              debugPrint('Failed to open file: $e');
            }
          },
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
        ToastHelper.show(
          rootContext,
          '下载失败: $e',
          type: ToastType.error,
        );
      }
    }
  }

  Future<String> _translateDescription(String text) async {
    if (text.isEmpty) return '';

    // We want to support both Markdown links: [text](url) and HTML <a> tags: <a href="url">text</a>
    final markdownRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    final htmlRegex = RegExp(r'<a\b[^>]*>(.*?)<\/a>', caseSensitive: false);

    final List<String> originalLinks = [];
    final List<String> innerTexts = [];
    final List<String> linkUrls = [];
    final List<bool> isHtml = [];

    String textWithPlaceholders = text;

    // 1. Process Markdown links first
    var mdMatches = markdownRegex.allMatches(textWithPlaceholders).toList();
    int placeholderIndex = 0;
    for (final match in mdMatches) {
      final original = match.group(0)!;
      final inner = match.group(1)!;
      final url = match.group(2)!;

      originalLinks.add(original);
      innerTexts.add(inner);
      linkUrls.add(url);
      isHtml.add(false);

      // Use punctuation-free alphanumeric tokens with spaces so translation engines leave them untouched
      textWithPlaceholders = textWithPlaceholders.replaceFirst(original, ' XLINK${placeholderIndex}X ');
      placeholderIndex++;
    }

    // 2. Process HTML <a> tags next (on the already replaced string)
    var htmlMatches = htmlRegex.allMatches(textWithPlaceholders).toList();
    for (final match in htmlMatches) {
      final original = match.group(0)!;
      final inner = match.group(1)!;

      // Extract href if possible
      final hrefMatch = RegExp(r'''href=["']([^"']+)["']''', caseSensitive: false).firstMatch(original);
      final url = hrefMatch?.group(1) ?? '';

      originalLinks.add(original);
      innerTexts.add(inner);
      linkUrls.add(url);
      isHtml.add(true);

      textWithPlaceholders = textWithPlaceholders.replaceFirst(original, ' XLINK${placeholderIndex}X ');
      placeholderIndex++;
    }

    if (placeholderIndex == 0) {
      return TranslationService.translate(text);
    }

    // 3. Translate the description text with placeholders
    String translatedText = await TranslationService.translate(textWithPlaceholders);

    // 4. Translate inner text of each link in parallel
    final List<String> translatedInnerTexts = await Future.wait(
      innerTexts.map((inner) async {
        if (inner.trim().isEmpty) return inner;
        try {
          return await TranslationService.translate(inner);
        } catch (_) {
          return inner;
        }
      }).toList(),
    );

    // 5. Reconstruct and restore each link back into the translated text
    for (int i = 0; i < placeholderIndex; i++) {
      final inner = translatedInnerTexts[i];
      final url = linkUrls[i];
      final isTagHtml = isHtml[i];

      String reconstructed;
      if (isTagHtml) {
        final original = originalLinks[i];
        final openTagEndIndex = original.indexOf('>');
        final openTagPart = original.substring(0, openTagEndIndex + 1);
        reconstructed = '$openTagPart$inner</a>';
      } else {
        reconstructed = '[$inner]($url)';
      }

      // Try matching our premium alphanumeric token first
      final primaryRegex = RegExp('X\\s*LINK\\s*${i}\\s*X', caseSensitive: false);
      
      // Resilient fallback matching standard brackets (supports missing bracket like [[L_0], [L_0]], L_0, etc.)
      final bracketRegex = RegExp('\\[*\\s*[lL]_?\\s*${i}\\s*\\]*', caseSensitive: false);
      
      // Resilient fallback matching Chinese brackets (e.g. 【L_0】)
      final chineseBracketRegex = RegExp('【*\\s*[lL]_?\\s*${i}\\s*】*', caseSensitive: false);

      if (primaryRegex.hasMatch(translatedText)) {
        translatedText = translatedText.replaceFirst(primaryRegex, reconstructed);
      } else if (bracketRegex.hasMatch(translatedText)) {
        translatedText = translatedText.replaceFirst(bracketRegex, reconstructed);
      } else if (chineseBracketRegex.hasMatch(translatedText)) {
        translatedText = translatedText.replaceFirst(chineseBracketRegex, reconstructed);
      } else {
        // Literal replacements
        translatedText = translatedText
            .replaceFirst('XLINK${i}X', reconstructed)
            .replaceFirst('[[L_$i]]', reconstructed)
            .replaceFirst('[[L_$i]', reconstructed)
            .replaceFirst('[L_$i]', reconstructed);
      }
    }

    return translatedText;
  }

  Future<void> _handleTranslation() async {
    if (_isTranslated) {
      setState(() {
        _isTranslated = false;
      });
      return;
    }

    if (_details == null) return;

    setState(() {
      _isTranslating = true;
    });

    try {
      // 1. Prepare parallel translation futures for tags separately
      Future<String> tagsFuture = Future.value('');
      if (_details!.tags.isNotEmpty) {
        final cleanTags = _details!.tags.map((tag) {
          var clean = tag.replaceAll('|nolink', '');
          if (clean.contains('|slug:')) {
            clean = clean.split('|slug:').first;
          }
          clean = clean.trim();
          if (clean.startsWith('#')) {
            clean = clean.substring(1).trim();
          }
          return clean;
        }).toList();

        final translatedTagFutures = cleanTags.map((tag) {
          if (tag.trim().isEmpty) return Future.value('');
          return TranslationService.translate(tag).catchError((err) {
            debugPrint('Tag "$tag" translation failed: $err');
            return tag;
          });
        }).toList();

        tagsFuture = Future.wait(translatedTagFutures).then((list) {
          return list.where((t) => t.isNotEmpty).join(', ');
        });
      }

      // 2. Prepare description translation protecting all hyperlink formats
      Future<String> descFuture = Future.value('');
      final hasDescription = _details!.description.isNotEmpty && 
          _details!.description != '暂无描述' && 
          _details!.description != '获取描述中...';
      if (hasDescription) {
        descFuture = _translateDescription(_details!.description).catchError((err) {
          debugPrint('Description translation failed: $err');
          return '';
        });
      }

      // 3. Wait for both in parallel
      final results = await Future.wait([tagsFuture, descFuture]);
      final translatedTags = results[0];
      final translatedDesc = results[1];

      setState(() {
        _translatedTags = translatedTags;
        _translatedDescription = translatedDesc;
        _isTranslated = true;
        _isTranslating = false;
      });
    } catch (e) {
      setState(() {
        _isTranslating = false;
      });
      if (mounted) {
        final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
        ToastHelper.show(rootContext, '翻译失败，请检查网络后重试', type: ToastType.error);
      }
    }
  }

  void _showWallpaperOptions(int index) {
    final theme = Theme.of(context);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface.withOpacity(0.95),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Text(
                    '设为原生壁纸 (第 ${index + 1} 张)',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                _buildWallpaperOptionTile(
                  icon: Icons.wallpaper_rounded,
                  title: '设置为桌面壁纸',
                  onTap: () {
                    Navigator.pop(context);
                    _applyWallpaper(index, 1);
                  },
                  theme: theme,
                ),
                _buildWallpaperOptionTile(
                  icon: Icons.lock_rounded,
                  title: '设置为锁屏壁纸',
                  onTap: () {
                    Navigator.pop(context);
                    _applyWallpaper(index, 2);
                  },
                  theme: theme,
                ),
                _buildWallpaperOptionTile(
                  icon: Icons.phonelink_setup_rounded,
                  title: '同时设置为桌面与锁屏',
                  onTap: () {
                    Navigator.pop(context);
                    _applyWallpaper(index, 3);
                  },
                  theme: theme,
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWallpaperOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required ThemeData theme,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.primary.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: theme.colorScheme.primary),
      ),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      ),
      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
      onTap: onTap,
    );
  }

  Future<void> _applyWallpaper(int index, int type) async {
    String downloadUrl = '';
    if (_details != null && _details!.downloadUrls.length > index) {
      downloadUrl = _details!.downloadUrls[index];
    } else if (index == 0) {
      downloadUrl = _getHighResUrl(_currentImage.urls);
    } else {
      return;
    }

    final extension = downloadUrl.contains('.png') ? 'png' : 'jpg';
    final totalPages = int.tryParse(_currentImage.total ?? '') ?? (_details?.downloadUrls.length ?? 1);
    final filename = totalPages > 1
        ? '${_currentImage.id}_p$index.$extension'
        : '${_currentImage.id}.$extension';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
        content: SizedBox(
          width: MediaQuery.of(context).size.width * 0.85,
          child: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  '正在下载并应用壁纸...',
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    try {
      final savedPath = await DownloadHelper.downloadImage(
        downloadUrl,
        filename,
        onProgress: (received, total) {},
      );

      final success = await WallpaperService.setWallpaper(savedPath, type);

      if (mounted) {
        Navigator.pop(context); // Close dialog
        if (success) {
          _showNotification('壁纸设置成功！', type: 'success');
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Close dialog
        _showNotification('设置壁纸失败: $e', type: 'error');
      }
    }
  }

  void _handleShare(BuildContext context) {
    final RenderBox? box = context.findRenderObject() as RenderBox?;
    final String shareText = '分享二次元插画 (ID: ${_currentImage.id}) By ${_currentImage.category} @${_currentImage.cleanUser}\n网页链接: https://www.moely.link/img/${_currentImage.id}/';
    Share.share(
      shareText,
      sharePositionOrigin: box != null ? box.localToGlobal(Offset.zero) & box.size : null,
    );
  }

  void _openFullscreenViewer(List<String> urls, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrls: urls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPixiv = _currentImage.category.toLowerCase() == 'pixiv';
    final platformColor = theme.colorScheme.primary;

    // List of previews to display
    final List<String> previewsToDisplay = [];
    if (_isLoadingDetails || _details == null || _details!.previewUrls.isEmpty) {
      previewsToDisplay.add(_getHighResUrl(_currentImage.urls));
    } else {
      previewsToDisplay.addAll(_details!.previewUrls);
    }

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Listener(
        onPointerUp: (event) {
          _handleScrollRelease();
        },
        child: Stack(
          children: [
            // Dynamic scrolling view containing all illustrations and then metadata at the end (Pixiv-Style)
            Positioned.fill(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 60,
                  bottom: 100, // Room for FAB share and bottom spacing
                ),
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. List of illustrations stacked vertically (前面展示图片)
                  ...List.generate(previewsToDisplay.length, (index) {
                    final imgUrl = previewsToDisplay[index];

                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: Stack(
                        children: [
                          // Tap image to trigger immersive zoom view
                          GestureDetector(
                            onTap: () => _openFullscreenViewer(previewsToDisplay, index),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.08),
                                    blurRadius: 16,
                                    offset: const Offset(0, 4),
                                  )
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(20),
                                child: Hero(
                                  tag: index == 0 ? 'img_${_currentImage.id}' : 'img_${_currentImage.id}_p$index',
                                  child: imgUrl.isEmpty
                                      ? _buildPlaceholder(context, '', index, theme, platformColor)
                                      : CachedNetworkImage(
                                          imageUrl: imgUrl,
                                          httpHeaders: {'User-Agent': UserAgentService.userAgent},
                                          fit: BoxFit.fitWidth,
                                          placeholder: (context, url) => _buildPlaceholder(context, url, index, theme, platformColor),
                                          errorWidget: (context, url, error) => Container(
                                            height: 250,
                                            color: theme.colorScheme.surfaceVariant,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.broken_image_rounded, size: 48),
                                          ),
                                        ),
                                ),
                              ),
                            ),
                          ),

                          // 2. Action overlay on TOP-RIGHT of EACH image: Frosted Glass download/favorite/wallpaper capsule
                          Positioned(
                            top: 14,
                            right: 14,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(20),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  color: Colors.black.withOpacity(0.45),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Favorite Action
                                      GestureDetector(
                                        onTap: () => _toggleFavorite(imgUrl, index),
                                        child: ScaleTransition(
                                          scale: _heartScaleAnimation,
                                          child: const Icon(
                                            Icons.favorite_border_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Download Action
                                      GestureDetector(
                                        onTap: () => _handleDownload(index),
                                        child: const Icon(
                                          Icons.download_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 14),

                                      // Wallpaper Action
                                      GestureDetector(
                                        onTap: () => _showWallpaperOptions(index),
                                        child: const Icon(
                                          Icons.wallpaper_rounded,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // 3. Resolution overlay on BOTTOM-RIGHT of EACH image: Frosted Glass resolution badge
                          if (!_isLoadingDetails && _details != null && _details!.resolution.isNotEmpty)
                            Positioned(
                              bottom: 14,
                              right: 14,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: BackdropFilter(
                                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                    color: Colors.black.withOpacity(0.45),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.aspect_ratio_rounded,
                                          color: Colors.white,
                                          size: 13,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          _details!.resolution.replaceAll('原图尺寸：', ''),
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }),

                  // Multi-image Page indicator text helper if total > 1
                  if (previewsToDisplay.length > 1)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18.0, vertical: 4.0),
                      child: Text(
                        '共 ${previewsToDisplay.length} 张图片，滑动浏览，轻触图片可全屏双击缩放',
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),

                  const SizedBox(height: 16),

                  // 3. Metadata details & descriptions section at the end (最后显示描述，类似Pixiv)
                  _buildPixivDetailsCard(theme, platformColor),
                ],
              ),
            ),
          ),

          // Status bar background shield (so content doesn't bleed into status bar)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: MediaQuery.of(context).padding.top,
            child: Container(
              color: theme.colorScheme.background,
            ),
          ),

          // 4. Custom Sleek Transparent App Bar Header
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Back Button
                ClipOval(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                    child: Container(
                      width: 48,
                      height: 48,
                      color: theme.colorScheme.surface.withOpacity(0.6),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back_ios_new_rounded, color: theme.colorScheme.onSurface, size: 20),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                      child: Container(
                        height: 48,
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        color: theme.colorScheme.surface.withOpacity(0.6),
                        child: Text(
                          _getDisplayTitle(),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 5. Floating Share Button (右下角显示一个悬浮的分享按钮)
          Positioned(
            right: 20,
            bottom: 24,
            child: FloatingActionButton(
              onPressed: () => _handleShare(context),
              backgroundColor: platformColor,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              elevation: 6,
              child: const Icon(Icons.share_rounded),
            ),
          ),

          // 6. Top Overscroll Indicator (Return to previous)
          if (_overscrollTop > 5 && _hasPrevImage)
            Positioned(
              top: MediaQuery.of(context).padding.top + 80,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: (math.min(_overscrollTop, 100.0) / 100.0),
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * (math.min(_overscrollTop, 100.0) / 100.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: platformColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_downward_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _overscrollTop >= 100 ? '释放以返回上一张' : '继续下拉返回上一张 (${_overscrollTop.toInt()}/100)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

          // 7. Bottom Overscroll Indicator (Random next image)
          if (_overscrollBottom > 5)
            Positioned(
              bottom: 110,
              left: 0,
              right: 0,
              child: Center(
                child: Opacity(
                  opacity: (math.min(_overscrollBottom, 100.0) / 100.0),
                  child: Transform.scale(
                    scale: 0.8 + 0.2 * (math.min(_overscrollBottom, 100.0) / 100.0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        color: platformColor,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.2),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          )
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.arrow_upward_rounded, size: 16, color: Colors.white),
                          const SizedBox(width: 8),
                          Text(
                            _overscrollBottom >= 100 ? '释放以探索随机图片' : '继续上拉探索随机图片 (${_overscrollBottom.toInt()}/100)',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

  Widget _buildPixivDetailsCard(ThemeData theme, Color platformColor) {
    const Map<String, String> languageNames = {
      'zh-CN': '中文(简体)',
      'zh-TW': '中文(繁体)',
      'en': '英语',
      'ja': '日语',
      'ko': '韩语',
    };

    final targetLangName = languageNames[AppSettings.instance.translationLanguage] ?? '中文';
    final engineName = AppSettings.instance.translationEngine == 'google' ? '谷歌翻译' : '微软翻译';

    return Container(
      margin: const EdgeInsets.all(16.0),
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24.0),
        border: Border.all(
          color: theme.colorScheme.onSurface.withOpacity(0.06),
        ),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withOpacity(0.04),
            blurRadius: 20,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ID Title & Source Launch Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _getDisplayTitle(),
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (!_isLoadingDetails && _details != null && _details!.sourceUrl.isNotEmpty)
                IconButton.filledTonal(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => DenoisedWebScreen(
                          url: _details!.sourceUrl,
                          title: '原始出处',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.launch_rounded),
                  style: IconButton.styleFrom(
                    foregroundColor: platformColor,
                    backgroundColor: platformColor.withOpacity(0.1),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          // Creator & Platform badges row
          Row(
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: 14,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  _currentImage.cleanUser,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface.withOpacity(0.8),
                  ),
                ),
              ),
              InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => CategoryGridScreen(
                        categoryCode: _currentImage.category.toLowerCase(),
                        title: _currentImage.category,
                      ),
                    ),
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: platformColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: platformColor.withOpacity(0.3)),
                  ),
                  child: Text(
                    _currentImage.category,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: platformColor,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(height: 1),
          ),

          // Illustration Description (直接渲染文本，去掉多余卡片)
          Text(
            '作品描述',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _isLoadingDetails 
              ? Text(
                  '获取描述中...',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.85),
                  ),
                )
              : _buildClickableDescription(
                  (_isTranslated && _translatedDescription.isNotEmpty)
                      ? _translatedDescription
                      : _details?.description ?? '暂无描述',
                  theme,
                ),

          // Twitter-Style Minimalist Translation Trigger
          if (!_isLoadingDetails && 
              _details != null && 
              AppSettings.instance.enableTranslation) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: _isTranslating
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 1.5),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '正在翻译...',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    )
                  : InkWell(
                      onTap: _handleTranslation,
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.translate_rounded,
                              size: 13,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _isTranslated ? '显示原文' : '翻译简介和标签为$targetLangName',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            if (_isTranslated) ...[
                              const SizedBox(width: 6),
                              Text(
                                '(由$engineName提供)',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ],

          const SizedBox(height: 20),

          // Illustration Tags List
          Text(
            '插画标签',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          _isLoadingDetails
              ? const Center(child: CircularProgressIndicator())
              : _buildTagsChipCloud(theme),
        ],
      ),
    );
  }

  Widget _buildClickableDescription(String text, ThemeData theme) {
    if (text.isEmpty) return const SizedBox.shrink();

    final List<InlineSpan> spans = [];
    final linkRegex = RegExp(r'\[([^\]]+)\]\(([^)]+)\)');
    
    int lastIdx = 0;
    final matches = linkRegex.allMatches(text);
    
    for (final match in matches) {
      // 1. Add plain text before match
      if (match.start > lastIdx) {
        spans.add(TextSpan(
          text: text.substring(lastIdx, match.start),
          style: TextStyle(
            fontSize: 13,
            height: 1.5,
            color: theme.colorScheme.onSurface.withOpacity(0.85),
          ),
        ));
      }
      
      // 2. Add clickable link
      final linkText = match.group(1) ?? '';
      final url = match.group(2) ?? '';
      
      spans.add(TextSpan(
        text: linkText,
        style: TextStyle(
          fontSize: 13,
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.underline,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () {
            UrlHandlerService.handleUrl(context, url);
          },
      ));
      
      lastIdx = match.end;
    }
    
    // 3. Add remaining text
    if (lastIdx < text.length) {
      spans.add(TextSpan(
        text: text.substring(lastIdx),
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: theme.colorScheme.onSurface.withOpacity(0.85),
        ),
      ));
    }
    
    return RichText(
      text: TextSpan(children: spans),
    );
  }

  Widget _buildTagsChipCloud(ThemeData theme) {
    if (_details == null || _details!.tags.isEmpty) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const TagGridScreen(tag: '暂无标签'),
              ),
            );
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
            ),
            child: Text(
              '#暂无标签',
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }

    final List<String> translatedTagList = _isTranslated && _translatedTags.isNotEmpty
        ? _translatedTags.split(RegExp(r'[,，、]+')).map((s) => s.trim()).toList()
        : [];

    int index = 0;

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _details!.tags.map((tag) {
        final isClickable = !tag.endsWith('|nolink');
        final currentIdx = index++;

        // Determine the display tag text
        String displayTag;
        if (_isTranslated && translatedTagList.length > currentIdx && translatedTagList[currentIdx].isNotEmpty) {
          final translatedText = translatedTagList[currentIdx];
          displayTag = translatedText.startsWith('#') ? translatedText : '#$translatedText';
        } else {
          if (tag.contains('|slug:')) {
            displayTag = tag.split('|slug:').first;
          } else {
            displayTag = tag.replaceAll('|nolink', '');
          }
        }

        final cleanTag = displayTag.replaceAll('#', '');
        
        String targetSlug;
        if (tag.contains('|slug:')) {
          targetSlug = tag.split('|slug:').last;
        } else {
          targetSlug = cleanTag;
        }

        if (isClickable) {
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TagGridScreen(tag: targetSlug, displayName: cleanTag),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: theme.colorScheme.primary.withOpacity(0.12)),
                ),
                child: Text(
                  displayTag,
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          );
        } else {
          // Muted non-clickable style
          return Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: theme.colorScheme.onSurface.withOpacity(0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.1)),
            ),
            child: Text(
              displayTag,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withOpacity(0.55),
                fontWeight: FontWeight.w500,
              ),
            ),
          );
        }
      }).toList(),
    );
  }
}


/// Fully Immersive fullscreen swipeable & zoomable view for illustration lists
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Pager with zoomable interactive viewer for each image
          Positioned.fill(
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.imageUrls.length,
              onPageChanged: (idx) {
                setState(() {
                  _currentIndex = idx;
                });
              },
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: Center(
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrls[index],
                      httpHeaders: {'User-Agent': UserAgentService.userAgent},
                      fit: BoxFit.contain,
                      placeholder: (context, url) => const CircularProgressIndicator(color: Colors.white70),
                      errorWidget: (context, url, error) => const Icon(Icons.broken_image_rounded, color: Colors.white38, size: 48),
                    ),
                  ),
                );
              },
            ),
          ),

          // Fullscreen Header: Back button & Page Indicator
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            right: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ClipOval(
                  child: Container(
                    color: Colors.black45,
                    child: IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
                if (widget.imageUrls.length > 1)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black45,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_currentIndex + 1} / ${widget.imageUrls.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                const SizedBox(width: 48), // spacer balance
              ],
            ),
          ),
        ],
      ),
    );
  }
}
