import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:math' as math;
import '../services/settings_service.dart';
import 'storage_management_screen.dart';
import '../utils/cache_helper.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;

class SettingsTab extends StatefulWidget {
  const SettingsTab({super.key});

  @override
  State<SettingsTab> createState() => _SettingsTabState();
}

class _SettingsTabState extends State<SettingsTab> {
  String _cacheSize = '正在计算...';

  // Premium Preset Colors
  final List<Map<String, dynamic>> _presetColors = [
    {'name': '皇家紫', 'color': const Color(0xFF8B5CF6)},
    {'name': '烈焰红', 'color': const Color(0xFFEF4444)},
    {'name': '活力蓝', 'color': const Color(0xFF3B82F6)},
    {'name': '翡翠绿', 'color': const Color(0xFF10B981)},
    {'name': '樱花粉', 'color': const Color(0xFFEC4899)},
    {'name': '琥珀橙', 'color': const Color(0xFFF59E0B)},
    {'name': '晴空青', 'color': const Color(0xFF06B6D4)},
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

  Future<void> _pickDirectory(BuildContext context) async {
    try {
      final selectedDirectory = await FilePicker.getDirectoryPath();
      if (selectedDirectory != null) {
        AppSettings.instance.setDownloadPath(selectedDirectory);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('下载目录已成功更新为: $selectedDirectory'),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Native picker failed: $e. Falling back to custom path selection...');
      if (context.mounted) {
        _showCustomDirectoryBrowser(context);
      }
    }
  }

  Future<void> _showCustomDirectoryBrowser(BuildContext context) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final List<Directory> rootDirs = [];
    try {
      if (Platform.isAndroid) {
        final internal = Directory('/storage/emulated/0');
        if (internal.existsSync()) rootDirs.add(internal);

        final download = Directory('/storage/emulated/0/Download');
        if (download.existsSync()) rootDirs.add(download);

        final pictures = Directory('/storage/emulated/0/Pictures');
        if (pictures.existsSync()) rootDirs.add(pictures);
      } else if (Platform.isWindows) {
        final home = Platform.environment['USERPROFILE'];
        if (home != null) {
          final homeDir = Directory(home);
          if (homeDir.existsSync()) rootDirs.add(homeDir);

          final download = Directory('$home\\Downloads');
          if (download.existsSync()) rootDirs.add(download);

          final pictures = Directory('$home\\Pictures');
          if (pictures.existsSync()) rootDirs.add(pictures);
        }
      } else {
        final doc = await getApplicationDocumentsDirectory();
        rootDirs.add(doc);
      }
    } catch (_) {}

    if (rootDirs.isEmpty) {
      try {
        final doc = await getApplicationDocumentsDirectory();
        rootDirs.add(doc);
      } catch (_) {}
    }

    if (context.mounted) {
      showDialog(
        context: context,
        builder: (context) {
          return _DirectoryBrowserDialog(
            rootDirs: rootDirs,
            theme: theme,
            isDark: isDark,
          );
        },
      );
    }
  }

  void _showColorPickerDialog(ThemeData theme) {
    final originalThemeColor = AppSettings.instance.themeColor;
    final originalCustomColor = AppSettings.instance.customColor;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return _ThemeColorPickerDialog(
          theme: theme,
          initialThemeColor: originalThemeColor,
          initialCustomColor: originalCustomColor,
          presetColors: _presetColors,
          onApply: (selectedColor, isCustomSelected, customColor) {
            if (isCustomSelected) {
              AppSettings.instance.setCustomColor(customColor);
            }
            AppSettings.instance.setThemeColor(selectedColor);
          },
        );
      },
    );
  }

  Widget _buildThemeModeSelector(ThemeData theme) {
    final currentMode = AppSettings.instance.themeMode;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '颜色模式',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildThemeModeOption(
                  theme,
                  ThemeMode.system,
                  Icons.settings_suggest_rounded,
                  '跟随系统',
                  currentMode == ThemeMode.system,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThemeModeOption(
                  theme,
                  ThemeMode.light,
                  Icons.wb_sunny_rounded,
                  '浅色',
                  currentMode == ThemeMode.light,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildThemeModeOption(
                  theme,
                  ThemeMode.dark,
                  Icons.dark_mode_rounded,
                  '深色',
                  currentMode == ThemeMode.dark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildThemeModeOption(
    ThemeData theme,
    ThemeMode mode,
    IconData icon,
    String label,
    bool isSelected,
  ) {
    final activeColor = AppSettings.instance.themeColor;
    return GestureDetector(
      onTap: () => AppSettings.instance.setThemeMode(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withOpacity(0.08)
              : theme.colorScheme.onSurface.withOpacity(0.04),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? activeColor : Colors.grey.withOpacity(0.15),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: isSelected ? activeColor : theme.colorScheme.onSurface.withOpacity(0.6),
              size: 20,
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? activeColor : theme.colorScheme.onSurface.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTranslationEngineSelector(ThemeData theme) {
    final isEnabled = AppSettings.instance.enableTranslation;
    return ListTile(
      enabled: isEnabled,
      leading: Icon(
        Icons.psychology_rounded,
        color: isEnabled ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.38),
      ),
      title: Text(
        '翻译引擎',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isEnabled ? null : theme.colorScheme.onSurface.withOpacity(0.38),
        ),
      ),
      subtitle: Text(
        '如果当前翻译源不可用，请尝试更换翻译引擎',
        style: TextStyle(
          fontSize: 12,
          color: isEnabled ? null : theme.colorScheme.onSurface.withOpacity(0.38),
        ),
      ),
      trailing: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.primary.withOpacity(0.08)
                : theme.colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: AppSettings.instance.translationEngine,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            style: TextStyle(
              color: isEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.38),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            items: const [
              DropdownMenuItem(value: 'microsoft', child: Text(' Microsoft ')),
              DropdownMenuItem(value: 'google', child: Text(' Google ')),
            ],
            onChanged: isEnabled
                ? (engine) {
                    if (engine != null) {
                      AppSettings.instance.setTranslationEngine(engine);
                    }
                  }
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildTranslationLanguageSelector(ThemeData theme) {
    final isEnabled = AppSettings.instance.enableTranslation;
    return ListTile(
      enabled: isEnabled,
      leading: Icon(
        Icons.language_rounded,
        color: isEnabled ? theme.colorScheme.onSurface.withOpacity(0.7) : theme.colorScheme.onSurface.withOpacity(0.38),
      ),
      title: Text(
        '翻译目标语言',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 14,
          color: isEnabled ? null : theme.colorScheme.onSurface.withOpacity(0.38),
        ),
      ),
      subtitle: Text(
        '翻译的目标地区及语言种类',
        style: TextStyle(
          fontSize: 12,
          color: isEnabled ? null : theme.colorScheme.onSurface.withOpacity(0.38),
        ),
      ),
      trailing: Opacity(
        opacity: isEnabled ? 1.0 : 0.5,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: isEnabled
                ? theme.colorScheme.primary.withOpacity(0.08)
                : theme.colorScheme.onSurface.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: DropdownButton<String>(
            value: AppSettings.instance.translationLanguage,
            underline: const SizedBox(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            style: TextStyle(
              color: isEnabled ? theme.colorScheme.primary : theme.colorScheme.onSurface.withOpacity(0.38),
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
            items: const [
              DropdownMenuItem(value: 'zh-CN', child: Text(' 简体中文 ')),
              DropdownMenuItem(value: 'zh-TW', child: Text(' 繁体中文 ')),
              DropdownMenuItem(value: 'en', child: Text(' English ')),
              DropdownMenuItem(value: 'ja', child: Text(' 日本語 ')),
              DropdownMenuItem(value: 'ko', child: Text(' 한국어 ')),
            ],
            onChanged: isEnabled
                ? (lang) {
                    if (lang != null) {
                      AppSettings.instance.setTranslationLanguage(lang);
                    }
                  }
                : null,
          ),
        ),
      ),
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
              _buildSectionHeader(theme, '主题与外观'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      // Segmented Color Mode Selector
                      _buildThemeModeSelector(theme),
                      const Divider(height: 1, indent: 16, endIndent: 16),

                      // Theme Color picker trigger with right circle preview
                      ListTile(
                        leading: Icon(Icons.palette_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                        title: const Text('主题色', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: const Text('系统配色，彰显个性', style: TextStyle(fontSize: 12)),
                        onTap: () => _showColorPickerDialog(theme),
                        trailing: GestureDetector(
                          onTap: () => _showColorPickerDialog(theme),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppSettings.instance.themeColor,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: theme.brightness == Brightness.dark ? Colors.white70 : Colors.black12,
                                width: 2.0,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppSettings.instance.themeColor.withOpacity(0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.colorize_rounded,
                              color: Colors.white,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Section 2: Browsing
              _buildSectionHeader(theme, '浏览'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.security_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('外部链接确认弹窗', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('关闭后将不再展示安全提示弹窗', style: TextStyle(fontSize: 12)),
                      value: AppSettings.instance.showJumpConfirmation,
                      onChanged: (val) {
                        AppSettings.instance.setShowJumpConfirmation(val);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    SwitchListTile(
                      secondary: Icon(Icons.open_in_browser_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('在App内浏览外部网页', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('关闭后将使用系统默认浏览器打开外部链接', style: TextStyle(fontSize: 12)),
                      value: AppSettings.instance.browseInApp,
                      onChanged: (val) {
                        AppSettings.instance.setBrowseInApp(val);
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section 3: Translation
              _buildSectionHeader(theme, '翻译'),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: Icon(Icons.translate_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('启用翻译功能', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('在作品详情页展示翻译按钮', style: TextStyle(fontSize: 12)),
                      value: AppSettings.instance.enableTranslation,
                      onChanged: (val) {
                        AppSettings.instance.setEnableTranslation(val);
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Translation Engine
                    _buildTranslationEngineSelector(theme),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // Translation Target Language
                    _buildTranslationLanguageSelector(theme),
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
                    // 1. Cache Management Tile
                    ListTile(
                      leading: Icon(Icons.cleaning_services_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('缓存管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('管理图片、网页信息与索引占用的缓存空间', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const CacheManagementScreen()),
                        ).then((_) {
                          _calculateCacheSize();
                        });
                      },
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // 2. Download Path Customization Tile
                    ListTile(
                      leading: Icon(Icons.folder_shared_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('下载目录', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: AnimatedBuilder(
                        animation: AppSettings.instance,
                        builder: (context, child) {
                          final path = AppSettings.instance.downloadPath;
                          return Text(
                            path.isEmpty ? '默认: Download/Moely' : path,
                            style: const TextStyle(fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () => _pickDirectory(context),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),

                    // 3. Download Manager Tile
                    ListTile(
                      leading: Icon(Icons.download_for_offline_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: const Text('下载管理', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('查看与管理已下载完成的二次元美图', style: TextStyle(fontSize: 12)),
                      trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => const DownloadManagementScreen()),
                        );
                      },
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
                    ListTile(
                      leading: Icon(Icons.info_outline_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
                      title: Text('应用版本', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      trailing: Text('v2.0.0 (Native Flutter next)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                    const Divider(height: 1, indent: 16, endIndent: 16),
                    ListTile(
                      leading: Icon(Icons.code_rounded, color: theme.colorScheme.onSurface.withOpacity(0.7)),
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

class _ThemeColorPickerDialog extends StatefulWidget {
  final ThemeData theme;
  final Color initialThemeColor;
  final Color initialCustomColor;
  final List<Map<String, dynamic>> presetColors;
  final Function(Color selectedColor, bool isCustomSelected, Color customColor) onApply;

  const _ThemeColorPickerDialog({
    super.key,
    required this.theme,
    required this.initialThemeColor,
    required this.initialCustomColor,
    required this.presetColors,
    required this.onApply,
  });

  @override
  State<_ThemeColorPickerDialog> createState() => _ThemeColorPickerDialogState();
}

class _ThemeColorPickerDialogState extends State<_ThemeColorPickerDialog> {
  late Color _currentColor;
  late Color _customColor;
  late int _selectedPresetIndex;

  final _rController = TextEditingController();
  final _gController = TextEditingController();
  final _bController = TextEditingController();

  bool _isUpdatingFromRGB = false;

  @override
  void initState() {
    super.initState();
    _currentColor = widget.initialThemeColor;
    _customColor = widget.initialCustomColor;

    // Determine initial selected index
    _selectedPresetIndex = widget.presetColors.indexWhere(
      (p) => p['color'].value == widget.initialThemeColor.value,
    );
    if (_selectedPresetIndex == -1) {
      _selectedPresetIndex = 7; // Custom
      _customColor = widget.initialThemeColor;
    }

    _rController.text = _currentColor.red.toString();
    _gController.text = _currentColor.green.toString();
    _bController.text = _currentColor.blue.toString();
  }

  @override
  void dispose() {
    _rController.dispose();
    _gController.dispose();
    _bController.dispose();
    super.dispose();
  }

  void _updateColor(Color newColor, {bool updateTextFields = true, bool isPresetChange = false}) {
    setState(() {
      _currentColor = newColor;
      if (!isPresetChange) {
        // If modified manually by wheel or RGB, active mode is Custom
        _selectedPresetIndex = 7;
        _customColor = newColor;
      }
    });

    if (updateTextFields) {
      _isUpdatingFromRGB = true;
      _rController.text = newColor.red.toString();
      _gController.text = newColor.green.toString();
      _bController.text = newColor.blue.toString();
      _isUpdatingFromRGB = false;
    }
  }

  void _onRGBChanged() {
    if (_isUpdatingFromRGB) return;
    final r = int.tryParse(_rController.text) ?? 0;
    final g = int.tryParse(_gController.text) ?? 0;
    final b = int.tryParse(_bController.text) ?? 0;

    final clampedR = r.clamp(0, 255);
    final clampedG = g.clamp(0, 255);
    final clampedB = b.clamp(0, 255);

    // Update if clamped
    if (r != clampedR || g != clampedG || b != clampedB) {
      _isUpdatingFromRGB = true;
      if (r != clampedR) _rController.text = clampedR.toString();
      if (g != clampedG) _gController.text = clampedG.toString();
      if (b != clampedB) _bController.text = clampedB.toString();
      _isUpdatingFromRGB = false;
    }

    final newColor = Color.fromARGB(255, clampedR, clampedG, clampedB);
    _updateColor(newColor, updateTextFields: false);
  }

  Widget _buildRGBField(String label, TextEditingController controller, Color labelColor, Color activeColor, VoidCallback onChanged) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 3,
      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
      decoration: InputDecoration(
        counterText: "",
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 8.0, right: 2.0),
          child: Center(
            widthFactor: 1.0,
            child: Text(
              label,
              style: TextStyle(
                color: labelColor,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        isDense: true,
        filled: true,
        fillColor: widget.theme.colorScheme.primary.withOpacity(0.04),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.grey.withOpacity(0.15)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: activeColor, width: 2),
        ),
      ),
      onChanged: (val) => onChanged(),
    );
  }

  Widget _buildGridItem(int index, String name, Color color, bool isCustom) {
    final isSelected = _selectedPresetIndex == index;
    final displayColor = isCustom ? _customColor : color;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedPresetIndex = index;
          });
          _updateColor(displayColor, isPresetChange: true);
        },
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: displayColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? (widget.theme.brightness == Brightness.dark ? Colors.white : Colors.black87)
                      : Colors.transparent,
                  width: 2.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: displayColor.withOpacity(0.3),
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 18,
                    )
                  : (isCustom
                      ? const Icon(
                          Icons.blur_on_rounded,
                          color: Colors.white70,
                          size: 18,
                        )
                      : null),
            ),
            const SizedBox(height: 4),
            Text(
              name,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? widget.theme.colorScheme.primary : Colors.grey[600],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> row1 = [];
    final List<Widget> row2 = [];

    for (int i = 0; i < 4; i++) {
      row1.add(_buildGridItem(i, widget.presetColors[i]['name'], widget.presetColors[i]['color'], false));
    }
    for (int i = 4; i < 7; i++) {
      row2.add(_buildGridItem(i, widget.presetColors[i]['name'], widget.presetColors[i]['color'], false));
    }
    row2.add(_buildGridItem(7, '自定义', _customColor, true));

    return AlertDialog(
      backgroundColor: widget.theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      title: Row(
        children: [
          Icon(Icons.palette_rounded, color: _currentColor),
          const SizedBox(width: 12),
          const Text('主题色选取面板', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '预设颜色',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: row1,
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: row2,
              ),
              const SizedBox(height: 20),

              const Text(
                '调色盘',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              ColorWheelPicker(
                color: _currentColor,
                onChanged: (color) {
                  _updateColor(color);
                },
              ),
              const SizedBox(height: 20),

              const Text(
                'RGB 属性',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _buildRGBField(
                      'R',
                      _rController,
                      const Color(0xFFEF4444),
                      _currentColor,
                      _onRGBChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRGBField(
                      'G',
                      _gController,
                      const Color(0xFF10B981),
                      _currentColor,
                      _onRGBChanged,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildRGBField(
                      'B',
                      _bController,
                      const Color(0xFF3B82F6),
                      _currentColor,
                      _onRGBChanged,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            widget.onApply(_currentColor, _selectedPresetIndex == 7, _customColor);
            Navigator.pop(context);
          },
          style: FilledButton.styleFrom(
            backgroundColor: _currentColor,
            foregroundColor: Colors.white,
          ),
          child: const Text('确定'),
        ),
      ],
    );
  }
}

class ColorWheelPicker extends StatelessWidget {
  final Color color;
  final ValueChanged<Color> onChanged;

  const ColorWheelPicker({
    super.key,
    required this.color,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hsv = HSVColor.fromColor(color);
    final double value = hsv.value;
    final double hue = hsv.hue;
    final double saturation = hsv.saturation;

    return Center(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Color Wheel
          SizedBox(
            width: 180,
            height: 180,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double radius = constraints.maxWidth / 2;

                // Calculate cursor offset relative to the center
                final angleRad = hue * math.pi / 180;
                final dist = saturation * radius;
                final cursorPosition = Offset(
                  radius + dist * math.cos(angleRad),
                  radius + dist * math.sin(angleRad),
                );

                return GestureDetector(
                  onPanUpdate: (details) {
                    _handleWheelGesture(details.localPosition, radius, value);
                  },
                  onPanDown: (details) {
                    _handleWheelGesture(details.localPosition, radius, value);
                  },
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, constraints.maxWidth),
                    painter: ColorWheelPainter(
                      cursorColor: color,
                      cursorPosition: cursorPosition,
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(width: 20),

          // 2. Vertical Brightness (Value) Slider
          GestureDetector(
            onPanUpdate: (details) {
              _handleValueGesture(details.localPosition, 180.0, hue, saturation);
            },
            onPanDown: (details) {
              _handleValueGesture(details.localPosition, 180.0, hue, saturation);
            },
            child: Container(
              width: 18,
              height: 180,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: Colors.black12, width: 1.0),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black,
                    HSVColor.fromAHSV(1.0, hue, saturation, 1.0).toColor(),
                  ],
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Handle
                  Positioned(
                    top: (1.0 - value) * 180.0 - 6, // 6 is half the height of the handle (12)
                    left: -3,
                    right: -3,
                    child: Container(
                      height: 12,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.black45, width: 1.5),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 2, offset: Offset(0, 1)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _handleWheelGesture(Offset localPosition, double radius, double currentValue) {
    final center = Offset(radius, radius);
    final dx = localPosition.dx - center.dx;
    final dy = localPosition.dy - center.dy;

    final distance = math.sqrt(dx * dx + dy * dy);
    final saturation = (distance / radius).clamp(0.0, 1.0);

    double angle = math.atan2(dy, dx);
    if (angle < 0) {
      angle += 2 * math.pi;
    }
    final hue = (angle * 180 / math.pi) % 360;

    // Use current value, but clamp it to avoid completely black if it is 0
    final val = currentValue < 0.01 ? 1.0 : currentValue;
    final newColor = HSVColor.fromAHSV(1.0, hue, saturation, val).toColor();
    onChanged(newColor);
  }

  void _handleValueGesture(Offset localPosition, double sliderHeight, double hue, double saturation) {
    final double value = (1.0 - (localPosition.dy / sliderHeight)).clamp(0.0, 1.0);
    final newColor = HSVColor.fromAHSV(1.0, hue, saturation, value).toColor();
    onChanged(newColor);
  }
}

class ColorWheelPainter extends CustomPainter {
  final Color cursorColor;
  final Offset cursorPosition;

  ColorWheelPainter({
    required this.cursorColor,
    required this.cursorPosition,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final double radius = size.width / 2;
    final center = Offset(radius, radius);

    // 1. Draw the hue wheel using SweepGradient
    final paintHue = Paint()
      ..shader = const SweepGradient(
        colors: [
          Color(0xFFFF0000), // Red
          Color(0xFFFFFF00), // Yellow
          Color(0xFF00FF00), // Green
          Color(0xFF00FFFF), // Cyan
          Color(0xFF0000FF), // Blue
          Color(0xFFFF00FF), // Magenta
          Color(0xFFFF0000), // Red
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paintHue);

    // 2. Draw white overlay using RadialGradient to represent saturation (0 at center, 1 at edge)
    final paintSaturation = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white,
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..blendMode = BlendMode.srcOver;

    canvas.drawCircle(center, radius, paintSaturation);

    // 3. Draw black border line to make it neat
    final paintBorder = Paint()
      ..color = Colors.black12
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(center, radius, paintBorder);

    // 4. Draw cursor shadow
    canvas.drawCircle(
      cursorPosition,
      10,
      Paint()
        ..color = Colors.black.withOpacity(0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );

    // 5. Draw cursor outer white circle
    canvas.drawCircle(cursorPosition, 10, Paint()..color = Colors.white);

    // 6. Draw cursor inner color circle
    canvas.drawCircle(cursorPosition, 7, Paint()..color = cursorColor);

    // 7. Draw cursor border
    canvas.drawCircle(
      cursorPosition,
      10,
      Paint()
        ..color = Colors.black26
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0,
    );
  }

  @override
  bool shouldRepaint(covariant ColorWheelPainter oldDelegate) {
    return oldDelegate.cursorColor != cursorColor || oldDelegate.cursorPosition != cursorPosition;
  }
}

// ==========================================
// Fallback Custom Directory Browser Dialog
// ==========================================
class _DirectoryBrowserDialog extends StatefulWidget {
  final List<Directory> rootDirs;
  final ThemeData theme;
  final bool isDark;

  const _DirectoryBrowserDialog({
    required this.rootDirs,
    required this.theme,
    required this.isDark,
  });

  @override
  State<_DirectoryBrowserDialog> createState() => _DirectoryBrowserDialogState();
}

class _DirectoryBrowserDialogState extends State<_DirectoryBrowserDialog> {
  late Directory _currentDir;
  late Directory _activeRoot;
  List<Directory> _subDirs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _currentDir = widget.rootDirs.first;
    _activeRoot = widget.rootDirs.first;
    _loadSubDirectories();
  }

  void _loadSubDirectories() {
    setState(() {
      _isLoading = true;
      _subDirs = [];
    });

    try {
      if (_currentDir.existsSync()) {
        final List<FileSystemEntity> list = _currentDir.listSync(recursive: false);
        for (final entity in list) {
          if (entity is Directory) {
            final name = p.basename(entity.path);
            if (!name.startsWith('.')) {
              _subDirs.add(entity);
            }
          }
        }
        _subDirs.sort((a, b) => p.basename(a.path).toLowerCase().compareTo(p.basename(b.path).toLowerCase()));
      }
    } catch (e) {
      debugPrint('Failed to list directories: $e');
    }

    setState(() {
      _isLoading = false;
    });
  }

  void _navigateBack() {
    final parent = _currentDir.parent;
    if (parent.path != _currentDir.path) {
      setState(() {
        _currentDir = parent;
        _loadSubDirectories();
      });
    }
  }

  void _createNewFolder() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: widget.theme.colorScheme.surface,
        title: const Text('新建文件夹', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: '请输入文件夹名称',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final name = controller.text.trim();
              if (name.isNotEmpty) {
                try {
                  final newDir = Directory('${_currentDir.path}/$name');
                  if (!newDir.existsSync()) {
                    newDir.createSync();
                  }
                  Navigator.pop(context);
                  _loadSubDirectories();
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('创建文件夹失败: $e')),
                  );
                }
              }
            },
            child: const Text('创建'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final isDark = widget.isDark;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: EdgeInsets.zero,
      title: Row(
        children: [
          Icon(Icons.folder_open_rounded, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          const Text('选择保存文件夹', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.create_new_folder_outlined, size: 20),
            onPressed: _createNewFolder,
            tooltip: '新建文件夹',
          )
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        height: 350,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.onSurface.withOpacity(0.02),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: widget.rootDirs.map((dir) {
                    // Strictly active only when current directory is exactly equal to this root directory path
                    final isSelected = _currentDir.path == dir.path;
                    
                    String displayName;
                    final lowerPath = dir.path.toLowerCase();
                    if (lowerPath == '/storage/emulated/0') {
                      displayName = '主存储空间';
                    } else if (lowerPath.endsWith('/download') || lowerPath.endsWith('\\downloads')) {
                      displayName = '下载目录 (Download)';
                    } else if (lowerPath.endsWith('/pictures') || lowerPath.endsWith('\\pictures')) {
                      displayName = '相册目录 (Pictures)';
                    } else if (lowerPath.contains('com.apple.') || lowerPath.contains('application')) {
                      displayName = '应用沙盒';
                    } else {
                      displayName = p.basename(dir.path);
                      if (displayName.isEmpty) displayName = dir.path;
                    }

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(displayName, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        selected: isSelected,
                        onSelected: (selected) {
                          if (selected) {
                            setState(() {
                              _currentDir = dir;
                              _loadSubDirectories();
                            });
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: theme.colorScheme.onSurface.withOpacity(0.04),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                    onPressed: _navigateBack,
                    tooltip: '返回上级目录',
                  ),
                  Expanded(
                    child: Text(
                      _currentDir.path,
                      style: TextStyle(
                        fontSize: 11,
                        fontFamily: 'monospace',
                        color: theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _subDirs.isEmpty
                      ? Center(
                          child: Text(
                            '无子文件夹',
                            style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withOpacity(0.4)),
                          ),
                        )
                      : ListView.builder(
                          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                          itemCount: _subDirs.length,
                          itemBuilder: (context, index) {
                            final dir = _subDirs[index];
                            final name = p.basename(dir.path);

                            return ListTile(
                              leading: const Icon(Icons.folder_rounded, color: Colors.amber, size: 22),
                              title: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              onTap: () {
                                setState(() {
                                  _currentDir = dir;
                                  _loadSubDirectories();
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      actions: [
        Row(
          children: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () {
                AppSettings.instance.setDownloadPath('');
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('已恢复为默认公共下载目录')),
                );
              },
              child: const Text('恢复默认'),
            ),
            const Spacer(),
            FilledButton(
              onPressed: () {
                AppSettings.instance.setDownloadPath(_currentDir.path);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('下载目录已设定为: ${_currentDir.path}')),
                );
              },
              child: const Text('选择当前目录'),
            ),
          ],
        ),
      ],
    );
  }
}
