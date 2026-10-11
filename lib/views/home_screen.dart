import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'latest_tab.dart';
import 'random_tab.dart';
import 'explore_tab.dart';
import 'settings_tab.dart';
import 'mine_tab.dart';
import '../services/update_service.dart';
import '../services/url_handler_service.dart';
import '../services/widget_service.dart';

class HomeScreen extends StatefulWidget {
  static final GlobalKey<HomeScreenState> homeKey = GlobalKey<HomeScreenState>();

  HomeScreen() : super(key: homeKey);

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  late PageController _pageController;
  bool _isAnimating = false;
  List<Widget>? _displayTabs;

  final List<GlobalKey> _tabKeys = List.generate(5, (_) => GlobalKey());

  late final List<Widget> _tabs = [
    LatestTab(), // Latest Tab (internally uses LatestTab.latestTabKey)
    ExploreTab(key: _tabKeys[1]), // Explore Category / Search
    RandomTab(key: _tabKeys[2]), // Native Random Staggered Grid
    SettingsTab(key: _tabKeys[3]), // Native Settings Tab
    MineTab(key: _tabKeys[4]), // Native Mine/Profile Tab
  ];

  void switchTab(int index) {
    if (!mounted || _isAnimating || index == _currentIndex) return;

    FocusScope.of(context).unfocus();

    final int fromIndex = _currentIndex;
    final int toIndex = index;
    final int distance = (toIndex - fromIndex).abs();

    if (!_pageController.hasClients) {
      setState(() {
        _currentIndex = toIndex;
      });
      return;
    }

    if (distance == 1) {
      setState(() {
        _currentIndex = toIndex;
        _isAnimating = true;
      });
      _pageController.animateToPage(
        toIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        if (mounted) {
          setState(() {
            _isAnimating = false;
          });
        }
      });
    } else {
      final tempTabs = List<Widget>.from(_tabs);
      final int tempTargetIndex = toIndex > fromIndex ? fromIndex + 1 : fromIndex - 1;

      // Place the target tab at the adjacent index
      tempTabs[tempTargetIndex] = _tabs[toIndex];

      // Put placeholders at all other indices to prevent duplicate widgets in the tree
      for (int i = 0; i < tempTabs.length; i++) {
        if (i != fromIndex && i != tempTargetIndex) {
          tempTabs[i] = const SizedBox();
        }
      }

      setState(() {
        _currentIndex = toIndex;
        _displayTabs = tempTabs;
        _isAnimating = true;
      });

      _pageController.animateToPage(
        tempTargetIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ).then((_) {
        if (mounted) {
          _pageController.jumpToPage(toIndex);
          setState(() {
            _displayTabs = null;
            _isAnimating = false;
          });
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _currentIndex);
    _requestPermissions();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      UpdateService.checkUpdate();
      UrlHandlerService.handlePendingUrl(context);
      _checkAndRequestShortcutPermission();
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _requestPermissions() async {
    try {
      if (Platform.isAndroid || Platform.isIOS) {
        await Permission.storage.request();
        await Permission.photos.request();
      }
    } catch (e) {
      debugPrint('Failed to request permissions: $e');
    }
  }

  Future<void> _checkAndRequestShortcutPermission() async {
    if (!Platform.isAndroid) return;
    
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
              '为了能够快捷地将小组件添加至桌面，建议您开启「创建桌面快捷方式」权限。\n\n'
              '请点击“去开启”前往设置界面手动允许该权限。'
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  '暂不需要',
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
    }
  }

  // Fully Native refactored tabs
  // (We use _tabs defined above)

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      extendBody: true, // Allow body content to flow under the floating bottom bar
      body: Stack(
        children: [
          // Content Tab Layer
          PageView(
            controller: _pageController,
            physics: _isAnimating ? const NeverScrollableScrollPhysics() : null,
            onPageChanged: (index) {
              if (!_isAnimating) {
                setState(() {
                  _currentIndex = index;
                });
                FocusScope.of(context).unfocus();
              }
            },
            children: _displayTabs ?? _tabs,
          ),
          
          // Telegram-Style Floating Glassmorphic Navigation Bar
          Positioned(
            left: 18.0,
            right: 18.0,
            bottom: 24.0,
            child: _buildFloatingBottomBar(theme),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingBottomBar(ThemeData theme) {
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36.0),
        boxShadow: [
          // Soft ambient dark diffusion
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.18 : 0.05),
            blurRadius: 32,
            offset: const Offset(0, 8),
            spreadRadius: -2,
          ),
          // Sharp contact shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.08 : 0.02),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(36.0),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8.0, sigmaY: 8.0),
          child: CustomPaint(
            painter: _LiquidGlassPainter(isDark: isDark, borderRadius: 36.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(36.0),
                // High clarity fluid glass base matching reference
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: isDark
                      ? [
                          const Color(0xFF1E1E22).withValues(alpha: 0.40),
                          const Color(0xFF0F0F12).withValues(alpha: 0.22),
                          const Color(0xFF16161A).withValues(alpha: 0.32),
                        ]
                      : [
                          Colors.white.withValues(alpha: 0.45),
                          Colors.white.withValues(alpha: 0.20),
                          Colors.white.withValues(alpha: 0.35),
                        ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(0, Icons.auto_awesome_rounded, '最新', theme),
                    _buildNavItem(1, Icons.explore_rounded, '探索', theme),
                    _buildNavItem(2, Icons.shuffle_rounded, '随机', theme),
                    _buildNavItem(3, Icons.settings_rounded, '设置', theme),
                    _buildNavItem(4, Icons.person_rounded, '我的', theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label, ThemeData theme) {
    final isSelected = _currentIndex == index;
    final isDark = theme.brightness == Brightness.dark;
    final activeColor = theme.colorScheme.primary;
    final inactiveIconColor = isDark ? Colors.white.withValues(alpha: 0.90) : Colors.black87;
    final inactiveTextColor = isDark ? Colors.white.withValues(alpha: 0.70) : Colors.black54;

    return Expanded(
      child: InkWell(
        onTap: () {
          switchTab(index);
        },
        borderRadius: BorderRadius.circular(24.0),
        splashColor: activeColor.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Liquid Bubble Indicator (Matching Apple iOS Liquid Glass pill)
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 5.0),
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: isDark
                              ? [
                                  Colors.white.withValues(alpha: 0.20),
                                  Colors.white.withValues(alpha: 0.07),
                                ]
                              : [
                                  Colors.white.withValues(alpha: 0.65),
                                  Colors.white.withValues(alpha: 0.25),
                                ],
                        )
                      : null,
                  borderRadius: BorderRadius.circular(22.0),
                  border: isSelected
                      ? Border.all(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.28)
                              : Colors.white.withValues(alpha: 0.70),
                          width: 1.0,
                        )
                      : Border.all(
                          color: Colors.transparent,
                          width: 1.0,
                        ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: AnimatedScale(
                  duration: const Duration(milliseconds: 200),
                  scale: isSelected ? 1.05 : 1.0,
                  child: Icon(
                    icon,
                    color: isSelected ? activeColor : inactiveIconColor,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 3.0),

              // Text label
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LiquidGlassPainter extends CustomPainter {
  final bool isDark;
  final double borderRadius;

  _LiquidGlassPainter({required this.isDark, required this.borderRadius});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect,
      Radius.circular(borderRadius),
    );

    // 1. Soft Ambient Specular Rim Bloom (柔和自然边缘弥散 - 无硬塑光感)
    final outerGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4.0)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.35),
                Colors.white.withValues(alpha: 0.10),
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.20),
              ]
            : [
                Colors.white.withValues(alpha: 0.55),
                Colors.white.withValues(alpha: 0.25),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.35),
              ],
        stops: const [0.0, 0.30, 0.70, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, outerGlowPaint);

    canvas.save();
    canvas.clipRRect(rrect);

    // 2. Inner Refraction Lens Glow (紧凑极窄边缘屈光)
    final innerRefractionPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.85, -0.90),
        radius: 0.35,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.02),
                Colors.white.withValues(alpha: 0.0),
              ]
            : [
                Colors.white.withValues(alpha: 0.22),
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.0),
              ],
        stops: const [0.0, 0.30, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, innerRefractionPaint);

