import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../utils/cache_helper.dart';
import '../utils/download_helper.dart';
import '../services/settings_service.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:open_filex/open_filex.dart';

// Helper to interpolate double values smoothly
double lerpDouble(double start, double end, double t) {
  return start + (end - start) * t;
}

// ==========================================
// 1. 缓存管理内页 (Telegram 极简设计)
// ==========================================
class CacheManagementScreen extends StatefulWidget {
  const CacheManagementScreen({super.key});

  @override
  State<CacheManagementScreen> createState() => _CacheManagementScreenState();
}

class _CacheManagementScreenState extends State<CacheManagementScreen> with TickerProviderStateMixin {
  int _imagesSize = 0;
  int _detailsSize = 0;
  int _indexSize = 0;
  int _favoritesSize = 0;
  int _webviewSize = 0;
  int _otherSize = 0;
  bool _isLoading = true;

  // Selected categories to clear
  final Map<String, bool> _selected = {
    'images': true,
    'details': true,
    'index': true,
    'favorites': true,
    'webview': true,
    'other': true,
  };

  late AnimationController _initialScaleController;
  late Animation<double> _chartScaleAnimation;

  // Animation controller for smooth segment value transitions
  late AnimationController _chartValuesController;
  
  double _oldImagesVal = 0.0;
  double _targetImagesVal = 0.0;
  
  double _oldDetailsVal = 0.0;
  double _targetDetailsVal = 0.0;
  
  double _oldIndexVal = 0.0;
  double _targetIndexVal = 0.0;
  
  double _oldFavoritesVal = 0.0;
  double _targetFavoritesVal = 0.0;

  double _oldWebviewVal = 0.0;
  double _targetWebviewVal = 0.0;
  
  double _oldOtherVal = 0.0;
  double _targetOtherVal = 0.0;

  @override
  void initState() {
    super.initState();
    
    _initialScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _chartScaleAnimation = CurvedAnimation(
      parent: _initialScaleController,
      curve: Curves.easeOutBack,
    );

    _chartValuesController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    
    _loadSizes();
  }

  @override
  void dispose() {
    _initialScaleController.dispose();
    _chartValuesController.dispose();
    super.dispose();
  }

