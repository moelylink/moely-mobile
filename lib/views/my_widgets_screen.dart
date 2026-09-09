import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/toast_helper.dart';
import '../utils/cache_helper.dart';
import '../services/widget_service.dart';
import '../services/user_agent_service.dart';
import 'widget_store_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

class MyWidgetsScreen extends StatefulWidget {
  final int? initialConfigureWidgetId;
  const MyWidgetsScreen({super.key, this.initialConfigureWidgetId});

  @override
  State<MyWidgetsScreen> createState() => _MyWidgetsScreenState();
}

class _MyWidgetsScreenState extends State<MyWidgetsScreen> {
  List<Map<String, dynamic>> _activeWidgets = [];
  bool _isLoading = true;
  bool _isPremiumUnlocked = false;
  bool _hasShownInitialConfigure = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Check premium status
      if (WidgetService.isPlatformAndroid) {
        _isPremiumUnlocked = await WidgetService.isPremiumUnlocked();
      }
      
      // 2. Fetch all active widgets from home screen
      final widgets = await WidgetService.getAllActiveWidgets();
      
      if (mounted) {
        setState(() {
          _activeWidgets = widgets;
          _isLoading = false;
        });
        
        // If was opened via deep link to configure a specific widget
        if (widget.initialConfigureWidgetId != null && !_hasShownInitialConfigure) {
          _hasShownInitialConfigure = true;
          final targetWidget = widgets.firstWhere(
            (w) => w['id'] == widget.initialConfigureWidgetId,
            orElse: () => <String, dynamic>{},
          );
          if (targetWidget.isNotEmpty) {
            final id = targetWidget['id'] as int;
            final type = targetWidget['type'] as String;
            final provider = targetWidget['provider'] as String;
            final customName = targetWidget['customName'] as String;
            final isDark = Theme.of(context).brightness == Brightness.dark;
            
            if (type == 'gallery') {
              _showGalleryConfigOptions(
                context, 
                Theme.of(context), 
                isDark, 
                widgetId: id,
              );
            } else if (type == 'pet') {
              _showPetConfigOptions(
                context, 
                Theme.of(context), 
                isDark, 
                id, 
                customName,
              );
            } else if (type.startsWith('daily')) {
              _showDailyConfigOptions(
                context, 
                Theme.of(context), 
                isDark, 
                id, 
                customName, 
                type, 
                provider,
              );
            }
          }
        }
      }
    } catch (e) {
      print('Failed to load widgets: $e');
      if (mounted) {
        ToastHelper.show(context, '加载桌面组件失败: $e', type: ToastType.error);
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _handlePinWidget(String providerName, String widgetName) async {
    if (!WidgetService.isPlatformAndroid) {
      ToastHelper.show(context, '当前平台不支持添加桌面小组件', type: ToastType.warning);
      return;
    }
    
    final hasPermission = await WidgetService.checkShortcutPermission();
    if (!hasPermission) {
      if (!mounted) return;
      final result = await showDialog<bool>(
        context: context,
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          return AlertDialog(
            title: const Text('需要桌面快捷方式权限'),
            content: const Text(
              '由于您的系统限制，快捷添加小组件需要「创建桌面快捷方式」权限。\n\n'
              '请点击“去开启”前往设置界面手动允许该权限，然后再试。'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  '取消',
                  style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.colorScheme.primary,
                  foregroundColor: theme.colorScheme.onPrimary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('去开启'),
              ),
            ],
          );
        },
      );
      if (result == true) {
        await WidgetService.openShortcutPermissionSettings();
      }
      return;
    }
    
    final success = await WidgetService.pinWidget(providerName);
    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return AlertDialog(
              title: const Text('添加请求已发送'),
              content: const Text(
                '已向系统桌面发送小组件添加请求。\n\n'
                '⚠️ 提示：如果您的桌面没有出现任何添加提示框，可能是由于系统限制了「创建桌面快捷方式」权限。请点击“去开启”手动授权后再试。'
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    '好的',
                    style: TextStyle(color: isDark ? Colors.white70 : Colors.black54),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    WidgetService.openShortcutPermissionSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary,
                    foregroundColor: theme.colorScheme.onPrimary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('去开启权限'),
                ),
              ],
            );
          },
        );
      } else {
        ToastHelper.show(context, '您的系统桌面暂不支持快捷添加，请长按桌面手动添加小组件！', type: ToastType.warning);
      }
    }
  }

  Future<void> _unlockPremium() async {
    final success = await WidgetService.setPremiumUnlocked(true);
    if (mounted) {
      setState(() {
        _isPremiumUnlocked = success;
      });
      if (success) {
        ToastHelper.show(context, '🎉 高级版桌面小组件已解锁！', type: ToastType.success);
      } else {
        ToastHelper.show(context, '解锁失败，请重试', type: ToastType.error);
      }
    }
  }

  Widget _buildWidgetStoreBanner(ThemeData theme, bool isDark) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark 
              ? [const Color(0xFF1E293B), const Color(0xFF334155)]
              : [theme.colorScheme.primary.withOpacity(0.08), theme.colorScheme.secondary.withOpacity(0.08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark 
              ? Colors.white.withOpacity(0.08) 
              : theme.colorScheme.primary.withOpacity(0.15),
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => WidgetStoreScreen()),
              ).then((_) => _loadData());
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.store_mall_directory_rounded, color: theme.colorScheme.primary, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              '小组件商城',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text(
                                'NEW',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '浏览并添加更多二次元精美桌面小组件',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 16,
                    color: theme.colorScheme.onSurface.withOpacity(0.4),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('我的小组件', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadData,
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Widget Store Entrance at the top
                    _buildWidgetStoreBanner(theme, isDark),
                    
                    const SizedBox(height: 20),
                    
                    // Premium status banner
                    if (!_isPremiumUnlocked)
                      _buildPremiumBanner(theme, isDark)
                    else
                      _buildPremiumUnlockedBadge(theme, isDark),
                    
                    const SizedBox(height: 24),
                    
                    // Section: Active Placed Widgets
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '已添加到桌面的小组件',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '共 ${_activeWidgets.length} 个',
                          style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withOpacity(0.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _buildActiveWidgetsSection(theme, isDark),
                    
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPremiumBanner(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [theme.colorScheme.primary, theme.colorScheme.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.lock_person_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  '解锁高级版桌面小组件',
                  style: theme.textTheme.titleMedium?.copyWith(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '解锁后可体验桌面互动看板娘、自定义相册轮播画廊等核心高级版组件！',
            style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _unlockPremium,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: theme.colorScheme.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text('立即免费解锁', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumUnlockedBadge(ThemeData theme, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF66BB6A).withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF66BB6A).withOpacity(0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.stars_rounded, color: Color(0xFF66BB6A), size: 24),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '高级版已成功解锁',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF66BB6A)),
                ),
                SizedBox(height: 2),
                Text(
                  '已启用：DIY自定义画廊、互动桌宠全部高级功能。',
                  style: TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildActiveWidgetsSection(ThemeData theme, bool isDark) {
    if (_activeWidgets.isEmpty) {
      return Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(Icons.widgets_outlined, color: theme.colorScheme.primary.withOpacity(0.5), size: 48),
              const SizedBox(height: 16),
              const Text(
                '桌面上没有已添加的小组件',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '您可以在系统桌面长按 -> 选择「添加组件」\n找到「萌哩」即可将小组件放置在桌面上。',
                style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.5), height: 1.5),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _activeWidgets.length,
      itemBuilder: (context, index) {
        final w = _activeWidgets[index];
        final wId = w['id'] as int;
        final wType = w['type'] as String;
        final wProvider = w['provider'] as String;
        final wCustomName = w['customName'] as String;

        Color widgetColor = const Color(0xFF66BB6A); // Gallery green
        IconData widgetIcon = Icons.photo_library_rounded;
        String badgeText = "画廊";

        if (wType == 'pet') {
          widgetColor = const Color(0xFFFF7043); // Pet orange
          widgetIcon = Icons.assistant_rounded;
          badgeText = "桌宠";
        } else if (wType.startsWith('daily')) {
          widgetColor = const Color(0xFFAB47BC); // Daily Image purple
          widgetIcon = Icons.image_rounded;
          badgeText = "每日一图";
        }

        return Card(
          margin: const EdgeInsets.only(bottom: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: () {
                if (wType == 'gallery') {
                  _showGalleryConfigOptions(context, theme, isDark, widgetId: wId);
                } else if (wType == 'pet') {
                  _showPetConfigOptions(context, theme, isDark, wId, wCustomName);
                } else if (wType.startsWith('daily')) {
                  _showDailyConfigOptions(context, theme, isDark, wId, wCustomName, wType, wProvider);
                }
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: widgetColor.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widgetIcon, color: widgetColor, size: 26),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  wCustomName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: widgetColor.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  badgeText,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: widgetColor,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Text(
                                'ID: $wId',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontFamily: 'monospace',
                                  color: theme.colorScheme.onSurface.withOpacity(0.4),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Icon(
                                Icons.settings_rounded,
                                size: 12,
                                color: theme.colorScheme.onSurface.withOpacity(0.4),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '点击修改设置',
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
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.sync_rounded),
                      tooltip: '同步刷新',
                      onPressed: () async {
                        final success = await WidgetService.updateWidget(wProvider);
                        if (context.mounted && success) {
                          ToastHelper.show(context, '刷新小组件数据成功！', type: ToastType.success);
                        }
                      },
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



  void _showGalleryConfigOptions(BuildContext context, ThemeData theme, bool isDark, {int? widgetId}) async {
    final config = await WidgetService.getGalleryConfig(widgetId: widgetId);
    List<String> currentImages = List<String>.from(config['images'] ?? []);
    String currentTitle = config['title'] ?? '自定义画廊';
    int currentScale = config['scale'] ?? 6;
    
    final titleController = TextEditingController(text: currentTitle);
    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.85,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    widgetId != null ? '配置画廊小组件 (#$widgetId)' : '配置默认画廊图片',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  // Title Setting
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: '组件自定义标题',
                      hintText: '例如：动漫美图、我的收藏',
                      prefixIcon: const Icon(Icons.edit_note_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Scale Mode Setting
                  Row(
                    children: [
                      Text(
                        '显示模式：',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('裁剪填充'),
                        selected: currentScale == 6,
                        onSelected: (selected) {
                          if (selected) setState(() => currentScale = 6);
                        },
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: const Text('完整展示'),
                        selected: currentScale == 3,
                        onSelected: (selected) {
                          if (selected) setState(() => currentScale = 3);
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Buttons to add images
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final pickedPaths = await _pickLocalImages();
                            if (pickedPaths.isNotEmpty) {
                              setState(() {
                                currentImages.addAll(pickedPaths);
                              });
                            }
                          },
                          icon: const Icon(Icons.add_photo_alternate_rounded),
                          label: const Text('添加本地'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final chosenFavUrls = await _pickFromFavorites(context, theme, isDark);
                            if (chosenFavUrls.isNotEmpty) {
                              setState(() {
                                currentImages.addAll(chosenFavUrls);
                              });
                            }
                          },
                          icon: const Icon(Icons.star_rounded),
                          label: const Text('从收藏夹'),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // Selected images list
                  Expanded(
                    child: currentImages.isEmpty
                        ? Center(
                            child: Text(
                              '暂未添加图片，请从上方选择图片',
                              style: TextStyle(color: theme.colorScheme.onSurface.withOpacity(0.4)),
                            ),
                          )
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                            itemCount: currentImages.length,
                            itemBuilder: (context, index) {
                              final imgPath = currentImages[index];
                              final isLocal = !imgPath.startsWith('http');
                              return Stack(
                                children: [
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12),
                                      child: isLocal
                                          ? Image.file(File(imgPath), fit: BoxFit.cover)
                                          : CachedNetworkImage(
                                              imageUrl: imgPath,
                                              httpHeaders: UserAgentService.headers,
                                              fit: BoxFit.cover,
                                              placeholder: (context, url) => Container(
                                                color: Colors.grey.withOpacity(0.2),
                                                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                              ),
                                              errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                            ),
                                    ),
                                  ),
                                  Positioned(
                                    right: 4,
                                    top: 4,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          currentImages.removeAt(index);
                                        });
                                      },
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: const BoxDecoration(
                                          color: Colors.black54,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final finalTitle = titleController.text.trim().isNotEmpty
                                ? titleController.text.trim()
                                : '自定义画廊';
                            final success = await WidgetService.setGalleryImages(
                              currentImages,
                              widgetId: widgetId,
                              title: finalTitle,
                              scale: currentScale,
                            );
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ToastHelper.show(context, '保存画廊配置成功！', type: ToastType.success);
                                if (widgetId == null) {
                                  _handlePinWidget('GalleryWidgetProvider', 'DIY自定义画廊');
                                } else {
                                  // Refresh layout immediately on screen
                                  _loadData();
                                }
                              } else {
                                ToastHelper.show(context, '保存失败，请重试', type: ToastType.error);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: Text(widgetId != null ? '应用修改' : '保存并添加', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showPetConfigOptions(BuildContext context, ThemeData theme, bool isDark, int widgetId, String currentName) {
    final nameController = TextEditingController(text: currentName);
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '配置桌宠小组件 (#$widgetId)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '自定义小组件名称',
                      hintText: '例如：我的萌宠、看板娘一号',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline_rounded, color: theme.colorScheme.primary, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            '您可以在桌面组件上直接点击【喂食】、【互动】或【状态】按钮与看板娘互动。',
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface.withOpacity(0.7),
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final finalName = nameController.text.trim().isNotEmpty
                                ? nameController.text.trim()
                                : '随机探索看板娘';
                            final success = await WidgetService.saveWidgetCustomName(widgetId, finalName);
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ToastHelper.show(context, '保存名称成功！', type: ToastType.success);
                                _loadData();
                              } else {
                                ToastHelper.show(context, '保存失败，请重试', type: ToastType.error);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('应用修改', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDailyConfigOptions(
    BuildContext context, 
    ThemeData theme, 
    bool isDark, 
    int widgetId, 
    String currentName, 
    String type,
    String provider,
  ) {
    final nameController = TextEditingController(text: currentName);
    
    String defaultName = '萌哩每日一图';
    String specName = '经典卡片 (4 × 2)';
    if (type == 'daily_portrait') {
      defaultName = '精美竖屏大卡';
      specName = '竖屏大卡 (3 × 2)';
    } else if (type == 'daily_landscape') {
      defaultName = '电影感横屏卡';
      specName = '横屏卡片 (2 × 3)';
    }
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: EdgeInsets.only(
                left: 24,
                right: 24,
                top: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: theme.colorScheme.onSurface.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    '配置每日一图小组件 (#$widgetId)',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: nameController,
                    decoration: InputDecoration(
                      labelText: '自定义小组件名称',
                      hintText: '例如：桌面壁纸、我的每日推荐',
                      prefixIcon: const Icon(Icons.badge_rounded),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  Row(
                    children: [
                      Text(
                        '组件规格：',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      ),
                      const SizedBox(width: 8),
                      Chip(
                        label: Text(specName),
                        backgroundColor: theme.colorScheme.secondary.withOpacity(0.1),
                        side: BorderSide.none,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  OutlinedButton.icon(
                    onPressed: () async {
                      final success = await WidgetService.updateWidget(provider);
                      if (context.mounted && success) {
                        ToastHelper.show(context, '已触发该小组件刷新！', type: ToastType.success);
                      }
                    },
                    icon: const Icon(Icons.sync_rounded),
                    label: const Text('强制刷新小组件图片'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  Row(
                    children: [
                      Expanded(
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('取消'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            final finalName = nameController.text.trim().isNotEmpty
                                ? nameController.text.trim()
                                : defaultName;
                            final success = await WidgetService.saveWidgetCustomName(widgetId, finalName);
                            if (context.mounted) {
                              Navigator.pop(context);
                              if (success) {
                                ToastHelper.show(context, '保存名称成功！', type: ToastType.success);
                                _loadData();
                              } else {
                                ToastHelper.show(context, '保存失败，请重试', type: ToastType.error);
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.colorScheme.primary,
                            foregroundColor: theme.colorScheme.onPrimary,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('应用修改', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<List<String>> _pickLocalImages() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.image,
        allowMultiple: true,
      );
      if (result != null && result.paths.isNotEmpty) {
        final docDir = await getApplicationDocumentsDirectory();
        final galleryDir = Directory('${docDir.path}/gallery_images');
        if (!galleryDir.existsSync()) {
          galleryDir.createSync(recursive: true);
        }
        
        List<String> copiedPaths = [];
        for (final path in result.paths) {
          if (path != null) {
            final file = File(path);
            final fileName = file.uri.pathSegments.last;
            final targetFile = File('${galleryDir.path}/${DateTime.now().millisecondsSinceEpoch}_$fileName');
            await file.copy(targetFile.path);
            copiedPaths.add(targetFile.path);
          }
        }
        return copiedPaths;
      }
    } catch (e) {
      print('Error picking local images: $e');
    }
    return [];
  }

  Future<List<String>> _pickFromFavorites(BuildContext context, ThemeData theme, bool isDark) async {
    List<dynamic> bookmarks = [];
    String imagesDirPath = '';
    
    final favDir = await CacheHelper.getFavoritesCacheDir();
    imagesDirPath = '${favDir.path}/images';
    final jsonFile = File('${favDir.path}/favorites.json');
    
    if (AuthService.instance.isLoggedIn) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('正在同步收藏夹...'),
                ],
              ),
            ),
          ),
        ),
      );
      
      try {
        final supabase = Supabase.instance.client;
        final userId = supabase.auth.currentUser?.id;
        if (userId != null) {
          final response = await supabase
              .from('bookmarks')
              .select('id, url, image, created_at')
              .eq('user_id', userId)
              .order('created_at', ascending: false);
          
          final List<dynamic> cloudBookmarks = response as List;
          await jsonFile.writeAsString(json.encode(cloudBookmarks));
          bookmarks = cloudBookmarks;
        }
      } catch (e) {
        print('Error syncing favorites from cloud: $e');
        // Fallback to local cache if sync fails
        try {
          if (jsonFile.existsSync()) {
            final content = await jsonFile.readAsString();
            bookmarks = json.decode(content) as List<dynamic>;
          }
        } catch (_) {}
      } finally {
        if (context.mounted) {
          Navigator.pop(context);
        }
      }
    } else {
      try {
        if (jsonFile.existsSync()) {
          final content = await jsonFile.readAsString();
          bookmarks = json.decode(content) as List<dynamic>;
        }
      } catch (e) {
        print('Error reading favorites: $e');
      }
    }

    if (bookmarks.isEmpty) {
      if (context.mounted) {
        ToastHelper.show(context, '您的收藏夹是空的，请先收藏美图！', type: ToastType.warning);
      }
      return [];
    }

    if (!context.mounted) return [];

    List<String> selectedPaths = [];
    final result = await showDialog<List<String>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('选择收藏的图片', style: TextStyle(fontWeight: FontWeight.bold)),
              backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
              content: SizedBox(
                width: double.maxFinite,
                height: 400,
                child: GridView.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                  ),
                  itemCount: bookmarks.length,
                  itemBuilder: (context, index) {
                    final item = bookmarks[index];
                    final id = item['id'].toString();
                    final imageUrl = item['image'].toString();
                    
                    final localFile = File('$imagesDirPath/$id.jpg');
                    final isOffline = localFile.existsSync();
                    final targetPath = isOffline ? localFile.path : imageUrl;
                    
                    final isSelected = selectedPaths.contains(targetPath);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            selectedPaths.remove(targetPath);
                          } else {
                            selectedPaths.add(targetPath);
                          }
                        });
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: isSelected ? theme.colorScheme.primary : Colors.transparent,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: isOffline
                                    ? Image.file(localFile, fit: BoxFit.cover)
                                    : CachedNetworkImage(
                                        imageUrl: imageUrl,
                                        httpHeaders: UserAgentService.headers,
                                        fit: BoxFit.cover,
                                        placeholder: (context, url) => Container(
                                          color: Colors.grey.withOpacity(0.2),
                                          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                        ),
                                        errorWidget: (context, url, error) => const Icon(Icons.broken_image),
                                      ),
                              ),
                              if (isSelected)
                                Positioned(
                                  right: 4,
                                  top: 4,
                                  child: Container(
                                    padding: const EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.check, color: Colors.white, size: 14),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, <String>[]),
                  child: const Text('取消'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context, selectedPaths),
                  child: const Text('确定'),
                ),
              ],
            );
          },
        );
      },
    );

    return result ?? [];
  }
}
