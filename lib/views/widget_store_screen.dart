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

class _RomGuidance {
  final String title;
  final String permissionDesc;
  final String manualSteps;

  const _RomGuidance({
    required this.title,
    required this.permissionDesc,
    required this.manualSteps,
  });
}

class _WidgetStoreScreenState extends State<WidgetStoreScreen> {
  bool _isPremiumUnlocked = false;
  bool _isLoadingPremium = true;
  Map<String, String>? _romInfo;

  @override
  void initState() {
    super.initState();
    _checkPremiumStatus();
    _initRomInfoAndCheckPermission();
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
        ToastHelper.show(context, '恭喜！高级版桌宠已成功解锁！', type: ToastType.success);
      } else {
        ToastHelper.show(context, '解锁失败，请重试', type: ToastType.error);
      }
    }
  }

  Future<void> _initRomInfoAndCheckPermission() async {
    if (!WidgetService.isPlatformAndroid) return;
    final info = await WidgetService.getDeviceRomInfo();
    if (mounted) {
      setState(() {
        _romInfo = info;
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        final supportDir = await getApplicationSupportDirectory();
        final flagFile = File('${supportDir.path}/settings/widget_perm_prompt_shown.flag');
        final alreadyShown = flagFile.existsSync();
        final hasPermission = await WidgetService.checkShortcutPermission();
        
        // 若尚未授权或首次进入小部件商城，主动弹出授权引导对话框
        if (!hasPermission || !alreadyShown) {
          if (!alreadyShown) {
            try {
              flagFile.createSync(recursive: true);
            } catch (_) {}
          }
          if (mounted) {
            final romName = _romInfo != null && _romInfo!['romType'] != 'other'
                ? _romInfo!['romName']!
                : '';
            final dialogTitle = romName.isNotEmpty ? '$romName 桌面小组件授权提示' : '桌面小组件授权提示';
            _showPermissionGuidanceDialog(
              title: dialogTitle,
              isStartupPrompt: true,
            );
          }
        }
      } catch (e) {
        debugPrint('[WidgetStoreScreen] initRomInfo error: $e');
      }
    });
  }

  _RomGuidance _getRomGuidance() {
    final romType = _romInfo?['romType'] ?? 'other';
    switch (romType) {
      case 'coloros':
        return const _RomGuidance(
          title: 'OPPO ColorOS / OnePlus / Realme',
          permissionDesc: 'ColorOS / Realme UI 系统默认对桌面微件设置了严格的权限管控。请进入系统设置允许「桌面快捷方式」权限，并确保桌面设置中未开启「锁定桌面布局」。',
          manualSteps: '在桌面双指捏合或长按空白处 -> 点击「微件」（注意选择「微件」而非系统卡片）-> 找到「萌哩」即可拖动添加至桌面。',
        );
      case 'originos':
        return const _RomGuidance(
          title: 'vivo OriginOS / iQOO',
          permissionDesc: 'OriginOS 系统默认拦截第三方应用的小部件自动添加广播。请前往系统应用权限管理开启「桌面快捷方式」权限，并确认桌面未开启「锁定桌面布局」。',
          manualSteps: '长按桌面空白处 -> 进入「原子组件」-> 滑到底部点击「经典组件 / 安卓微件」-> 找到「萌哩」添加。',
        );
      case 'hyperos':
        return const _RomGuidance(
          title: '小米 HyperOS / MIUI',
          permissionDesc: 'HyperOS / MIUI 系统默认禁止应用创建桌面快捷方式。必须在应用权限设置中将「桌面快捷方式」权限手动设为「始终允许」。',
          manualSteps: '长按桌面空白处或双指捏合 -> 点击「添加小部件」-> 滑到底部「支持小部件的应用 / 安卓小部件」-> 找到「萌哩」添加。',
        );
      case 'magicos':
        return const _RomGuidance(
          title: '荣耀 MagicOS',
          permissionDesc: 'MagicOS 默认对第三方桌面小部件有安全限制。请在荣耀手机管家或系统权限管理中允许「桌面快捷方式」权限，并确认主屏幕未锁定。',
          manualSteps: '在桌面双指捏合或长按空白处 -> 点击「卡片」并切换至「窗口小工具」-> 找到「萌哩」小组件拖动至桌面。',
        );
      case 'harmonyos':
        return const _RomGuidance(
          title: '华为 HarmonyOS / EMUI',
          permissionDesc: 'HarmonyOS 默认对桌面微件有防护管控。请进入系统应用权限管理，确认已开启「创建桌面快捷方式」权限。',
          manualSteps: '桌面双指捏合 -> 点击「服务卡片」并切换至「窗口小工具」-> 滑动找到经典微件中的「萌哩」添加。',
        );
      case 'oneui':
        return const _RomGuidance(
          title: '三星 One UI',
          permissionDesc: 'One UI 原生支持桌面微件。若添加失败，请确认「萌哩」未处于系统「深度休眠」列表，并在主屏幕设置中确认未开启「锁定主屏幕布局」。',
          manualSteps: '长按桌面空白处 -> 点击底部「微件 (Widgets)」-> 展开「萌哩」列表并长按拖动到桌面合适位置。',
        );
      default:
        return const _RomGuidance(
          title: 'Android 系统桌面',
          permissionDesc: '部分定制系统默认限制应用向桌面添加组件。如无法自动弹出添加弹窗，请检查是否已在系统设置中授予「创建桌面快捷方式」权限，且桌面未开启「锁定桌面布局」。',
          manualSteps: '• ColorOS / Realme：桌面双指捏合 -> 点击「微件」-> 找到「萌哩」添加；\n• OriginOS：桌面长按 ->「原子组件」-> 底部「经典组件 / 微件」-> 找到「萌哩」；\n• HyperOS / MIUI：桌面长按 ->「添加小部件」-> 底部「支持小部件的应用」-> 找到「萌哩」；\n• MagicOS：桌面双指捏合 ->「卡片」->「窗口小工具」-> 找到「萌哩」；\n• One UI：桌面长按 ->「微件」-> 展开「萌哩」长按拖出。',
        );
    }
  }

  void _showPermissionGuidanceDialog({
    required String title,
    bool isStartupPrompt = false,
  }) {
    if (!mounted) return;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final guidance = _getRomGuidance();
    final isSpecificRom = _romInfo != null && _romInfo!['romType'] != 'other';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
          title: Row(
            children: [
              Icon(Icons.dashboard_customize_rounded, color: theme.colorScheme.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: MediaQuery.of(context).size.width * 0.85,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                if (isSpecificRom) ...[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '已适配当前系统：${guidance.title}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Text(
                  '系统权限说明：',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guidance.permissionDesc,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  isSpecificRom ? '推荐添加方式（手动添加）：' : '主流定制系统手动添加指引：',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  guidance.manualSteps,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withOpacity(0.75),
                  ),
                ),
              ],
            ),
          ),
        ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                isStartupPrompt ? '我知道了' : '关闭',
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
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('前往设置允许权限'),
            ),
          ],
        );
      },
    );
  }

  void _handlePinWidget(String providerName, String widgetName) async {
    if (!WidgetService.isPlatformAndroid) {
      ToastHelper.show(context, '当前平台不支持添加桌面小组件', type: ToastType.warning);
      return;
    }

    final hasPermission = await WidgetService.checkShortcutPermission();
    if (!hasPermission) {
      if (!mounted) return;
      _showPermissionGuidanceDialog(
        title: '需要桌面快捷方式权限',
      );
      return;
    }

    // 等待至少两帧，确保此前所有 BottomSheet/Dialog 的关闭动画已结束、
    // Activity window focus 已完整归还前台。部分国产 Launcher（ColorOS/OriginOS）
    // 会在 Binder 侧检测 caller 的前台状态，focus 空窗期内调用会被静默拒绝。
    await Future.delayed(const Duration(milliseconds: 320));
    if (!mounted) return;

    print('[WidgetStoreScreen] Requesting pinWidget for providerName: $providerName');
    final success = await WidgetService.pinWidget(providerName);
    print('[WidgetStoreScreen] pinWidget returned: $success');
    if (mounted) {
      if (success) {
        ToastHelper.show(context, '请在系统底部弹窗中点击「添加」即可固定到桌面', type: ToastType.success);
      } else {
        final guidance = _getRomGuidance();
        final isSpecificRom = _romInfo != null && _romInfo!['romType'] != 'other';
        showDialog(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 24.0),
              title: const Text('系统桌面未响应', style: TextStyle(fontWeight: FontWeight.bold)),
              content: SizedBox(
                width: MediaQuery.of(context).size.width * 0.85,
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('未能自动调起系统添加弹窗。\n'),
                      if (isSpecificRom) ...[
                        Text('【${guidance.title} 专属说明】', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(guidance.permissionDesc, style: const TextStyle(fontSize: 13, height: 1.4)),
                        const SizedBox(height: 10),
                        const Text('请按下方指引手动添加：', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        const SizedBox(height: 4),
                        Text(guidance.manualSteps, style: const TextStyle(fontSize: 13, height: 1.4)),
                      ] else ...[
                        const Text('说明与排查：\n1. 请检查是否已授予应用「桌面快捷方式」权限，并确认桌面未开启「锁定桌面布局」；\n2. 建议通过桌面空白处长按选择「小部件/微件」手动添加。'),
                      ],
                    ],
                  ),
                ),
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
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: const Text('检查权限设置'),
                ),
              ],
            );
          },
        );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            tooltip: '权限与添加指引',
            onPressed: () {
              final romName = _romInfo != null && _romInfo!['romType'] != 'other'
                  ? _romInfo!['romName']!
                  : '';
              final dialogTitle = romName.isNotEmpty ? '$romName 桌面小组件授权与添加指引' : '桌面小组件授权与添加指引';
              _showPermissionGuidanceDialog(
                title: dialogTitle,
                isStartupPrompt: false,
              );
            },
          ),
        ],
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
                                              cacheManager: AppImageCacheManager(),
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
                                        cacheManager: AppImageCacheManager(),
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