  Future<void> _loadSizes() async {
    setState(() {
      _isLoading = true;
    });

    final imgDir = await CacheHelper.getImagesCacheDir();
    final detDir = await CacheHelper.getDetailsCacheDir();
    final idxDir = await CacheHelper.getIndexCacheDir();
    final favDir = await CacheHelper.getFavoritesCacheDir();
    final webDir = await CacheHelper.getWebViewCacheDir();

    final imgS = await CacheHelper.getDirSize(imgDir);
    final detS = await CacheHelper.getDirSize(detDir);
    final idxS = await CacheHelper.getDirSize(idxDir);
    final favS = await CacheHelper.getDirSize(favDir);
    final webS = await CacheHelper.getDirSize(webDir);

    // Calculate other files (excluding isolated system and user directories)
    final docDir = await getApplicationDocumentsDirectory();
    final supportDir = await getApplicationSupportDirectory();
    final tempDir = await getTemporaryDirectory();
    final parentDir = tempDir.parent;
    
    // 1. Scan code_cache (Android V8 compilation shader & bytecode cache)
    int codeCacheS = 0;
    final codeCacheDir = Directory('${parentDir.path}/code_cache');
    if (codeCacheDir.existsSync()) {
      codeCacheS = await CacheHelper.getDirSize(codeCacheDir);
    }

    // 2. Scan the rest of tempDir (excluding libCachedImageData and WebView)
    int restTempS = 0;
    if (tempDir.existsSync()) {
      try {
        final List<FileSystemEntity> files = tempDir.listSync(recursive: true);
        for (final FileSystemEntity file in files) {
          if (file is File) {
            final path = file.path;
            if (path.contains('libCachedImageData') || path.contains('WebView')) {
              continue;
            }
            restTempS += file.lengthSync();
          }
        }
      } catch (_) {}
    }
    
    final excludedFolders = [
      detDir.path,
      idxDir.path,
      favDir.path,
      '${supportDir.path}/settings',
      '${supportDir.path}/MoelyDownloads',
      '${docDir.path}/MoelyDownloads',
    ];
    final customDownloadPath = AppSettings.instance.downloadPath;
    if (customDownloadPath.isNotEmpty) {
      excludedFolders.add(customDownloadPath);
    }
    
    int otherS = codeCacheS + restTempS;
    
    void calculateOtherCacheSize(Directory dir) {
      if (!dir.existsSync()) return;
      try {
        final list = dir.listSync(recursive: true);
        for (final entity in list) {
          if (entity is File) {
            final path = entity.path;
            
            // Check if file is in any excluded folders
            bool isExcluded = false;
            for (final folder in excludedFolders) {
              if (path.startsWith(folder)) {
                isExcluded = true;
                break;
              }
            }
            if (isExcluded) continue;
            
            // Also exclude app_settings.json in docDir root (for backward compatible/migrating states)
            final name = p.basename(path);
            if (name == 'app_settings.json') {
              continue;
            }
            
            // Exclude SQLite databases
            final ext = p.extension(path).toLowerCase();
            if (ext == '.db' || ext == '.db-shm' || ext == '.db-wal') {
              continue;
            }
            
            // Otherwise, it is a miscellaneous cache file
            otherS += entity.lengthSync();
          }
        }
      } catch (_) {}
    }

    calculateOtherCacheSize(docDir);
    calculateOtherCacheSize(supportDir);

    if (mounted) {
      setState(() {
        _imagesSize = imgS;
        _detailsSize = detS;
        _indexSize = idxS;
        _favoritesSize = favS;
        _webviewSize = webS;
        _otherSize = otherS;
        _isLoading = false;

        // Initialize target and old values for smooth pie chart animations
        _targetImagesVal = _selected['images'] == true ? imgS.toDouble() : 0.0;
        _targetDetailsVal = _selected['details'] == true ? detS.toDouble() : 0.0;
        _targetIndexVal = _selected['index'] == true ? idxS.toDouble() : 0.0;
        _targetFavoritesVal = _selected['favorites'] == true ? favS.toDouble() : 0.0;
        _targetWebviewVal = _selected['webview'] == true ? webS.toDouble() : 0.0;
        _targetOtherVal = _selected['other'] == true ? otherS.toDouble() : 0.0;

        _oldImagesVal = _targetImagesVal;
        _oldDetailsVal = _targetDetailsVal;
        _oldIndexVal = _targetIndexVal;
        _oldFavoritesVal = _targetFavoritesVal;
        _oldWebviewVal = _targetWebviewVal;
        _oldOtherVal = _targetOtherVal;
      });
      _initialScaleController.forward(from: 0.0);
      _chartValuesController.forward(from: 1.0);
    }
  }

  void _toggleCategory(String key) {
    setState(() {
      final isChecked = !(_selected[key] ?? false);
      _selected[key] = isChecked;

      // Capture current animated position as the start of the next animation
      final progress = _chartValuesController.value;
      _oldImagesVal = lerpDouble(_oldImagesVal, _targetImagesVal, progress);
      _oldDetailsVal = lerpDouble(_oldDetailsVal, _targetDetailsVal, progress);
      _oldIndexVal = lerpDouble(_oldIndexVal, _targetIndexVal, progress);
      _oldFavoritesVal = lerpDouble(_oldFavoritesVal, _targetFavoritesVal, progress);
      _oldWebviewVal = lerpDouble(_oldWebviewVal, _targetWebviewVal, progress);
      _oldOtherVal = lerpDouble(_oldOtherVal, _targetOtherVal, progress);

      // Define new target positions
      _targetImagesVal = _selected['images'] == true ? _imagesSize.toDouble() : 0.0;
      _targetDetailsVal = _selected['details'] == true ? _detailsSize.toDouble() : 0.0;
      _targetIndexVal = _selected['index'] == true ? _indexSize.toDouble() : 0.0;
      _targetFavoritesVal = _selected['favorites'] == true ? _favoritesSize.toDouble() : 0.0;
      _targetWebviewVal = _selected['webview'] == true ? _webviewSize.toDouble() : 0.0;
      _targetOtherVal = _selected['other'] == true ? _otherSize.toDouble() : 0.0;

      // Run smooth transition
      _chartValuesController.forward(from: 0.0);
    });
  }