    // 3. Secondary Bottom Caustics (底部极微折射)
    final brGlowPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.75, 0.85),
        radius: 0.6,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.01),
                Colors.white.withValues(alpha: 0.0),
              ]
            : [
                Colors.white.withValues(alpha: 0.20),
                Colors.white.withValues(alpha: 0.04),
                Colors.white.withValues(alpha: 0.0),
              ],
        stops: const [0.0, 0.40, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, brGlowPaint);

    // 4. Double Inner Refraction Edge Rim (内嵌柔和双边缘)
    final insetRRect = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular(borderRadius - 1.2),
    );
    final insetRimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.20),
                Colors.white.withValues(alpha: 0.05),
                Colors.white.withValues(alpha: 0.10),
              ]
            : [
                Colors.white.withValues(alpha: 0.40),
                Colors.white.withValues(alpha: 0.12),
                Colors.white.withValues(alpha: 0.25),
              ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawRRect(insetRRect, insetRimPaint);

    canvas.restore();

    // 5. Crisp Rim Border Line (精致自然水滴描边)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? [
                Colors.white.withValues(alpha: 0.45),
                Colors.white.withValues(alpha: 0.18),
                Colors.white.withValues(alpha: 0.08),
                Colors.white.withValues(alpha: 0.28),
              ]
            : [
                Colors.white.withValues(alpha: 0.65),
                Colors.white.withValues(alpha: 0.30),
                Colors.white.withValues(alpha: 0.15),
                Colors.white.withValues(alpha: 0.40),
              ],
        stops: const [0.0, 0.28, 0.72, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, borderPaint);

    // 6. Top Specular Light Beam (顶部柔和顶光光束 - 自然融光)
    final topBeamPath = Path();
    topBeamPath.moveTo(borderRadius * 0.6, 0.6);
    topBeamPath.lineTo(size.width - borderRadius * 0.6, 0.6);

    final topBeamGlowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5)
      ..shader = LinearGradient(
        begin: Alignment.centerLeft,
        end: Alignment.centerRight,
        colors: [
          Colors.white.withValues(alpha: 0.0),
          Colors.white.withValues(alpha: isDark ? 0.35 : 0.55),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);
    canvas.drawPath(topBeamPath, topBeamGlowPaint);

    // 7. Top-Left Specular Corner Arc (左上角精致小巧微点切光)
    final tlArcPath = Path();
    tlArcPath.moveTo(borderRadius + 8, 0.6);
    tlArcPath.lineTo(borderRadius, 0.6);
    tlArcPath.arcToPoint(
      const Offset(0.6, 20.0),
      radius: Radius.circular(borderRadius - 0.6),
      clockwise: false,
    );
    tlArcPath.lineTo(0.6, borderRadius + 6);

    final tlArcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.5)
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.center,
        colors: [
          Colors.white.withValues(alpha: isDark ? 0.50 : 0.70),
          Colors.white.withValues(alpha: isDark ? 0.12 : 0.28),
          Colors.white.withValues(alpha: 0.0),
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, borderRadius * 2, borderRadius * 2));

    canvas.drawPath(tlArcPath, tlArcPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassPainter oldDelegate) {
    return oldDelegate.isDark != isDark || oldDelegate.borderRadius != borderRadius;
  }
}


