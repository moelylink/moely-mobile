import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../utils/toast_helper.dart';
import '../utils/cache_helper.dart';
import '../services/url_handler_service.dart';
import '../services/widget_service.dart';
import '../services/user_agent_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';



class WidgetStoreScreen extends StatefulWidget {
  const WidgetStoreScreen({super.key});

  @override
  State<WidgetStoreScreen> createState() => _WidgetStoreScreenState();
}

class _WidgetStoreScreenState extends State<WidgetStoreScreen> {
  bool _isPremiumUnlocked = false;
  bool _isLoadingPremium = true;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
  }

  Future<void> _checkPremiumStatus() async {
    if (WidgetService.isPlatformAndroid) {
      final unlocked = await WidgetService.isPremiumUnlocked();
      if (mounted) {
        setState(() {
          _isPremiumUnlocked = unlocked;
          _isLoadingPremium = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoadingPremium = false;
        });
      }
    }
  }

  Future<void> _unlockPremium() async {
    if (!WidgetService.isPlatformAndroid) {
      ToastHelper.show(context, '当前平台不支持解锁桌面小组件高级版', type: ToastType.warning);
      return;
    }
    setState(() {
      _isLoadingPremium = true;
    });
    final success = await WidgetService.setPremiumUnlocked(true);
    if (mounted) {
      setState(() {
        _isPremiumUnlocked = success;
        _isLoadingPremium = false;
      });
      if (success) {
        ToastHelper.show(context, '🎉 恭喜！高级版桌宠已成功解锁！', type: ToastType.success);
      } else {
        ToastHelper.show(context, '解锁失败，请重试', type: ToastType.error);
      }
    }
  }

  void _handlePinWidget(String providerName, String widgetName) async {
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
                '⚠️ 提示：如果您的桌面没有出现任何添加提示框，可能是由于系统限制了「创建桌面快捷方式」权限。请点击“去开启权限”手动授权后再试。'
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

  void _showDailyImageOptions(BuildContext context, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 15,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                '选择组件样式',
                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '萌哩每日一图提供两种不同比例的桌面小组件',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.5)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              
              // Option 2: DailyImagePortraitProvider
              _buildOptionCard(
                theme: theme,
                isDark: isDark,
                title: '精美竖屏大卡 (2 × 3)',
                subtitle: '适合纵向较长的小组件，展示完美的竖屏人物美图',
                icon: Icons.smartphone_rounded,
                color: const Color(0xFF29B6F6),
                onTap: () {
                  Navigator.pop(context);
                  _handlePinWidget('DailyImagePortraitProvider', '竖屏比例每日一图');
                },
              ),
              const SizedBox(height: 12),

              // Option 3: DailyImageLandscapeProvider
              _buildOptionCard(
                theme: theme,
                isDark: isDark,
                title: '电影感横屏卡 (3 × 2)',
                subtitle: '经典宽银幕比例，展示绝美的横版二次元插图',
                icon: Icons.crop_original_rounded,
                color: const Color(0xFFFF7043),
                onTap: () {
                  Navigator.pop(context);
                  _handlePinWidget('DailyImageLandscapeProvider', '横屏比例每日一图');
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  void _showPetWidgetOptions(BuildContext context, ThemeData theme, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 15,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
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
                  
                  if (!_isPremiumUnlocked) ...[
                    // Lock screen display
                    Icon(Icons.lock_person_rounded, size: 54, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      '解锁桌面互动看板娘',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '解锁后可在桌面开启可爱的互动宠物角色，支持喂食、贴贴互动、状态展示等丰富特效！',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6), height: 1.5),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isLoadingPremium
                          ? null
                          : () async {
                              setModalState(() {}); // Force redraw inside modal to show loader
                              await _unlockPremium();
                              if (context.mounted) {
                                if (_isPremiumUnlocked) {
                                  Navigator.pop(context); // Close on success
                                } else {
                                  setModalState(() {}); // Redraw on error/failure
                                }
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 3,
                      ),
                      child: _isLoadingPremium
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: theme.colorScheme.onPrimary,
                              ),
                            )
                          : const Text('立即免费解锁高级版桌宠', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ] else ...[
                    // Unlocked display
                    Icon(Icons.check_circle_rounded, size: 54, color: Colors.greenAccent[700]),
                    const SizedBox(height: 16),
                    Text(
                      '添加桌宠小组件 (已解锁)',
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '您可以直接将其添加到您的手机桌面，并开始与可爱的萌宠互动！',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        _handlePinWidget('PetWidgetProvider', '随机探索看板娘');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text('添加到手机桌面', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildOptionCard({
    required ThemeData theme,
    required bool isDark,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.colorScheme.onSurface.withOpacity(0.06)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final mockWidgets = [
      {
        'title': '萌哩每日一图',
        'desc': '在桌面上展示每日精心挑选的二次元神级美图，支持自动更新与点击跳转。',
        'size': '2 × 3 / 3 × 2',
        'downloads': '1.2 万',
        'price': '免费',
        'color': const Color(0xFFAB47BC),
        'icon': Icons.image_rounded,
        'type': 'daily_image',
      },
      {
        'title': '随机探索看板娘',
        'desc': '随机展示最受好评的精选画师代表作，让你的桌面瞬间充满朝气与灵动！',
        'size': '2 × 2',
        'downloads': '8,500',
        'price': _isPremiumUnlocked ? '添加' : '解锁',
        'color': const Color(0xFFFF7043),
        'icon': Icons.assistant_rounded,
        'type': 'pet_board',
      },
      {
        'title': 'DIY自定义画廊',
        'desc': '支持在桌面上轮播展示您自定义选择的本地图片或收藏夹美图，随心定制您的专属桌面。',
        'size': '3 × 3',
        'downloads': '6,500',
        'price': _isPremiumUnlocked ? '设置' : '解锁',
        'color': const Color(0xFF66BB6A),
        'icon': Icons.photo_library_rounded,
        'type': 'custom_gallery',
      },
      {
        'title': '色彩灵感卡',
        'desc': '聚合当日最火二次元插画的配色色卡方案，一键复制十六进制灵感配色。',
        'size': '4 × 1',
        'downloads': '4,300',
        'price': '10 萌豆',
        'color': const Color(0xFFFF9800),
        'icon': Icons.color_lens_rounded,
        'type': 'color_card',
      },
      {
        'title': '画师动态订阅',
        'desc': '在您的手机桌面上实时接收订阅画师的最新发布作品，不错过任何心动瞬间。',
        'size': '2 × 2',
        'downloads': '6,200',
        'price': '免费',
        'color': const Color(0xFF29B6F6),
        'icon': Icons.rss_feed_rounded,
        'type': 'rss_feed',
      },
    ];

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('小部件商城', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: CustomScrollView(
        slivers: [
          // Banner Section
          SliverToBoxAdapter(
            child: Container(
              margin: const EdgeInsets.all(16),
              height: 150,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    theme.colorScheme.primary,
                    theme.colorScheme.secondary,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: theme.colorScheme.primary.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Stack(
                children: [
                  Positioned(
                    right: -20,
                    bottom: -20,
                    child: Icon(
                      Icons.widgets_rounded,
                      size: 160,
                      color: Colors.white.withOpacity(0.12),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          '让桌面跃然指尖',
                          style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '下载并设置 iOS & Android 原生桌面小部件，精美二次元插图一触即达。',
                          style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 11, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Text(
                '精选小部件',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),

          // Widgets list
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final widgetItem = mockWidgets[index];
                  final title = widgetItem['title'].toString();
                  final desc = widgetItem['desc'].toString();
                  final size = widgetItem['size'].toString();
                  final downloads = widgetItem['downloads'].toString();
                  final price = widgetItem['price'].toString();
                  final color = widgetItem['color'] as Color;
                  final icon = widgetItem['icon'] as IconData;
                  final type = widgetItem['type'].toString();

                  return Card(
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Widget Icon Placeholder
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: color.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(icon, color: color, size: 28),
                          ),
                          const SizedBox(width: 16),
                          
                          // Widget Details
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: theme.colorScheme.onSurface.withOpacity(0.06),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        size,
                                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface.withOpacity(0.6)),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  desc,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: theme.colorScheme.onSurface.withOpacity(0.5),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Icon(Icons.download_rounded, size: 14, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    const SizedBox(width: 4),
                                    Text(
                                      '$downloads 下载',
                                      style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                                    ),
                                    const Spacer(),
                                    FilledButton(
                                      onPressed: () {
                                        if (type == 'daily_image') {
                                          _showDailyImageOptions(context, theme, isDark);
                                        } else if (type == 'pet_board') {
                                          _showPetWidgetOptions(context, theme, isDark);
                                        } else if (type == 'custom_gallery') {
                                          if (!_isPremiumUnlocked) {
                                            _showPetWidgetOptions(context, theme, isDark);
                                          } else {
                                            _showGalleryConfigOptions(context, theme, isDark);
                                          }
                                        } else {
                                          final rootContext = UrlHandlerService.navigatorKey.currentContext ?? context;
                                          ToastHelper.show(rootContext, '$title 小部件正在开发中，敬请期待！', type: ToastType.warning);
                                        }
                                      },
                                      style: FilledButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(horizontal: 16),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                        textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                      ),
                                      child: Text(price),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
                childCount: mockWidgets.length,
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 40)),
        ],
      ),
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
                  
                  // Images Grid View
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
      if (!context.mounted) return [];
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