  Future<void> _clearSelected() async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        content: const Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 20),
            Text('正在清理选中缓存...', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );

    if (_selected['images'] == true) {
      final dir = await CacheHelper.getImagesCacheDir();
      await CacheHelper.clearDir(dir);
    }
    if (_selected['details'] == true) {
      final dir = await CacheHelper.getDetailsCacheDir();
      await CacheHelper.clearDir(dir);
    }
    if (_selected['index'] == true) {
      final dir = await CacheHelper.getIndexCacheDir();
      await CacheHelper.clearDir(dir);
    }
    if (_selected['favorites'] == true) {
      final dir = await CacheHelper.getFavoritesCacheDir();
      await CacheHelper.clearDir(dir);
    }
    if (_selected['webview'] == true) {
      final dir = await CacheHelper.getWebViewCacheDir();
      await CacheHelper.clearDir(dir);
    }
    if (_selected['other'] == true) {
      try {
        final docDir = await getApplicationDocumentsDirectory();
        final supportDir = await getApplicationSupportDirectory();
        final tempDir = await getTemporaryDirectory();
        
        final detDir = await CacheHelper.getDetailsCacheDir();
        final idxDir = await CacheHelper.getIndexCacheDir();
        final favDir = await CacheHelper.getFavoritesCacheDir();

        final excludedFolders = [
          detDir.path,
          idxDir.path,
          favDir.path,
          '${supportDir.path}/settings',
          '${supportDir.path}/MoelyDownloads',
          '${docDir.path}/MoelyDownloads',
        ];
        final customDownloadPath = AppSettings.instance.downloadPath;
        if (customDownloadPath.isNotEmpty) {
          excludedFolders.add(customDownloadPath);
        }

        // 1. Clear other files in docDir and supportDir
        void clearOtherCacheFiles(Directory dir) {
          if (!dir.existsSync()) return;
          try {
            final List<FileSystemEntity> files = dir.listSync(recursive: true);
            for (final file in files) {
              if (file is File) {
                final path = file.path;
                
                // Check if file is in any excluded folders
                bool isExcluded = false;
                for (final folder in excludedFolders) {
                  if (path.startsWith(folder)) {
                    isExcluded = true;
                    break;
                  }
                }
                if (isExcluded) continue;
                
                // Also exclude app_settings.json in docDir root (for backward compatible/migrating states)
                final name = p.basename(path);
                if (name == 'app_settings.json') {
                  continue;
                }
                
                // Exclude SQLite databases
                final ext = p.extension(path).toLowerCase();
                if (ext == '.db' || ext == '.db-shm' || ext == '.db-wal') {
                  continue;
                }
                
                // Safe to delete other miscellaneous cache files
                file.deleteSync();
              }
            }
          } catch (_) {}
        }

        clearOtherCacheFiles(docDir);
        clearOtherCacheFiles(supportDir);

        // 2. Clear code_cache (V8 compile and shader bytecode caches)
        final codeCacheDir = Directory('${tempDir.parent.path}/code_cache');
        if (codeCacheDir.existsSync()) {
          try {
            final List<FileSystemEntity> files = codeCacheDir.listSync(recursive: true);
            for (final file in files) {
              if (file is File) {
                file.deleteSync();
              }
            }
          } catch (_) {}
        }

        // 3. Clear rest of tempDir (excluding images and WebView caches)
        if (tempDir.existsSync()) {
          try {
            final List<FileSystemEntity> files = tempDir.listSync(recursive: true);
            for (final file in files) {
              if (file is File) {
                final path = file.path;
                if (path.contains('libCachedImageData') || path.contains('WebView')) {
                  continue;
                }
                file.deleteSync();
              }
            }
          } catch (_) {}
        }
      } catch (_) {}
    }

    if (mounted) {
      Navigator.pop(context); // Close dialog
      final theme = Theme.of(context);
      final isDark = theme.brightness == Brightness.dark;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                Icons.check_circle_rounded, 
                color: isDark ? Colors.greenAccent : const Color(0xFF10B981),
              ),
              const SizedBox(width: 8),
              Text(
                '清理完成！已经释放磁盘空间。',
                style: TextStyle(
                  color: isDark ? theme.colorScheme.onSurface : theme.colorScheme.onInverseSurface,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          backgroundColor: isDark ? theme.colorScheme.surfaceVariant : theme.colorScheme.inverseSurface,
        ),
      );
      _loadSizes();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final totalSize = _imagesSize + _detailsSize + _indexSize + _favoritesSize + _webviewSize + _otherSize;
    
    // Sum of selected items (for dynamic button display)
    int selectedSize = 0;
    if (_selected['images'] == true) selectedSize += _imagesSize;
    if (_selected['details'] == true) selectedSize += _detailsSize;
    if (_selected['index'] == true) selectedSize += _indexSize;
    if (_selected['favorites'] == true) selectedSize += _favoritesSize;
    if (_selected['webview'] == true) selectedSize += _webviewSize;
    if (_selected['other'] == true) selectedSize += _otherSize;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.onSurface),
            onPressed: _loadSizes,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 10),
                  // Donut Pie Chart Container with dynamic Smooth Value Animation!
                  ScaleTransition(
                    scale: _chartScaleAnimation,
                    child: Container(
                      height: 220,
                      alignment: Alignment.center,
                      child: AnimatedBuilder(
                        animation: _chartValuesController,
                        builder: (context, child) {
                          final t = CurvedAnimation(
                            parent: _chartValuesController,
                            curve: Curves.easeInOutCubic,
                          ).value;

                          // Interpolate all sizes in real-time
                          final currentImages = lerpDouble(_oldImagesVal, _targetImagesVal, t);
                          final currentDetails = lerpDouble(_oldDetailsVal, _targetDetailsVal, t);
                          final currentIndex = lerpDouble(_oldIndexVal, _targetIndexVal, t);
                          final currentFavorites = lerpDouble(_oldFavoritesVal, _targetFavoritesVal, t);
                          final currentWebview = lerpDouble(_oldWebviewVal, _targetWebviewVal, t);
                          final currentOther = lerpDouble(_oldOtherVal, _targetOtherVal, t);

                          final currentSelectedSize = (currentImages + currentDetails + currentIndex + currentFavorites + currentWebview + currentOther).round();

                          // Format dynamic text inside the pie chart center
                          String sizeValue = "0";
                          String sizeUnit = "B";
                          if (currentSelectedSize > 0) {
                            final formatted = CacheHelper.formatSize(currentSelectedSize);
                            final parts = formatted.split(" ");
                            if (parts.length >= 2) {
                              sizeValue = parts[0];
                              sizeUnit = parts[1];
                            }
                          }

                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              CustomPaint(
                                size: const Size(200, 200),
                                painter: DonutChartPainter(
                                  imagesVal: currentImages,
                                  detailsVal: currentDetails,
                                  indexVal: currentIndex,
                                  favoritesVal: currentFavorites,
                                  webviewVal: currentWebview,
                                  otherVal: currentOther,
                                  centerBgColor: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
                                ),
                              ),
                              Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    sizeValue,
                                    style: const TextStyle(
                                      fontSize: 36,
                                      fontWeight: FontWeight.w900,
                                      letterSpacing: -1,
                                    ),
                                  ),
                                  Text(
                                    sizeUnit,
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    ),
                                  ),
                                ],
                              )
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title & Subtitle under Pie Chart
                  Center(
                    child: Text(
                      '存储使用情况',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      '萌哩已占用您设备 <1.0% 的存储空间。',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Device Storage horizontal Progress Bar
                  Center(
                    child: Container(
                      height: 6,
                      width: 200,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: Row(
                          children: [
                            // 1. Moely occupied space (themed color)
                            Expanded(
                              flex: 12,
                              child: Container(
                                color: theme.colorScheme.primary,
                              ),
                            ),
                            // 2. Other apps occupied space (light themed color - secondaryContainer)
                            Expanded(
                              flex: 58,
                              child: Container(
                                color: theme.colorScheme.secondaryContainer,
                              ),
                            ),
                            // 3. Free space (transparent/background of the bar)
                            Expanded(
                              flex: 30,
                              child: Container(
                                color: Colors.transparent,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Legend row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _buildLegendItem(theme, '萌哩', theme.colorScheme.primary),
                      const SizedBox(width: 16),
                      _buildLegendItem(theme, '其他应用', theme.colorScheme.secondaryContainer),
                      const SizedBox(width: 16),
                      _buildLegendItem(theme, '系统与剩余', theme.colorScheme.onSurface.withOpacity(0.15)),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Telegram-style Unified Card
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        _buildCategoryRow(
                          key: 'images',
                          title: '图片文件',
                          size: _imagesSize,
                          totalSize: totalSize,
                          color: const Color(0xFF4CD0E1), // Cyan/Blue
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildCategoryRow(
                          key: 'details',
                          title: '图片信息',
                          size: _detailsSize,
                          totalSize: totalSize,
                          color: const Color(0xFFAB47BC), // Purple
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildCategoryRow(
                          key: 'index',
                          title: '索引数据',
                          size: _indexSize,
                          totalSize: totalSize,
                          color: const Color(0xFF66BB6A), // Green
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildCategoryRow(
                          key: 'favorites',
                          title: '图片收藏',
                          size: _favoritesSize,
                          totalSize: totalSize,
                          color: const Color(0xFFFF7043), // Orange/Pink
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildCategoryRow(
                          key: 'webview',
                          title: '网页缓存', // WebView Cache split out
                          size: _webviewSize,
                          totalSize: totalSize,
                          color: const Color(0xFFEC407A), // Deep Pink for WebView
                          theme: theme,
                        ),
                        _buildDivider(isDark),
                        _buildCategoryRow(
                          key: 'other',
                          title: '其他数据',
                          size: _otherSize,
                          totalSize: totalSize,
                          color: const Color(0xFFFFCA28), // Yellow
                          theme: theme,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Capsule Clearing Button
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: selectedSize > 0 ? _clearSelected : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(26),
                        ),
                      ),
                      child: Text(
                        '清空缓存 ${CacheHelper.formatSize(selectedSize)}',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Bottom explanatory text
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        '所有已缓存的图片文件及网页缓存数据，在您下一次浏览访问时均可从网络重新加载。',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.4,
                          color: theme.colorScheme.onSurface.withOpacity(0.4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildDivider(bool isDark) {
    return Divider(
      height: 1,
      thickness: 1,
      color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
      indent: 56,
      endIndent: 16,
    );
  }

  Widget _buildLegendItem(ThemeData theme, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withOpacity(0.6),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryRow({
    required String key,
    required String title,
    required int size,
    required int totalSize,
    required Color color,
    required ThemeData theme,
  }) {
    final isChecked = _selected[key] ?? false;
    final percentage = totalSize > 0 ? (size / totalSize * 100).round() : 0;

    return InkWell(
      onTap: () => _toggleCategory(key),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            // Circular Colored Checkbox Icon (Exactly like Telegram screenshot!)
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: isChecked ? color : Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isChecked ? color : theme.colorScheme.onSurface.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: isChecked
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : null,
            ),
            const SizedBox(width: 16),
            
            // Title & Percentage
            Expanded(
              child: Row(
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$percentage%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                    ),
                  ),
                ],
              ),
            ),

            // Size value
            Text(
              CacheHelper.formatSize(size),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// Donut Pie Chart Painter (Telegram Style)
// ==========================================
class DonutChartPainter extends CustomPainter {
  final double imagesVal;
  final double detailsVal;
  final double indexVal;
  final double favoritesVal;
  final double webviewVal;
  final double otherVal;
  final Color centerBgColor;

  DonutChartPainter({
    required this.imagesVal,
    required this.detailsVal,
    required this.indexVal,
    required this.favoritesVal,
    required this.webviewVal,
    required this.otherVal,
    required this.centerBgColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double total = imagesVal + detailsVal + indexVal + favoritesVal + webviewVal + otherVal;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: radius - 15);
    const strokeWidth = 30.0;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Draw central black/dark backing circle
    final bgCirclePaint = Paint()
      ..color = centerBgColor
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius - 30, bgCirclePaint);

    if (total == 0) {
      paint.color = Colors.grey.withOpacity(0.15);
      canvas.drawArc(rect, 0, 2 * math.pi, false, paint);
      return;
    }

    final segments = [
      _Segment('images', imagesVal, const Color(0xFF4CD0E1)),
      _Segment('details', detailsVal, const Color(0xFFAB47BC)),
      _Segment('index', indexVal, const Color(0xFF66BB6A)),
      _Segment('favorites', favoritesVal, const Color(0xFFFF7043)),
      _Segment('webview', webviewVal, const Color(0xFFEC407A)),
      _Segment('other', otherVal, const Color(0xFFFFCA28)),
    ];

    double currentAngle = -math.pi / 2;

    // 1. Draw Arcs with separation gap
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final double sweepAngle = (seg.value / total) * 2 * math.pi;

      paint.color = seg.color;
      
      // Subtract a very tiny angle to leave a clean space between segments (exactly like Telegram!)
      final double gap = 0.04;
      final start = currentAngle + gap / 2;
      final sweep = sweepAngle - gap;
      
      if (sweep > 0) {
        canvas.drawArc(rect, start, sweep, false, paint);
      }
      
      currentAngle += sweepAngle;
    }

    // 2. Draw Percentage text directly inside the segments
    currentAngle = -math.pi / 2;
    for (final seg in segments) {
      if (seg.value <= 0) continue;
      final double sweepAngle = (seg.value / total) * 2 * math.pi;
      final int percentage = (seg.value / total * 100).round();

      // Only draw percentage labels inside segments that are large enough to fit them (>= 5%)
      if (percentage >= 5) {
        final double middleAngle = currentAngle + sweepAngle / 2;
        final double textRadius = radius - 15; // exactly in the center of the ring's stroke
        final double labelX = center.dx + textRadius * math.cos(middleAngle);
        final double labelY = center.dy + textRadius * math.sin(middleAngle);

        final textPainter = TextPainter(
          text: TextSpan(
            text: '$percentage%',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
          textDirection: TextDirection.ltr,
        );
        textPainter.layout();
        
        // Center the text inside the segment
        textPainter.paint(
          canvas,
          Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2),
        );
      }

      currentAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _Segment {
  final String key;
  final double value;
  final Color color;
  _Segment(this.key, this.value, this.color);
}


// ==========================================
// 2. 下载管理器内页 (支持任务状态、暂停、继续、删除与物理删除)
// ==========================================
class DownloadManagementScreen extends StatefulWidget {
  const DownloadManagementScreen({super.key});

  @override
  State<DownloadManagementScreen> createState() => _DownloadManagementScreenState();
}

class _DownloadManagementScreenState extends State<DownloadManagementScreen> {
  List<File> _downloadedFiles = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _scanDownloadedFiles();
    // Register listeners on any running tasks
    for (final task in DownloadHelper.activeTasks) {
      task.onStateChanged = () {
        if (mounted) setState(() {});
      };
    }
  }

  Future<void> _scanDownloadedFiles() async {
    setState(() {
      _isLoading = true;
    });

    final List<File> files = [];
    try {
      final downloadDir = await DownloadHelper.getDownloadDirectory();
      if (downloadDir.existsSync()) {
        final List<FileSystemEntity> list = downloadDir.listSync(recursive: false);
        for (final entity in list) {
          if (entity is File) {
            final ext = p.extension(entity.path).toLowerCase();
            if (ext == '.jpg' || ext == '.jpeg' || ext == '.png' || ext == '.gif' || ext == '.webp') {
              files.add(entity);
            }
          }
        }
        // Sort files by modified time descending (newest downloads at top)
        files.sort((a, b) => b.lastModifiedSync().compareTo(a.lastModifiedSync()));
      }
    } catch (e) {
      debugPrint('Failed to scan download directory: $e');
    }

    if (mounted) {
      setState(() {
        _downloadedFiles = files;
        _isLoading = false;
      });
    }
  }

  void _pauseTask(DownloadTask task) {
    DownloadHelper.pauseTask(task);
    setState(() {});
  }

  void _resumeTask(DownloadTask task) {
    DownloadHelper.resumeTask(task, onDone: () {
      if (mounted) {
        setState(() {});
        _scanDownloadedFiles();
      }
    });
    setState(() {});
  }

  void _confirmDelete({File? file, DownloadTask? activeTask}) {
    bool deleteLocal = false;
    final filename = file != null ? p.basename(file.path) : activeTask!.filename;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent),
                  SizedBox(width: 8),
                  Text('确认删除', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('您确定要从下载任务列表中删除此项目吗？'),
                  const SizedBox(height: 8),
                  Text(
                    filename,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (file != null)
                    CheckboxListTile(
                      value: deleteLocal,
                      onChanged: (val) {
                        setDialogState(() {
                          deleteLocal = val ?? true;
                        });
                      },
                      activeColor: theme.colorScheme.primary,
                      title: const Text('同时删除本地物理存储的文件', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      controlAffinity: ListTileControlAffinity.leading,
                      contentPadding: EdgeInsets.zero,
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    Navigator.pop(context); // Close dialog

                    if (activeTask != null) {
                      DownloadHelper.pauseTask(activeTask);
                      DownloadHelper.activeTasks.remove(activeTask);
                    }

                    if (file != null && deleteLocal) {
                      try {
                        if (file.existsSync()) {
                          await file.delete();
                        }
                      } catch (e) {
                        debugPrint('Delete physical file failed: $e');
                      }
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text('已成功删除下载项'),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    );

                    _scanDownloadedFiles();
                  },
                  child: const Text('确认删除'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeTasks = DownloadHelper.activeTasks;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      appBar: AppBar(
        title: const Text('下载管理器', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _scanDownloadedFiles,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : CustomScrollView(
              slivers: [
                // 1. Active Tasks Section
                if (activeTasks.isNotEmpty) ...[
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    sliver: SliverToBoxAdapter(
                      child: Text(
                        '正在下载中的任务 (${activeTasks.length})',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final task = activeTasks[index];
                          // Bind state changed listener to trigger setState
                          task.onStateChanged = () {
                            if (mounted) setState(() {});
                          };

                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          task.status == 'running'
                                              ? Icons.cloud_download_rounded
                                              : Icons.pause_circle_filled_rounded,
                                          color: theme.colorScheme.primary,
                                          size: 20,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              task.filename,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              task.status == 'running' ? '正在连接并下载中...' : '已暂停',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: theme.colorScheme.onSurface.withOpacity(0.5),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Action controllers
                                      if (task.status == 'running')
                                        IconButton(
                                          icon: const Icon(Icons.pause_rounded, color: Colors.blueAccent),
                                          onPressed: () => _pauseTask(task),
                                        )
                                      else
                                        IconButton(
                                          icon: const Icon(Icons.play_arrow_rounded, color: Colors.green),
                                          onPressed: () => _resumeTask(task),
                                        ),
                                      IconButton(
                                        icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                        onPressed: () => _confirmDelete(activeTask: task),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  // Live progress bar
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(4),
                                    child: LinearProgressIndicator(
                                      value: task.progress,
                                      minHeight: 5,
                                      backgroundColor: theme.colorScheme.onSurface.withOpacity(0.08),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Align(
                                    alignment: Alignment.centerRight,
                                    child: Text(
                                      '${(task.progress * 100).toStringAsFixed(1)}%',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: theme.colorScheme.primary,
                                      ),
                                    ),
                                  )
                                ],
                              ),
                            ),
                          );
                        },
                        childCount: activeTasks.length,
                      ),
                    ),
                  ),
                ],

                // 2. Downloaded Files List
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      '已下载的插画大图 (${_downloadedFiles.length})',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),

                _downloadedFiles.isEmpty
                    ? const SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.download_done_rounded, size: 48, color: Colors.grey),
                              SizedBox(height: 12),
                              Text('暂无下载完成的插画大图', style: TextStyle(color: Colors.grey, fontSize: 13)),
                            ],
                          ),
                        ),
                      )
                    : SliverPadding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
                        sliver: SliverList(
                          delegate: SliverChildBuilderDelegate(
                            (context, index) {
                              final file = _downloadedFiles[index];
                              final filename = p.basename(file.path);
                              final fileStats = file.statSync();
                              final sizeString = CacheHelper.formatSize(fileStats.size);
                              final modifiedDate = fileStats.modified;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(18),
                                  onTap: () async {
                                    bool opened = false;
                                    try {
                                      final result = await OpenFilex.open(file.path);
                                      opened = result.type == ResultType.done;
                                    } catch (e) {
                                      debugPrint('open_filex failed: $e');
                                    }

                                    if (!opened && context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: const Text('系统限制无法直接打开，已将路径复制到剪贴板'),
                                          behavior: SnackBarBehavior.floating,
                                          action: SnackBarAction(
                                            label: '复制路径',
                                            onPressed: () {
                                              Clipboard.setData(ClipboardData(text: file.path));
                                            },
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Row(
                                      children: [
                                        // Beautiful local preview image thumbnail (UX detail!)
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            width: 54,
                                            height: 54,
                                            color: theme.colorScheme.surfaceVariant,
                                            child: Image.file(
                                              file,
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Icon(Icons.broken_image_rounded, size: 24),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                filename,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                              const SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Text(
                                                    sizeString,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight: FontWeight.bold,
                                                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Text(
                                                    '${modifiedDate.year}-${modifiedDate.month.toString().padLeft(2, '0')}-${modifiedDate.day.toString().padLeft(2, '0')}',
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      color: theme.colorScheme.onSurface.withOpacity(0.4),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                        // Delete button
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                                          onPressed: () => _confirmDelete(file: file),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                            childCount: _downloadedFiles.length,
                          ),
                        ),
                      )
              ],
            ),
    );
  }
}
