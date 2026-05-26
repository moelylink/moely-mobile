import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../services/settings_service.dart';

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _cacheSize = '正在计算...';

  // Premium Preset Colors
  final List<Map<String, dynamic>> _presetColors = [
    {'name': '活力蓝', 'color': const Color(0xFF3B82F6)},
    {'name': '晴空青', 'color': const Color(0xFF06B6D4)},
    {'name': '翡翠绿', 'color': const Color(0xFF10B981)},
    {'name': '琥珀橙', 'color': const Color(0xFFF59E0B)},
    {'name': '樱花粉', 'color': const Color(0xFFEC4899)},
    {'name': '皇家紫', 'color': const Color(0xFF8B5CF6)},
    {'name': '烈焰红', 'color': const Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();
    _calculateCacheSize();
  }

  Future<void> _calculateCacheSize() async {
    try {
      final cacheDir = await getTemporaryDirectory();
      double tempSize = 0;
      if (cacheDir.existsSync()) {
        cacheDir.listSync(recursive: true).forEach((file) {
          if (file is File) {
            tempSize += file.lengthSync();
          }
        });
      }
      final sizeMb = tempSize / (1024 * 1024);
      setState(() {
        _cacheSize = '${sizeMb.toStringAsFixed(2)} MB';
      });
    } catch (e) {
      setState(() {
        _cacheSize = '未知尺寸';
      });
    }
  }

  Future<void> _clearCache() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('清理缓存', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('确定要清空所有已缓存的二次元美图吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(context);
              imageCache.clear();
              imageCache.clearLiveImages();
              try {
                final cacheDir = await getTemporaryDirectory();
                if (cacheDir.existsSync()) {
                  cacheDir.deleteSync(recursive: true);
                }
              } catch (_) {}
              
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('缓存清理成功！'),
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                );
                _calculateCacheSize();
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  void _showColorPickerDialog(ThemeData theme) {
    double hue = 200.0;
    double saturation = 0.8;
    double lightness = 0.5;

    // Convert existing theme color to HSL to initialize sliders if possible
    try {
      final hsl = HSLColor.fromColor(AppSettings.instance.themeColor);
      hue = hsl.hue;
      saturation = hsl.saturation;
      lightness = hsl.lightness;
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final currentColor = HSLColor.fromAHSL(1.0, hue, saturation, lightness).toColor();

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              title: const Row(
                children: [
                  Icon(Icons.palette_rounded),
                  SizedBox(width: 12),
                  Text('自定义主题色', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Color Preview Box
                  Container(
                    height: 80,
                    decoration: BoxDecoration(
                      color: currentColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: currentColor.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '#${currentColor.value.toRadixString(16).substring(2).toUpperCase()}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          shadows: [
                            Shadow(color: Colors.black45, blurRadius: 4, offset: Offset(0, 1))
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Hue Slider
                  Row(
                    children: [
                      const Text('色相', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: hue,
                          min: 0.0,
                          max: 360.0,
                          activeColor: currentColor,
                          onChanged: (val) {
                            setDialogState(() {
                              hue = val;
                            });
                          },
                        ),
                      ),
                      Text('${hue.toStringAsFixed(0)}°', style: const TextStyle(fontSize: 12)),
                    ],
                  ),

                  // Saturation Slider
                  Row(
                    children: [
                      const Text('饱和', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: saturation,
                          min: 0.0,
                          max: 1.0,
                          activeColor: currentColor,
                          onChanged: (val) {
                            setDialogState(() {
                              saturation = val;
                            });
                          },
                        ),
                      ),
                      Text('${(saturation * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
                    ],
                  ),

                  // Lightness Slider
                  Row(
                    children: [
                      const Text('亮度', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Expanded(
                        child: Slider(
                          value: lightness,
                          min: 0.2,
                          max: 0.8,
                          activeColor: currentColor,
                          onChanged: (val) {
                            setDialogState(() {
                              lightness = val;
                            });
                          },
                        ),
                      ),
                      Text('${(lightness * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
                FilledButton(
                  onPressed: () {
                    AppSettings.instance.setThemeColor(currentColor);
                    Navigator.pop(context);
                  },
                  child: const Text('应用'),
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

    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          appBar: AppBar(
            title: const Text('系统设置', style: TextStyle(fontWeight: FontWeight.bold)),
            centerTitle: true,
            elevation: 0,
            backgroundColor: Colors.transparent,
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120), // Bottom padding for floating bar
            children: [
              // Section 1: Themes & Colors
              _buildSectionHeader(theme, '个性化与外观'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      // Color Mode
                      ListTile(
                        leading: const Icon(Icons.dark_mode_rounded),
                        title: const Text('颜色模式', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text(
                          AppSettings.instance.themeMode == ThemeMode.system
                              ? '跟随系统'
                              : AppSettings.instance.themeMode == ThemeMode.dark
                                  ? '极夜深色'
                                  : '晴朗浅色',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButton<ThemeMode>(
                            value: AppSettings.instance.themeMode,
                            underline: const SizedBox(),
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            style: TextStyle(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                            items: const [
                              DropdownMenuItem(value: ThemeMode.system, child: Text(' 跟随系统')),
                              DropdownMenuItem(value: ThemeMode.light, child: Text(' 晴朗浅色')),
                              DropdownMenuItem(value: ThemeMode.dark, child: Text(' 极夜深色')),
                            ],
                            onChanged: (mode) {
                              if (mode != null) {
                                AppSettings.instance.setThemeMode(mode);
                              }
                            },
                          ),
                        ),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),

                      // Custom Theme Color
                      ListTile(
                        leading: const Icon(Icons.palette_rounded),
                        title: const Text('系统主题色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('挑选心仪主题，打造独特风格', style: TextStyle(fontSize: 12)),
                        trailing: OutlinedButton.icon(
                          onPressed: () => _showColorPickerDialog(theme),
                          icon: const Icon(Icons.colorize_rounded, size: 14),
                          label: const Text('调色板', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            minimumSize: const Size(60, 30),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),

                      // Horizontal preset colors selection
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                        child: SizedBox(
                          height: 48,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _presetColors.length,
                            itemBuilder: (context, index) {
                              final preset = _presetColors[index];
                              final Color color = preset['color'];
                              final isSelected = AppSettings.instance.themeColor.value == color.value;

                              return Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: InkWell(
                                  onTap: () => AppSettings.instance.setThemeColor(color),
                                  borderRadius: BorderRadius.circular(24),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 250),
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: color,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isSelected 
                                            ? (theme.brightness == Brightness.dark ? Colors.white : Colors.black87)
                                            : Colors.transparent,
                                        width: 2.5,
                                      ),
                                      boxShadow: isSelected
                                          ? [
                                              BoxShadow(
                                                color: color.withOpacity(0.4),
                                                blurRadius: 8,
                                                spreadRadius: 1,
                                              )
                                            ]
                                          : [],
                                    ),
                                    child: isSelected
                                        ? const Icon(
                                            Icons.check_rounded,
                                            color: Colors.white,
                                            size: 20,
                                          )
                                        : null,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Services
              _buildSectionHeader(theme, '网络与译文服务'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.translate_rounded),
                      title: const Text('智能译文服务', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('首选微软 Edge，自动降级至 Google 翻译', style: TextStyle(fontSize: 12)),
                      value: AppSettings.instance.enableTranslation,
                      onChanged: (val) {
                        AppSettings.instance.setEnableTranslation(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 3: Cache & Storage
              _buildSectionHeader(theme, '下载与存储管理'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.folder_shared_rounded),
                      title: Text('本地存储目录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text('系统公共目录/Download/moely', style: TextStyle(fontSize: 12)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.cleaning_services_rounded),
                      title: const Text('已占用图片缓存', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(_cacheSize, style: const TextStyle(fontSize: 12)),
                      trailing: TextButton(
                        onPressed: _clearCache,
                        child: const Text('清理缓存', style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 4: About
              _buildSectionHeader(theme, '关于萌哩'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    const ListTile(
                      leading: Icon(Icons.info_outline_rounded),
                      title: Text('应用版本', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: Text('v2.0.0 (Native Flutter next)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: const Icon(Icons.code_rounded),
                      title: const Text('开源存储库', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('https://github.com/moelylink/moely.link', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {},
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader(ThemeData theme, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: theme.colorScheme.primary,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
