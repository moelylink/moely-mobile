import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/kanban_service.dart';
import '../services/widget_service.dart';
import '../utils/toast_helper.dart';

const EdgeInsets _dialogInsetPadding = EdgeInsets.symmetric(horizontal: 20.0, vertical: 24.0);

class KanbanScreen extends StatefulWidget {
  const KanbanScreen({super.key});

  @override
  State<KanbanScreen> createState() => _KanbanScreenState();
}

class _KanbanScreenState extends State<KanbanScreen> with SingleTickerProviderStateMixin {
  late AnimationController _breathingController;
  Timer? _countdownTimer;
  String? _temporaryAction;
  Timer? _temporaryActionTimer;

  final List<_EffectParticle> _confettiParticles = [];
  Timer? _confettiTimer;

  void _triggerConfetti(Offset origin, {bool isHearts = false}) {
    final random = math.Random();
    final List<Color> colors = isHearts 
        ? [Colors.pink, Colors.pinkAccent, Colors.red, Colors.redAccent]
        : [Colors.yellow, Colors.orange, Colors.cyan, Colors.purpleAccent, Colors.greenAccent];

    setState(() {
      for (int i = 0; i < 15; i++) {
        final double angle = random.nextDouble() * 2 * math.pi;
        final double speed = random.nextDouble() * 5 + 3;
        _confettiParticles.add(_EffectParticle(
          position: origin,
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed - 2),
          color: colors[random.nextInt(colors.length)],
          size: random.nextDouble() * 6 + 3,
          opacity: 1.0,
          icon: isHearts ? Icons.favorite_rounded : (random.nextBool() ? Icons.star_rounded : null),
        ));
      }
    });

    _confettiTimer?.cancel();
    _confettiTimer = Timer.periodic(const Duration(milliseconds: 16), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        for (int i = _confettiParticles.length - 1; i >= 0; i--) {
          final p = _confettiParticles[i];
          p.position += p.velocity;
          p.velocity = Offset(p.velocity.dx * 0.95, p.velocity.dy * 0.95 + 0.15);
          p.opacity -= 0.025;
          if (p.opacity <= 0) {
            _confettiParticles.removeAt(i);
          }
        }
        if (_confettiParticles.isEmpty) {
          timer.cancel();
        }
      });
    });
  }

  void _triggerTemporaryAction(String action) {
    _temporaryActionTimer?.cancel();
    setState(() {
      _temporaryAction = action;
    });
    _temporaryActionTimer = Timer(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _temporaryAction = null;
        });
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _breathingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Refresh the screen every second to update countdowns and state progress
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      KanbanService.instance.checkProgress();
      if (mounted) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _breathingController.dispose();
    _countdownTimer?.cancel();
    _temporaryActionTimer?.cancel();
    _confettiTimer?.cancel();
    super.dispose();
  }

  Future<void> _pinWidget() async {
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
            insetPadding: _dialogInsetPadding,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
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

    print('[KanbanScreen] Requesting pinWidget for PetWidgetProvider');
    final success = await WidgetService.pinWidget('PetWidgetProvider');
    print('[KanbanScreen] pinWidget returned: $success');
    if (mounted) {
      if (success) {
        showDialog(
          context: context,
          builder: (context) {
            final theme = Theme.of(context);
            final isDark = theme.brightness == Brightness.dark;
            return AlertDialog(
              insetPadding: _dialogInsetPadding,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Text('添加请求已发送'),
              content: const Text(
                '已向系统桌面发送小组件添加请求。\n\n'
                '说明与排查：\n'
                '1. 如果桌面未出现确认弹窗，请检查是否已授予应用「桌面快捷方式」权限，并确认桌面未开启「锁定桌面布局」；\n'
                '2. 国产系统手动添加指引（推荐）：\n'
                '• ColorOS / Realme：桌面双指捏合或长按 -> 点击「微件」（注意非「卡片」）-> 找到「萌哩」添加；\n'
                '• OriginOS：长按桌面空白处 -> 进入「原子组件/组件」-> 滑到底部「经典组件/安卓微件」-> 添加；\n'
                '• MIUI / HyperOS：长按桌面 -> 点击「添加小部件」-> 滑到底部「支持小部件的应用」-> 添加。'
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
        ToastHelper.show(context, '桌面暂未响应快捷添加，建议长按桌面从「微件/组件」手动添加！', type: ToastType.warning);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('萌哩小屋', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.casino_rounded, color: Colors.amberAccent),
            tooltip: '趣味大转盘',
            onPressed: () => _showLuckyWheelDialog(context, KanbanService.instance),
          ),
          IconButton(
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () => _showHelpDialog(context, theme),
          ),
          IconButton(
            icon: const Icon(Icons.add_home_rounded),
            onPressed: _pinWidget,
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: KanbanService.instance,
        builder: (context, _) {
          final service = KanbanService.instance;
          final state = service.currentState;
          final emoji = service.stateEmoji;
          final currentSkin = service.currentSkin;

          // Night scene mode applies strictly if local time is between 19:00 and 6:00
          final now = DateTime.now();
          final showNightScene = now.hour >= 19 || now.hour < 6;

          // Dynamic coordinates for pet and bowl in the 360x380 manor coordinate space (smaller stickers)
          double petX = 130;
          double petY = 290;
          double bowlX = 220;
          double bowlY = 325;

          if (state == KanbanState.sleeping) {
            petX = 200;
            petY = 85;
          } else if (state == KanbanState.studying) {
            petX = 215;
            petY = 255;
          } else if (state == KanbanState.eating) {
            petX = 75;
            petY = 225;
            bowlX = 40;
            bowlY = 275;
          }

          return Stack(
            children: [
              // 1. Sky Background (Gradient)
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: showNightScene
                          ? [const Color(0xFF0D1B2A), const Color(0xFF1B263B)] // Deep night
                          : [const Color(0xFF38BDF8), const Color(0xFFBAE6FD)], // Bright warm sky
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),

              // 2. Stars at night, clouds during day
              if (showNightScene) ...[
                // Twinkling/shining stars in night sky
                Positioned.fill(
                  child: _MagicParticleField(isDark: true),
                ),
              ] else ...[
                // Sun
                Positioned(
                  top: 90,
                  right: 35,
                  child: const _GlowingSun(),
                ),
                // Floating clouds
                Positioned(
                  top: 55,
                  left: 10 + _breathingController.value * 12,
                  child: Icon(Icons.cloud_queue_rounded, color: Colors.white.withOpacity(0.85), size: 54),
                ),
                Positioned(
                  top: 115,
                  left: 90 - _breathingController.value * 8,
                  child: Icon(Icons.cloud_rounded, color: Colors.white.withOpacity(0.7), size: 40),
                ),
              ],

              // 3. Multi-Layered Grassy Hills (Grassland backdrop)
              // Far Hill
              Positioned.fill(
                child: ClipPath(
                  clipper: _FarHillClipper(),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFA7F3D0).withOpacity(0.7),
                          const Color(0xFF6EE7B7).withOpacity(0.7)
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    foregroundDecoration: showNightScene
                        ? BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.55),
                          )
                        : null,
                  ),
                ),
              ),
              // Mid Hill
              Positioned.fill(
                child: ClipPath(
                  clipper: _MidHillClipper(),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF86EFAC), Color(0xFF4ADE80)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    foregroundDecoration: showNightScene
                        ? BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.5),
                          )
                        : null,
                  ),
                ),
              ),
              // Near Lawn
              Positioned.fill(
                child: ClipPath(
                  clipper: _NearHillClipper(),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF4ADE80), Color(0xFF22C55E)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                    foregroundDecoration: showNightScene
                        ? BoxDecoration(
                            color: const Color(0xFF0F172A).withOpacity(0.45),
                          )
                        : null,
                  ),
                ),
              ),

              // 4. Centered Interactive Manor Area (The Dollhouse Cottage + Pet + Bowl)
              Positioned(
                left: 0,
                right: 0,
                top: MediaQuery.of(context).size.height * 0.5 - 180,
                child: Center(
                  child: SizedBox(
                    width: 360,
                    height: 380,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // The Dollhouse Cottage Image (360x360)
                        Positioned(
                          top: 0,
                          width: 360,
                          height: 360,
                          child: Image.asset(
                            'assets/manor_house.png',
                            fit: BoxFit.contain,
                          ),
                        ),

                        // Night light bulb hanging in the house
                        if (showNightScene)
                          Positioned(
                            top: 175, // lower floor ceiling
                            left: 172, // center
                            child: Icon(
                              Icons.lightbulb_rounded,
                              color: Colors.yellowAccent.shade200,
                              size: 26,
                              shadows: [
                                Shadow(
                                  color: Colors.yellowAccent.withOpacity(0.8),
                                  blurRadius: 15,
                                )
                              ],
                            ),
                          ),

                        // The Pet (Capoo) Sticker
                        Positioned(
                          left: petX,
                          top: petY,
                          child: GestureDetector(
                            onTapDown: (details) {
                              service.touchMascot();
                              _triggerTemporaryAction('touch');
                              // Confetti hearts
                              final renderBox = context.findRenderObject() as RenderBox?;
                              if (renderBox != null) {
                                final localPos = renderBox.globalToLocal(details.globalPosition);
                                _triggerConfetti(localPos, isHearts: true);
                              }
                            },
                            child: Stack(
                              alignment: Alignment.topCenter,
                              clipBehavior: Clip.none,
                              children: [
                                // Speech bubble directly above pet head
                                Positioned(
                                  bottom: 102,
                                  child: _buildDialogueBubble(theme, service.currentBubbleText, showNightScene),
                                ),
                                // Zzz bubble animation if sleeping
                                if (state == KanbanState.sleeping)
                                  const Positioned(
                                    top: -30,
                                    right: -15,
                                    child: _ZzzAnimation(),
                                  ),
                                AnimatedBuilder(
                                  animation: _breathingController,
                                  builder: (context, child) {
                                    return Transform.translate(
                                      offset: Offset(0, _breathingController.value * -5.0),
                                      child: child,
                                    );
                                  },
                                  child: _buildPetImage(state, emoji, _temporaryAction, currentSkin),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Food Bowl
                        if (service.currentBowlFeed > 0 || state == KanbanState.eating)
                          Positioned(
                            left: bowlX,
                            top: bowlY,
                            child: _buildFoodBowl(theme, service.currentBowlFeed, showNightScene),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // 6. Left-Bottom Floating Store Buttons (Vertical/Horizontal list of circular game actions)
              Positioned(
                left: 16,
                bottom: 20,
                child: Row(
                  children: [
                    _ManorButton(
                      icon: Icons.backpack_rounded,
                      label: '道具包',
                      gradientColors: const [Color(0xFF10B981), Color(0xFF047857)], // Emerald teal
                      shadowColor: Colors.tealAccent,
                      onPressed: () => _showInventoryDialog(context, service),
                      badge: (service.speedCardCount + service.doubleFeedCardCount) > 0
                          ? '${service.speedCardCount + service.doubleFeedCardCount}'
                          : null,
                    ),
                    const SizedBox(width: 8),
                    _ManorButton(
                      icon: Icons.store_rounded,
                      label: '庄园商店',
                      gradientColors: const [Color(0xFFFBBF24), Color(0xFFD97706)], // Warm orange
                      shadowColor: Colors.orangeAccent,
                      onPressed: () => _showFoodShopDialog(context, service),
                    ),
                    const SizedBox(width: 8),
                    _ManorButton(
                      icon: Icons.checkroom_rounded,
                      label: '衣帽间',
                      gradientColors: const [Color(0xFFC084FC), Color(0xFF9333EA)], // Warm purple
                      shadowColor: Colors.purpleAccent,
                      onPressed: () => _showDressupDialog(context, service),
                    ),
                  ],
                ),
              ),

              // 7. Right-Bottom Feed Container Button
              Positioned(
                right: 20,
                bottom: 20,
                child: _FeedStockBagButton(
                  service: service,
                  isDark: showNightScene,
                  onTap: () async {
                    if (service.currentState == KanbanState.eating) {
                      _showBowlActionDialog(context, service);
                      return;
                    }
                    if (service.doubleFeedCardCount > 0 && service.feedStock >= 200) {
                      _showFeedChoiceDialog(context, service);
                      return;
                    }
                    final success = await service.feedMascot();
                    if (success) {
                      if (mounted) {
                        ToastHelper.show(context, '倒入饲料，萌哩开始干饭啦！', type: ToastType.success);
                        final size = MediaQuery.of(context).size;
                        _triggerConfetti(Offset(size.width / 2 + 50, size.height / 2 + 90), isHearts: false);
                      }
                    } else {
                      if (service.feedStock < 100) {
                        _triggerTemporaryAction('hungry');
                      }
                    }
                  },
                ),
              ),

              // 8. Floating Signboards & Indicators
              // Growth & Heart indicator at Top-Left
              Positioned(
                top: 150,
                left: 20,
                child: _buildGrowthBoard(theme, service, showNightScene),
              ),

              // State switcher Signboard at Top-Right
              Positioned(
                top: 150,
                right: 20,
                child: _buildStateBoard(theme, service, showNightScene),
              ),

              // Floating lucky wheel on the right side
              Positioned(
                right: 12,
                bottom: 295,
                child: _buildFloatingLuckyWheel(theme, service),
              ),

              // Floating task board on the right side
              Positioned(
                right: 12,
                bottom: 220,
                child: _buildFloatingTaskBoard(theme, service),
              ),

              // Confetti effect overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _ConfettiPainter(_confettiParticles),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDialogueBubble(ThemeData theme, String text, bool isDark) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 180),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B).withOpacity(0.92) : Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                )
              ],
            ),
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: isDark ? const Color(0xFFF8FAFC) : Colors.brown.shade900,
                height: 1.3,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(10, 5),
            painter: _BubbleTrianglePainter(
              color: isDark ? const Color(0xFF38BDF8) : const Color(0xFFF59E0B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHouse(ThemeData theme, KanbanState state, String emoji, String? temporaryAction, String currentSkin, bool showNightScene) {
    final isDark = showNightScene;
    final isSleeping = state == KanbanState.sleeping;
    final isStudying = state == KanbanState.studying;

    return Stack(
      alignment: Alignment.bottomCenter,
      clipBehavior: Clip.none,
      children: [
        // 1. White picket fences on sides
        Positioned(
          left: -65,
          bottom: 0,
          child: _buildFence(),
        ),
        Positioned(
          right: -65,
          bottom: 0,
          child: _buildFence(),
        ),

        // 2. Cute Mailbox on the left side
        Positioned(
          left: -35,
          bottom: 0,
          child: _buildMailbox(isDark),
        ),

        // 3. Flower pots on ground
        Positioned(
          left: 10,
          bottom: 0,
          child: _buildFlowerpot(),
        ),
        Positioned(
          right: 10,
          bottom: 0,
          child: _buildFlowerpot(),
        ),

        // 4. Chimney with heart-shaped smoke rising
        Positioned(
          top: -30,
          left: 60,
          child: Container(
            width: 32,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF312E81), const Color(0xFF1E1B4B)]
                    : [const Color(0xFFE11D48), const Color(0xFF9F1239)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: isDark ? const Color(0xFF4C1D95) : const Color(0xFFFCA5A5), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                )
              ]
            ),
          ),
        ),
        
        // Heart smoke animation above the chimney
        const Positioned(
          top: -55,
          left: 65,
          child: _HeartSmokeAnimation(),
        ),
        
        // Zzz bubble animation if sleeping
        if (isSleeping)
          const Positioned(
            top: -70,
            left: 60,
            child: _ZzzAnimation(),
          ),

        // 5. House Base Wall with wood horizontal planks
        Container(
          width: 320,
          height: 220,
          child: CustomPaint(
            painter: _HouseWallPainter(isDark: isDark),
          ),
        ),

        // 6. Arched steps leading to the door
        Positioned(
          bottom: -4,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 130,
                height: 10,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark ? [const Color(0xFF334155), const Color(0xFF1E293B)] : [const Color(0xFFF1F5F9), const Color(0xFFE2E8F0)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF475569) : const Color(0xFFCBD5E1), width: 1.5),
                ),
              ),
              const SizedBox(height: 1),
              Container(
                width: 160,
                height: 11,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark ? [const Color(0xFF1E293B), const Color(0xFF0F172A)] : [const Color(0xFFE2E8F0), const Color(0xFFCBD5E1)],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: isDark ? const Color(0xFF334155) : const Color(0xFF94A3B8), width: 1.5),
                ),
              ),
            ],
          ),
        ),

        // 7. Arched Doorway (Inside the house)
        Positioned(
          bottom: 0,
          child: Container(
            width: 130,
            height: 155,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark ? [const Color(0xFF13112E), const Color(0xFF0D0B21)] : [const Color(0xFF4E2C0E), const Color(0xFF3A1A05)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(65),
                topRight: Radius.circular(65),
              ),
              border: Border.all(
                color: isDark ? const Color(0xFF00FFFF) : const Color(0xFFFFB03A),
                width: 3.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark ? const Color(0xFF00FFFF).withOpacity(0.3) : const Color(0xFFFFB03A).withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                )
              ]
            ),
            alignment: Alignment.bottomCenter,
            child: Stack(
              alignment: Alignment.bottomCenter,
              children: [
                // Study Lamp Glow
                if (isStudying)
                  Positioned(
                    top: 15,
                    child: Icon(
                      Icons.lightbulb_rounded,
                      color: Colors.yellowAccent.shade200,
                      size: 28,
                      shadows: [
                        Shadow(
                          color: Colors.yellowAccent.withOpacity(0.6),
                          blurRadius: 12,
                        )
                      ],
                    ),
                  ),
                
                // Dim Overlay for sleeping
                if (isSleeping)
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(65),
                        topRight: Radius.circular(65),
                      ),
                    ),
                  ),
                
                // Capoo / Pet (only if not eating)
                if (state != KanbanState.eating)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6.0),
                    child: _buildPetImage(state, emoji, temporaryAction, currentSkin),
                  ),
              ],
            ),
          ),
        ),

        // 8. Cute Hanging Lamp on door side
        Positioned(
          left: 24,
          top: 75,
          child: _GlowLamp(isDark: isDark),
        ),

        // 9. Circular Window (Glowing glass window)
        Positioned(
          top: 45,
          right: 40,
          child: Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: isStudying 
                    ? [Colors.yellowAccent.shade100, Colors.amber.shade400]
                    : (isDark 
                        ? [const Color(0xFFD946EF).withOpacity(0.8), const Color(0xFF4C1D95)]
                        : [Colors.white, const Color(0xFFFFFBEB)]),
              ),
              border: Border.all(color: isDark ? const Color(0xFFD946EF) : const Color(0xFF8B5CF6), width: 3),
              boxShadow: [
                BoxShadow(
                  color: isStudying 
                      ? Colors.amber.withOpacity(0.5) 
                      : (isDark ? const Color(0xFFD946EF).withOpacity(0.4) : Colors.black12),
                  blurRadius: 6,
                  spreadRadius: 1,
                )
              ]
            ),
            child: Stack(
              children: [
                Center(child: Container(width: 2.5, height: 46, color: isDark ? const Color(0xFF4C1D95) : const Color(0xFF8B5CF6))),
                Center(child: Container(width: 46, height: 2.5, color: isDark ? const Color(0xFF4C1D95) : const Color(0xFF8B5CF6))),
              ],
            ),
          ),
        ),

        // 10. Wood nameplate at top wall
        Positioned(
          top: 8,
          left: 0,
          right: 0,
          child: _buildNameplate(isDark),
        ),

        // 11. Custom Tiled Roof
        Positioned(
          top: -40,
          left: -25,
          right: -25,
          child: SizedBox(
            height: 50,
            child: CustomPaint(
              painter: _RoofPainter(isDark: isDark),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFence() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(3, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 35.0 - (index == 1 ? 6.0 : 0.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(4),
            ),
            border: Border.all(color: const Color(0xFFCBD5E1), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 2,
                offset: const Offset(0, 1),
              )
            ]
          ),
        );
      }),
    );
  }

  Widget _buildMailbox(bool isDark) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Wooden stand
        Container(
          width: 5,
          height: 35,
          color: Colors.brown.shade400,
        ),
        // Box head
        Transform.translate(
          offset: const Offset(0, -36),
          child: Container(
            width: 24,
            height: 18,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFFD946EF) : const Color(0xFFEF4444),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(8),
                topRight: Radius.circular(8),
                bottomLeft: Radius.circular(2),
                bottomRight: Radius.circular(2),
              ),
              border: Border.all(color: Colors.white, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black12,
                  blurRadius: 2,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            alignment: Alignment.center,
            child: Container(
              width: 14,
              height: 3,
              color: Colors.yellowAccent,
            ),
          ),
        )
      ],
    );
  }

  Widget _buildFlowerpot() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Foliage / flowers
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(
                color: Colors.greenAccent,
                shape: BoxShape.circle,
              ),
            ),
            Transform.translate(
              offset: const Offset(-3, -2),
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Colors.pinkAccent,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        // Pot
        Container(
          width: 16,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.brown.shade300,
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(4),
              bottomRight: Radius.circular(4),
            ),
            border: Border.all(color: Colors.brown.shade500, width: 1),
          ),
        )
      ],
    );
  }

  Widget _buildNameplate(bool isDark) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(width: 2, height: 10, color: isDark ? const Color(0xFFA78BFA) : Colors.brown.shade400),
            const SizedBox(width: 60),
            Container(width: 2, height: 10, color: isDark ? const Color(0xFFA78BFA) : Colors.brown.shade400),
          ],
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? [const Color(0xFF4C1D95), const Color(0xFF6D28D9)]
                  : [const Color(0xFFD97706), const Color(0xFFF59E0B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isDark ? const Color(0xFFA78BFA) : Colors.white,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: Text(
            '萌哩小屋',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              shadows: [
                Shadow(
                  color: Colors.black.withOpacity(0.3),
                  offset: const Offset(1, 1),
                  blurRadius: 2,
                )
              ]
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodBowl(ThemeData theme, int amount, bool isDark) {
    final service = KanbanService.instance;
    final isEating = service.currentState == KanbanState.eating;
    final isDouble = amount >= 200;
    String labelText = '';

    if (isEating && service.eatingEndTime != null) {
      final diff = service.eatingEndTime!.difference(service.nowTime);
      if (!diff.isNegative) {
        final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
        final hours = diff.inHours;
        final timeStr = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
        labelText = isDouble ? '双倍 $timeStr' : timeStr;
      }
    } else if (amount > 0) {
      labelText = isDouble ? '双倍 200g' : '${amount}g';
    }

    return GestureDetector(
      onTap: () {
        if (isEating) {
          _showBowlActionDialog(context, service);
        } else if (service.currentState == KanbanState.idle) {
          _showFeedChoiceDialog(context, service);
        }
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: isDouble ? 56 : 52,
                height: 26,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: isDark 
                        ? [const Color(0xFFD946EF), const Color(0xFF8B5CF6)] 
                        : isDouble
                            ? [const Color(0xFFF59E0B), const Color(0xFFEA580C)]
                            : [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                    topLeft: Radius.circular(6),
                    topRight: Radius.circular(6),
                  ),
                  border: Border.all(
                    color: isDouble ? const Color(0xFFFEF08A) : Colors.white,
                    width: isDouble ? 2.0 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? const Color(0xFFD946EF) : (isDouble ? const Color(0xFFEA580C) : const Color(0xFFFBBF24))).withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    )
                  ]
                ),
              ),
              Positioned(
                top: isDouble ? 0 : 2,
                child: Container(
                  width: isDouble ? 44 : 40,
                  height: isDouble ? 13 : 10,
                  decoration: BoxDecoration(
                    color: const Color(0xFF78350F),
                    borderRadius: BorderRadius.circular(isDouble ? 6 : 5),
                    border: isDouble ? Border.all(color: const Color(0xFFFBBF24), width: 1.0) : null,
                  ),
                ),
              ),
            ],
          ),
          if (labelText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: isDouble ? const Color(0xFF9A3412).withOpacity(0.85) : Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isDouble ? const Color(0xFFFDE68A) : Colors.white24,
                  width: 0.8,
                ),
              ),
              child: Text(
                labelText,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGrowthBoard(ThemeData theme, KanbanService service, bool isDark) {
    final expValue = service.expToNextLevel > 0 ? (service.exp / service.expToNextLevel).clamp(0.0, 1.0) : 0.0;
    final speedPercent = ((service.speedMultiplier - 1.0) * 100).toInt();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.22),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.amber.withOpacity(0.45), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              )
            ]
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade700,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'LV.${service.level}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'EXP (${service.exp}/${service.expToNextLevel})',
                    style: TextStyle(
                      fontSize: 10, 
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.brown.shade900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              SizedBox(
                width: 110,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: expValue,
                    minHeight: 6,
                    backgroundColor: isDark ? Colors.white12 : Colors.black.withOpacity(0.06),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.amber),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                  const SizedBox(width: 3),
                  Text(
                    '星星: ${service.collectedStars.toStringAsFixed(1)} ⭐',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.bolt_rounded, color: Colors.amber, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '速度加成: +$speedPercent%',
                    style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: isDark ? Colors.cyanAccent : Colors.blue.shade800),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStateBoard(ThemeData theme, KanbanService service, bool isDark) {
    String stateText = '';
    IconData stateIcon = Icons.pets_rounded;
    Color statusColor = Colors.green;

    switch (service.currentState) {
      case KanbanState.idle:
        if (service.isHungry) {
          stateText = '肚子饿';
          stateIcon = Icons.sentiment_dissatisfied_rounded;
          statusColor = Colors.orange.shade700;
        } else {
          stateText = '玩耍中';
          stateIcon = Icons.videogame_asset_rounded;
          statusColor = isDark ? const Color(0xFF00FFC2) : theme.colorScheme.primary;
        }
        break;
      case KanbanState.studying:
        stateText = '学习中';
        stateIcon = Icons.menu_book_rounded;
        statusColor = Colors.orangeAccent;
        break;
      case KanbanState.sleeping:
        stateText = '熟睡中';
        stateIcon = Icons.nights_stay_rounded;
        statusColor = const Color(0xFF60A5FA);
        break;
      case KanbanState.eating:
        String countdownText = '';
        if (service.eatingEndTime != null) {
          final diff = service.eatingEndTime!.difference(service.nowTime);
          if (!diff.isNegative) {
            final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
            final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
            final hours = diff.inHours;
            countdownText = hours > 0 ? ' ($hours:$minutes:$seconds)' : ' ($minutes:$seconds)';
          }
        }
        stateText = '干饭中$countdownText';
        stateIcon = Icons.restaurant_rounded;
        statusColor = const Color(0xFFF87171);
        break;
    }

    return GestureDetector(
      onTap: () {
        if (service.currentState == KanbanState.eating) {
          ToastHelper.show(context, '萌哩正在努力干饭，吃饱前不要打扰它哦~', type: ToastType.warning);
          return;
        }
        
        KanbanState nextState;
        switch (service.currentState) {
          case KanbanState.idle:
            nextState = KanbanState.studying;
            break;
          case KanbanState.studying:
            nextState = KanbanState.sleeping;
            break;
          case KanbanState.sleeping:
          default:
            nextState = KanbanState.idle;
            break;
        }
        service.updateState(nextState);
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isDark ? Colors.black.withOpacity(0.35) : Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: statusColor.withOpacity(0.45), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                )
              ]
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(stateIcon, color: statusColor, size: 16),
                const SizedBox(width: 6),
                Text(
                   stateText,
                   style: TextStyle(
                     fontSize: 11,
                     fontWeight: FontWeight.bold,
                     color: statusColor,
                   ),
                ),
                const SizedBox(width: 4),
                Icon(Icons.swap_horiz_rounded, color: statusColor.withOpacity(0.6), size: 14),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingLuckyWheel(ThemeData theme, KanbanService service) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showLuckyWheelDialog(context, service),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFFC026D3).withOpacity(0.9) : const Color(0xFFD946EF),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(-2, 2),
            )
          ]
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.casino_rounded, color: Colors.white, size: 18),
            SizedBox(height: 4),
            Text(
              '趣味\n转盘',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingTaskBoard(ThemeData theme, KanbanService service) {
    final isDark = theme.brightness == Brightness.dark;
    return GestureDetector(
      onTap: () => _showTasksDialog(context, service),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          color: isDark ? Colors.amber.shade900.withOpacity(0.9) : Colors.amber.shade700,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(16),
            bottomLeft: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 6,
              offset: const Offset(-2, 2),
            )
          ]
        ),
        child: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.assignment_rounded, color: Colors.white, size: 18),
            SizedBox(height: 4),
            Text(
              '日常\n任务',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                height: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPetImage(KanbanState state, String emoji, String? temporaryAction, String currentSkin) {
    String assetPath;
    final skinFolder = (currentSkin == 'classic') ? 'capoo' : currentSkin;
    
    if (currentSkin == 'classic' && temporaryAction == null) {
      switch (state) {
        case KanbanState.idle:
          assetPath = 'assets/pet/work.gif';
          break;
        case KanbanState.studying:
          assetPath = 'assets/pet/work.gif';
          break;
        case KanbanState.sleeping:
          assetPath = 'assets/pet/sleep.gif';
          break;
        case KanbanState.eating:
          assetPath = 'assets/pet/capoo/eating.webp';
          break;
      }
    } else {
      if (temporaryAction != null) {
        assetPath = 'assets/pet/$skinFolder/$temporaryAction.webp';
      } else if (KanbanService.instance.isHungry && state == KanbanState.idle) {
        assetPath = 'assets/pet/$skinFolder/hungry.webp';
      } else {
        switch (state) {
          case KanbanState.idle:
            assetPath = 'assets/pet/$skinFolder/play.webp';
            break;
          case KanbanState.studying:
            assetPath = 'assets/pet/$skinFolder/work.webp';
            break;
          case KanbanState.sleeping:
            assetPath = 'assets/pet/$skinFolder/sleep.webp';
            break;
          case KanbanState.eating:
            assetPath = 'assets/pet/$skinFolder/eating.webp';
            break;
        }
      }
    }
    
    return Image.asset(
      assetPath,
      width: 100,
      height: 100,
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        String fallbackGift;
        switch (state) {
          case KanbanState.idle:
            fallbackGift = 'idle.gif';
            break;
          case KanbanState.studying:
            fallbackGift = 'study.gif';
            break;
          case KanbanState.sleeping:
            fallbackGift = 'sleep.gif';
            break;
          case KanbanState.eating:
            fallbackGift = 'eat.gif';
            break;
        }
        return Image.asset(
          'assets/pet/$fallbackGift',
          width: 100,
          height: 100,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              width: 100,
              height: 100,
              alignment: Alignment.center,
              child: Text(
                emoji,
                style: const TextStyle(fontSize: 42),
              ),
            );
          },
        );
      },
    );
  }

  void _showHelpDialog(BuildContext context, ThemeData theme) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        insetPadding: _dialogInsetPadding,
        title: const Text('如何玩转萌哩小屋？', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          '1. 🥣 **干饭升级**：倒入 100g 饲料需要吃 1 小时。吃完增加经验升级！等级越高，学习与工作速度越快！\n'
          '2. 📝 **学习模式**：每 2 小时消耗 50g 饲料，收获 1 颗星星 ⭐（受等级加速！）。\n'
          '3. 💤 **睡觉模式**：无需消耗饲料，每 6 小时自动产出 1 颗星星 ⭐。\n'
          '4. ⭐ **星星兑换**：收获的星星类似庄园金蛋，可在衣帽间兑换限定专属皮肤装扮！\n'
          '5. ❤️ **抚摸互动**：点击萌哩摸摸头增进感情，每天摸头最多可获得 10 点经验值！\n'
          '6. 📱 **桌面小组件**：可将萌哩添加到手机桌面，随时互动看护！',
          style: TextStyle(height: 1.6),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('我知道了'),
          ),
        ],
      ),
    );
  }


  void _showFoodShopDialog(BuildContext context, KanbanService service) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: _dialogInsetPadding,
              title: const Row(
                children: [
                  Icon(Icons.store_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('庄园良品铺', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.rice_bowl_rounded, color: Colors.orange, size: 16),
                                const SizedBox(width: 4),
                                Text('饲料: ${service.feedStock}g', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            Row(
                              children: [
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text('星星: ${service.collectedStars.toStringAsFixed(1)}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            )
                          ],
                        ),
                      ),

                      // Section 1: Magic Items
                      const Row(
                        children: [
                          Icon(Icons.auto_awesome_rounded, color: Color(0xFF0284C7), size: 16),
                          SizedBox(width: 6),
                          Text('神奇道具', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0284C7))),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Speed Card
                      _buildShopItemTile(
                        icon: Icons.speed_rounded,
                        iconColor: const Color(0xFF06B6D4),
                        title: '时光加速卡 (1张)',
                        subtitle: '立即完成 1 小时的事情（干饭/学习/美梦）\n持有: ${service.speedCardCount}张',
                        actions: [
                          _buildPurchaseButton(
                            label: '0.5星星',
                            enabled: service.collectedStars >= 0.5,
                            color: Colors.amber.shade700,
                            onPressed: () async {
                              final success = await service.buySpeedCardWithStars(0.5, 1);
                              if (success) {
                                setDialogState(() {});
                                if (context.mounted) {
                                  ToastHelper.show(context, '兑换成功，获得 1 张时光加速卡！', type: ToastType.success);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 14),

                      // Double Feed Card
                      _buildShopItemTile(
                        icon: Icons.restaurant_rounded,
                        iconColor: const Color(0xFFEA580C),
                        title: '超级加饭卡 (1张)',
                        subtitle: '可在饭碗放两倍饲料 (200g)，享双倍经验\n持有: ${service.doubleFeedCardCount}张',
                        actions: [
                          _buildPurchaseButton(
                            label: '0.3星星',
                            enabled: service.collectedStars >= 0.3,
                            color: Colors.amber.shade700,
                            onPressed: () async {
                              final success = await service.buyDoubleFeedCardWithStars(0.3, 1);
                              if (success) {
                                setDialogState(() {});
                                if (context.mounted) {
                                  ToastHelper.show(context, '兑换成功，获得 1 张超级加饭卡！', type: ToastType.success);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Section 2: Delicious Feed
                      const Row(
                        children: [
                          Icon(Icons.fastfood_rounded, color: Colors.orange, size: 16),
                          SizedBox(width: 6),
                          Text('口粮美味', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.orange)),
                        ],
                      ),
                      const SizedBox(height: 6),

                      // Selected Grain
                      _buildShopItemTile(
                        icon: Icons.bakery_dining_rounded,
                        iconColor: Colors.orange.shade400,
                        title: '精选杂粮 (100g)',
                        subtitle: '价格: 1.0 颗星星',
                        actions: [
                          _buildPurchaseButton(
                            label: '1.0星星',
                            enabled: service.collectedStars >= 1.0,
                            color: Colors.amber.shade700,
                            onPressed: () async {
                              final success = await service.buyFeedWithStars(1.0, 100);
                              if (success) {
                                setDialogState(() {});
                                if (context.mounted) {
                                  ToastHelper.show(context, '购买成功，获得 100g 饲料！', type: ToastType.success);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                      const Divider(height: 14),

                      // Tuna Feast
                      _buildShopItemTile(
                        icon: Icons.savings_rounded,
                        iconColor: Colors.amber.shade600,
                        title: '金枪鱼豪华大餐 (250g)',
                        subtitle: '价格: 2.0 颗星星',
                        actions: [
                          _buildPurchaseButton(
                            label: '2.0星星',
                            enabled: service.collectedStars >= 2.0,
                            color: Colors.amber.shade700,
                            onPressed: () async {
                              final success = await service.buyFeedWithStars(2.0, 250);
                              if (success) {
                                setDialogState(() {});
                                if (context.mounted) {
                                  ToastHelper.show(context, '购买成功，获得 250g 饲料！', type: ToastType.success);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('离开商店'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildShopItemTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required List<Widget> actions,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(subtitle, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: actions,
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton({
    required String label,
    required bool enabled,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        elevation: 0,
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: enabled ? onPressed : null,
      child: Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }

  void _showInventoryDialog(BuildContext context, KanbanService service) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final isEating = service.currentState == KanbanState.eating;
            final isStudying = service.currentState == KanbanState.studying;
            final isSleeping = service.currentState == KanbanState.sleeping;
            final isIdle = service.currentState == KanbanState.idle;

            // Speed Card Status Hint
            String speedHint;
            if (isEating) {
              speedHint = '干饭中：立即缩短 1 小时干饭时间';
            } else if (isStudying) {
              speedHint = '学习中：立即推进 1 小时学业产出';
            } else if (isSleeping) {
              speedHint = '美梦中：立即推进 1 小时睡眠产出';
            } else {
              speedHint = '闲逛中：请先让萌哩干饭、学习或睡觉';
            }
            final canUseSpeed = service.speedCardCount > 0 && !isIdle;

            // Double Feed Card Status Hint
            String doubleFeedHint;
            bool canUseDoubleFeed = false;
            if (isEating) {
              if (service.currentBowlFeed >= 200) {
                doubleFeedHint = '饭碗中已装满 200g 双倍大餐';
                canUseDoubleFeed = false;
              } else if (service.feedStock < 100) {
                doubleFeedHint = '饲料库存不足 100g，无法追加';
                canUseDoubleFeed = false;
              } else {
                doubleFeedHint = '干饭中：可追加 100g 升级为双倍大餐';
                canUseDoubleFeed = service.doubleFeedCardCount > 0;
              }
            } else if (isIdle) {
              if (service.feedStock < 200) {
                doubleFeedHint = '饲料库存不足 200g，无法倒双倍饲料';
                canUseDoubleFeed = false;
              } else {
                doubleFeedHint = '空闲中：倒入 200g 双倍大餐（吃 2 小时）';
                canUseDoubleFeed = service.doubleFeedCardCount > 0;
              }
            } else {
              doubleFeedHint = '请等萌哩回到空闲或干饭时使用';
              canUseDoubleFeed = false;
            }

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: _dialogInsetPadding,
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.backpack_rounded, color: Color(0xFF10B981), size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Text('庄园道具包', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Resource Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.rice_bowl_rounded, color: Colors.orange, size: 16),
                                const SizedBox(width: 4),
                                Text('${service.feedStock}g', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                const SizedBox(width: 12),
                                const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                                const SizedBox(width: 4),
                                Text(service.collectedStars.toStringAsFixed(1), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ],
                            ),
                            InkWell(
                              onTap: () {
                                Navigator.pop(context);
                                _showFoodShopDialog(context, service);
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                child: Row(
                                  children: [
                                    Text('商店补充', style: TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                    Icon(Icons.chevron_right_rounded, size: 16, color: Colors.blue),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Card 1: Speed Card
                      _buildInventoryItemCard(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.speed_rounded,
                        iconBgColors: const [Color(0xFF06B6D4), Color(0xFF0284C7)],
                        title: '时光加速卡',
                        count: service.speedCardCount,
                        desc: '立即完成 1 小时的事情（干饭、学习或美梦）。',
                        hint: speedHint,
                        buttonLabel: '立即加速',
                        canUse: canUseSpeed,
                        onUse: () async {
                          final success = await service.useSpeedCard();
                          if (success) {
                            setDialogState(() {});
                            if (context.mounted) {
                              ToastHelper.show(context, '加速卡生效，时间快进 1 小时！', type: ToastType.success);
                              final size = MediaQuery.of(context).size;
                              _triggerConfetti(Offset(size.width / 2, size.height / 2), isHearts: false);
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 12),

                      // Card 2: Double Feed Card
                      _buildInventoryItemCard(
                        theme: theme,
                        isDark: isDark,
                        icon: Icons.restaurant_rounded,
                        iconBgColors: const [Color(0xFFF59E0B), Color(0xFFEA580C)],
                        title: '超级加饭卡',
                        count: service.doubleFeedCardCount,
                        desc: '在饭碗放两倍饲料 (200g)，吃 2 小时并收获双倍经验 (+20 EXP)。',
                        hint: doubleFeedHint,
                        buttonLabel: isEating ? '追加饲料' : '双倍开饭',
                        canUse: canUseDoubleFeed,
                        onUse: () async {
                          final success = await service.useDoubleFeedCard();
                          if (success) {
                            setDialogState(() {});
                            if (context.mounted) {
                              ToastHelper.show(context, '加饭卡生效，双倍大餐就绪！', type: ToastType.success);
                              final size = MediaQuery.of(context).size;
                              _triggerConfetti(Offset(size.width / 2, size.height / 2), isHearts: false);
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                )
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildInventoryItemCard({
    required ThemeData theme,
    required bool isDark,
    required IconData icon,
    required List<Color> iconBgColors,
    required String title,
    required int count,
    required String desc,
    required String hint,
    required String buttonLabel,
    required bool canUse,
    required VoidCallback onUse,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withOpacity(0.04) : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: iconBgColors),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(height: 2),
                    Text(desc, style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black54)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: count > 0 
                      ? const Color(0xFF10B981).withOpacity(0.15) 
                      : (isDark ? Colors.white10 : Colors.grey.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'x$count',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: count > 0 
                        ? const Color(0xFF10B981) 
                        : (isDark ? Colors.white38 : Colors.grey.shade500),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  hint,
                  style: TextStyle(
                    fontSize: 11,
                    color: canUse 
                        ? (isDark ? const Color(0xFF38BDF8) : const Color(0xFF0284C7))
                        : (isDark ? Colors.white38 : Colors.black38),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: iconBgColors.first,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  elevation: 0,
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: canUse ? onUse : null,
                child: Text(buttonLabel, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showBowlActionDialog(BuildContext context, KanbanService service) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            String leftTime = '';
            if (service.eatingEndTime != null) {
              final diff = service.eatingEndTime!.difference(service.nowTime);
              if (!diff.isNegative) {
                final m = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
                final s = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
                final h = diff.inHours;
                leftTime = h > 0 ? '$h小时$m分$s秒' : '$m分$s秒';
              }
            }
            final isDouble = service.currentBowlFeed >= 200;

            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: _dialogInsetPadding,
              title: const Row(
                children: [
                  Icon(Icons.rice_bowl_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('干饭进行中', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('饭碗状态：${service.currentBowlFeed}g ${isDouble ? "双倍大餐" : "精选饲料"}'),
                  const SizedBox(height: 4),
                  Text('预计剩余：$leftTime', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                  const SizedBox(height: 12),
                  const Divider(),
                  // Option 1: Use Speed Card
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06B6D4).withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.speed_rounded, color: Color(0xFF06B6D4)),
                    ),
                    title: const Text('时光加速卡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    subtitle: Text('立即减少 1 小时 (持有: ${service.speedCardCount}张)', style: const TextStyle(fontSize: 11)),
                    trailing: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF06B6D4),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        elevation: 0,
                      ),
                      onPressed: service.speedCardCount > 0
                          ? () async {
                              final success = await service.useSpeedCard();
                              if (success) {
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ToastHelper.show(context, '加速卡生效！', type: ToastType.success);
                                  final size = MediaQuery.of(context).size;
                                  _triggerConfetti(Offset(size.width / 2, size.height / 2), isHearts: false);
                                }
                              }
                            }
                          : null,
                      child: const Text('加速1h'),
                    ),
                  ),
                  if (!isDouble) ...[
                    const Divider(),
                    // Option 2: Use Double Feed Card
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEA580C).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C)),
                      ),
                      title: const Text('超级加饭卡', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      subtitle: Text('追加 100g 升级双倍大餐 (持有: ${service.doubleFeedCardCount}张)', style: const TextStyle(fontSize: 11)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFEA580C),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          elevation: 0,
                        ),
                        onPressed: (service.doubleFeedCardCount > 0 && service.feedStock >= 100)
                            ? () async {
                                final success = await service.useDoubleFeedCard();
                                if (success) {
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ToastHelper.show(context, '已升级为双倍大餐！', type: ToastType.success);
                                    final size = MediaQuery.of(context).size;
                                    _triggerConfetti(Offset(size.width / 2, size.height / 2), isHearts: false);
                                  }
                                }
                              }
                            : null,
                        child: const Text('加饭'),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showFeedChoiceDialog(BuildContext context, KanbanService service) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: theme.colorScheme.surface,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: _dialogInsetPadding,
          title: const Row(
            children: [
              Icon(Icons.rice_bowl_rounded, color: Colors.orange),
              SizedBox(width: 8),
              Text('准备喂食萌哩', style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.bakery_dining_rounded, color: Colors.orange),
                ),
                title: const Text('普通喂食 (100g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: const Text('耗时 1 小时，获得 10 EXP\n消耗 100g 饲料', style: TextStyle(fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: service.feedStock >= 100
                      ? () async {
                          Navigator.pop(context);
                          final success = await service.feedMascot();
                          if (success && context.mounted) {
                            ToastHelper.show(context, '倒入饲料，萌哩开始干饭啦！', type: ToastType.success);
                            final size = MediaQuery.of(context).size;
                            _triggerConfetti(Offset(size.width / 2 + 50, size.height / 2 + 90), isHearts: false);
                          }
                        }
                      : null,
                  child: const Text('开饭'),
                ),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEA580C).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.restaurant_rounded, color: Color(0xFFEA580C)),
                ),
                title: const Text('超级加饭卡 (200g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                subtitle: Text('放两倍饲料，耗时 2 小时，获 20 EXP\n需消耗 200g 饲料 (持有: ${service.doubleFeedCardCount}张)', style: const TextStyle(fontSize: 11)),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEA580C),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                  onPressed: (service.doubleFeedCardCount > 0 && service.feedStock >= 200)
                      ? () async {
                          Navigator.pop(context);
                          final success = await service.useDoubleFeedCard();
                          if (success && context.mounted) {
                            ToastHelper.show(context, '使用了加饭卡，200g 双倍大餐就绪！', type: ToastType.success);
                            final size = MediaQuery.of(context).size;
                            _triggerConfetti(Offset(size.width / 2 + 50, size.height / 2 + 90), isHearts: false);
                          }
                        }
                      : null,
                  child: const Text('双倍喂'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            )
          ],
        );
      },
    );
  }

  void _showDressupDialog(BuildContext context, KanbanService service) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final skinList = [
      {
        'id': 'capoo',
        'name': '猫猫虫 Capoo',
        'cost': 0,
        'desc': '人见人爱的猫猫虫，爱吃肉！',
        'icon': '🐱',
      },
      {
        'id': 'classic',
        'name': '经典小鸟萌哩',
        'cost': 0,
        'desc': '勤劳可爱的小黄鸟萌哩。',
        'icon': '🐣',
      },
      {
        'id': 'kitty',
        'name': '粉嫩小猫咪',
        'cost': 3,
        'desc': '傲娇可爱的粉红小野猫。',
        'icon': '🐈',
      },
      {
        'id': 'siamese',
        'name': '优雅暹罗猫',
        'cost': 4,
        'desc': '高贵优雅的糊脸小暹罗，粘人好动！',
        'icon': '😺',
      },
      {
        'id': 'salary',
        'name': '月薪喵',
        'cost': 5,
        'desc': '打工人的月薪喵，疯狂赚喵粮！',
        'icon': '💰',
      },
      {
        'id': 'space',
        'name': '太空探险猫',
        'cost': 6,
        'desc': '来自赛博坦星的机甲猫。',
        'icon': '🚀',
      },
    ];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: _dialogInsetPadding,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.checkroom_rounded, color: Colors.purpleAccent),
                      SizedBox(width: 8),
                      Text('萌哩衣帽间', style: TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Row(
                    children: [
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 14),
                      const SizedBox(width: 2),
                      Text(service.collectedStars.toStringAsFixed(1), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.amber)),
                    ],
                  )
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 350,
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const BouncingScrollPhysics(),
                  itemCount: skinList.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final skin = skinList[index];
                    final id = skin['id'] as String;
                    final name = skin['name'] as String;
                    final cost = skin['cost'] as int;
                    final desc = skin['desc'] as String;
                    final iconStr = skin['icon'] as String;
                    
                    final isUnlocked = service.unlockedSkins.contains(id);
                    final isActive = service.currentSkin == id;

                    Widget trailingWidget;
                    if (isActive) {
                      trailingWidget = const Text(
                        '已穿戴',
                        style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 13),
                      );
                    } else if (isUnlocked) {
                      trailingWidget = OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: Colors.purpleAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: () async {
                          final success = await service.selectSkin(id);
                          if (success) {
                            setDialogState(() {});
                            if (context.mounted) {
                              ToastHelper.show(context, '换装成功！', type: ToastType.success);
                            }
                          }
                        },
                        child: const Text('穿戴', style: TextStyle(color: Colors.purpleAccent)),
                      );
                    } else {
                      trailingWidget = ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.amber.shade700,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: service.collectedStars >= cost
                            ? () async {
                                final success = await service.unlockSkin(id, cost.toDouble());
                                if (success) {
                                  setDialogState(() {});
                                  if (context.mounted) {
                                    ToastHelper.show(context, '成功解锁 $name！', type: ToastType.success);
                                  }
                                }
                              }
                            : null,
                        icon: const Icon(Icons.star_rounded, size: 12),
                        label: Text('解锁 ($cost⭐)'),
                      );
                    }

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E293B) : Colors.purple.shade50,
                          shape: BoxShape.circle,
                        ),
                        alignment: Alignment.center,
                        child: Text(iconStr, style: const TextStyle(fontSize: 24)),
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Text(desc, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                      trailing: trailingWidget,
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('离开衣帽间'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showTasksDialog(BuildContext context, KanbanService service) {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final canClaim = service.canClaimDailyFeed;
            return AlertDialog(
              backgroundColor: Theme.of(context).colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              insetPadding: _dialogInsetPadding,
              title: const Row(
                children: [
                  Icon(Icons.task_alt_rounded, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text('庄园日常任务', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.event_available_rounded, color: Colors.green),
                    title: const Text('每日庄园签到', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: const Text('每日首次进入庄园，可领取 100g 饲料', style: TextStyle(fontSize: 12)),
                    trailing: canClaim
                        ? ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blueAccent,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () async {
                              final success = await service.claimDailyFeed();
                              if (success) {
                                setDialogState(() {});
                                if (context.mounted) {
                                  ToastHelper.show(context, '签到成功，领取 100g 饲料！', type: ToastType.success);
                                }
                              }
                            },
                            child: const Text('领取'),
                          )
                        : const Text('已领取', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                  ),
                  const Divider(),
                  const ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.wallpaper_rounded, color: Colors.purpleAccent),
                    title: Text('欣赏或保存壁纸', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text('在壁纸浏览器下载/保存精美插图，即可获赠 50g 饲料', style: TextStyle(fontSize: 12)),
                    trailing: Text('自动触发', style: TextStyle(color: Colors.blueGrey, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('关闭'),
                )
              ],
            );
          },
        );
      },
    );
  }

  void _showLuckyWheelDialog(BuildContext context, KanbanService service) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return _LuckyWheelDialogContent(
          service: service,
          onConfetti: () {
            if (mounted) {
              final size = MediaQuery.of(context).size;
              _triggerConfetti(Offset(size.width / 2, size.height / 2), isHearts: false);
            }
          },
        );
      },
    );
  }
}

class _LuckyWheelDialogContent extends StatefulWidget {
  final KanbanService service;
  final VoidCallback onConfetti;

  const _LuckyWheelDialogContent({
    required this.service,
    required this.onConfetti,
  });

  @override
  State<_LuckyWheelDialogContent> createState() => _LuckyWheelDialogContentState();
}

class _LuckyWheelDialogContentState extends State<_LuckyWheelDialogContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _spinController;
  late Animation<double> _spinAnimation;
  double _currentRotation = 0.0;
  bool _isSpinning = false;
  String _resultMessage = '消耗 100g 饲料抽奖，好运连连！';
  Map<String, dynamic>? _lastPrize;

  static const List<Map<String, dynamic>> _prizeConfigs = [
    {
      'name': '谢谢惠顾',
      'icon': Icons.sentiment_neutral_rounded,
      'bgColor': Color(0xFFF1F5F9), // 浅雾灰
      'textColor': Color(0xFF475569),
      'iconColor': Color(0xFF64748B),
    },
    {
      'name': '50g饲料',
      'icon': Icons.bakery_dining_rounded,
      'bgColor': Color(0xFFFEF3C7), // 奶黄
      'textColor': Color(0xFF92400E),
      'iconColor': Color(0xFFD97706),
    },
    {
      'name': '100g饲料',
      'icon': Icons.fastfood_rounded,
      'bgColor': Color(0xFFFED7AA), // 杏橙
      'textColor': Color(0xFF9A3412),
      'iconColor': Color(0xFFEA580C),
    },
    {
      'name': '150g饲料',
      'icon': Icons.rice_bowl_rounded,
      'bgColor': Color(0xFFFDE68A), // 暖黄
      'textColor': Color(0xFF854D0E),
      'iconColor': Color(0xFFCA8A04),
    },
    {
      'name': '200g饲料',
      'icon': Icons.restaurant_rounded,
      'bgColor': Color(0xFFFDBA74), // 活力橙
      'textColor': Color(0xFF9A3412),
      'iconColor': Color(0xFFEA580C),
    },
    {
      'name': '星星*1',
      'icon': Icons.star_rounded,
      'bgColor': Color(0xFFDDD6FE), // 浅紫
      'textColor': Color(0xFF5B21B6),
      'iconColor': Color(0xFF7C3AED),
    },
    {
      'name': '加速卡',
      'icon': Icons.speed_rounded,
      'bgColor': Color(0xFFBAE6FD), // 青蓝
      'textColor': Color(0xFF0369A1),
      'iconColor': Color(0xFF0284C7),
    },
    {
      'name': '加饭卡',
      'icon': Icons.dinner_dining_rounded,
      'bgColor': Color(0xFFFECDD3), // 蜜桃粉
      'textColor': Color(0xFF9F1239),
      'iconColor': Color(0xFFE11D48),
    },
  ];

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3800),
    );
    _spinAnimation = AlwaysStoppedAnimation(_currentRotation);
  }

  @override
  void dispose() {
    _spinController.dispose();
    super.dispose();
  }

  Future<void> _startSpin() async {
    if (_isSpinning) return;

    if (widget.service.feedStock < 100) {
      ToastHelper.show(context, '饲料不足 100g 无法抽奖，快去完成任务领饲料吧！', type: ToastType.warning);
      return;
    }

    final result = await widget.service.spinLuckyWheel();
    if (result == null) return;

    final targetIndex = result['index'] as int;
    final prize = result['prize'] as Map<String, dynamic>;

    setState(() {
      _isSpinning = true;
      _lastPrize = null;
      _resultMessage = '大转盘飞速旋转中，好运降临中……';
    });

    // 计算旋转停止的角度
    const double sectorAngle = 2 * math.pi / 8;
    final double currentMod = _currentRotation % (2 * math.pi);
    final double targetAngleMod = (2 * math.pi - (targetIndex * sectorAngle)) % (2 * math.pi);
    double diff = targetAngleMod - currentMod;
    if (diff < 0) diff += 2 * math.pi;

    // 至少转动 5 整圈保证物理惯性体验
    final double spinRounds = 5 * 2 * math.pi;
    final double endAngle = _currentRotation + spinRounds + diff;

    _spinAnimation = Tween<double>(begin: _currentRotation, end: endAngle).animate(
      CurvedAnimation(
        parent: _spinController,
        curve: Curves.fastLinearToSlowEaseIn,
      ),
    );

    _spinController.reset();
    _spinController.forward().then((_) {
      if (!mounted) return;
      _currentRotation = endAngle % (2 * math.pi);
      setState(() {
        _isSpinning = false;
        _lastPrize = prize;
        if (prize['id'] == 'thanks') {
          _resultMessage = '抽奖结果：谢谢惠顾！下次一定会更好运~';
        } else {
          _resultMessage = '恭喜抽中：${prize['name']}！已放入背包与庄园';
        }
      });

      if (prize['id'] != 'thanks') {
        widget.onConfetti();
        ToastHelper.show(context, '恭喜获得 ${prize['name']}！', type: ToastType.success);
      } else {
        ToastHelper.show(context, '谢谢惠顾，下次好运！', type: ToastType.info);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final service = widget.service;

    return AlertDialog(
      backgroundColor: theme.colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: _dialogInsetPadding,
      contentPadding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
      titlePadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: const Color(0xFFD946EF).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.casino_rounded, color: Color(0xFFD946EF), size: 22),
              ),
              const SizedBox(width: 8),
              const Text('趣味大转盘', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 20),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: _isSpinning ? null : () => Navigator.pop(context),
          ),
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 资源状态栏
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.rice_bowl_rounded, color: Colors.orange, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '饲料: ${service.feedStock}g',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: service.feedStock >= 100 ? Colors.orange.shade700 : Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.star_rounded, color: Colors.amber, size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '星星: ${service.collectedStars.toStringAsFixed(1)}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        const Icon(Icons.backpack_rounded, color: Color(0xFF10B981), size: 16),
                        const SizedBox(width: 4),
                        Text(
                          '卡片: ${service.speedCardCount + service.doubleFeedCardCount}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 大转盘区域（直径 264px）
              SizedBox(
                width: 264,
                height: 264,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 转盘本体
                    AnimatedBuilder(
                      animation: _spinController,
                      builder: (context, child) {
                        return CustomPaint(
                          size: const Size(264, 264),
                          painter: _LuckyWheelPainter(
                            rotationAngle: _spinAnimation.value,
                            prizes: _prizeConfigs,
                          ),
                        );
                      },
                    ),

                    // 正上方固定指针
                    Positioned(
                      top: 0,
                      child: _WheelArrowPointer(),
                    ),

                    // 中心 GO / 抽奖按钮
                    GestureDetector(
                      onTap: _isSpinning ? null : _startSpin,
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: const LinearGradient(
                            colors: [Color(0xFFF59E0B), Color(0xFFEA580C)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          border: Border.all(color: Colors.white, width: 3),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFEA580C).withOpacity(0.4),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _isSpinning ? '...' : 'GO',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Text(
                                '100g/次',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // 抽奖结果 / 提示横幅
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: _lastPrize != null && _lastPrize!['id'] != 'thanks'
                      ? const Color(0xFF10B981).withOpacity(0.12)
                      : (isDark ? Colors.white.withOpacity(0.05) : Colors.amber.shade50),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _lastPrize != null && _lastPrize!['id'] != 'thanks'
                        ? const Color(0xFF10B981).withOpacity(0.4)
                        : (isDark ? Colors.white12 : Colors.amber.shade200),
                  ),
                ),
                child: Text(
                  _resultMessage,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: _lastPrize != null && _lastPrize!['id'] != 'thanks'
                        ? const Color(0xFF047857)
                        : (isDark ? Colors.amber.shade200 : Colors.amber.shade900),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // 奖品速览胶囊
              Wrap(
                spacing: 6,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: _prizeConfigs.map((p) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: (p['bgColor'] as Color),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      p['name'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: p['textColor'] as Color,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSpinning ? null : () => Navigator.pop(context),
          child: const Text('关闭'),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFEA580C),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            elevation: 0,
          ),
          onPressed: _isSpinning ? null : _startSpin,
          child: Text(_isSpinning ? '抽奖中...' : '抽奖 (消耗100g)'),
        ),
      ],
    );
  }
}

class _WheelArrowPointer extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(24, 28),
      painter: _PointerPainter(),
    );
  }
}

class _PointerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    // 倒三角形指针指向转盘正上方
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();

    // 阴影
    canvas.drawShadow(path, Colors.black, 4, true);

    // 渐变填充
    final paint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE11D48), Color(0xFFBE123C)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    // 白色描边
    final strokePaint = Paint()
      ..color = Colors.white
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawPath(path, strokePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _LuckyWheelPainter extends CustomPainter {
  final double rotationAngle;
  final List<Map<String, dynamic>> prizes;

  _LuckyWheelPainter({
    required this.rotationAngle,
    required this.prizes,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const double sectorAngle = 2 * math.pi / 8;

    // 1. 绘制外底盘与金边
    final borderPaint = Paint()
      ..color = const Color(0xFFF59E0B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0;

    final outerBgPaint = Paint()
      ..color = const Color(0xFFB45309)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, outerBgPaint);

    // 2. 旋转绘制 8 个扇区
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);
    canvas.translate(-center.dx, -center.dy);

    final sectorRadius = radius - 4.0;
    final linePaint = Paint()
      ..color = Colors.white.withOpacity(0.9)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    for (int i = 0; i < 8; i++) {
      final double startAngle = i * sectorAngle - math.pi / 2 - sectorAngle / 2;
      final fillPaint = Paint()
        ..color = prizes[i]['bgColor'] as Color
        ..style = PaintingStyle.fill;

      // 绘制扇形填充
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: sectorRadius),
        startAngle,
        sectorAngle,
        true,
        fillPaint,
      );

      // 绘制白色分界线
      final endX = center.dx + sectorRadius * math.cos(startAngle);
      final endY = center.dy + sectorRadius * math.sin(startAngle);
      canvas.drawLine(center, Offset(endX, endY), linePaint);

      // 绘制扇区内的矢量图标与文本
      canvas.save();
      canvas.translate(center.dx, center.dy);
      final double midAngle = startAngle + sectorAngle / 2;
      canvas.rotate(midAngle + math.pi / 2);

      // 绘制矢量图标
      final icon = prizes[i]['icon'] as IconData;
      final iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(icon.codePoint),
          style: TextStyle(
            fontSize: 20,
            fontFamily: icon.fontFamily,
            package: icon.fontPackage,
            color: prizes[i]['iconColor'] as Color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      iconPainter.paint(canvas, Offset(-iconPainter.width / 2, -sectorRadius * 0.74));

      // 绘制奖品文字
      final name = prizes[i]['name'] as String;
      final textPainter = TextPainter(
        text: TextSpan(
          text: name,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: prizes[i]['textColor'] as Color,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(canvas, Offset(-textPainter.width / 2, -sectorRadius * 0.48));

      canvas.restore();
    }

    // 绘制外圈金色边框
    canvas.drawCircle(center, sectorRadius, borderPaint);

    // 绘制外圈 16 颗小圆点灯
    final dotPaintWhite = Paint()..color = Colors.white;
    final dotPaintAmber = Paint()..color = const Color(0xFFFEF08A);
    const int dotCount = 16;
    for (int i = 0; i < dotCount; i++) {
      final double angle = i * (2 * math.pi / dotCount);
      final dotX = center.dx + (radius - 2.0) * math.cos(angle);
      final dotY = center.dy + (radius - 2.0) * math.sin(angle);
      canvas.drawCircle(Offset(dotX, dotY), 2.0, i.isEven ? dotPaintAmber : dotPaintWhite);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _LuckyWheelPainter oldDelegate) {
    return oldDelegate.rotationAngle != rotationAngle;
  }
}

class _RoofClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(size.width * 0.15, 0);
    path.lineTo(size.width * 0.85, 0);
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ZzzAnimation extends StatefulWidget {
  const _ZzzAnimation();

  @override
  State<_ZzzAnimation> createState() => _ZzzAnimationState();
}

class _ZzzAnimationState extends State<_ZzzAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final val = _controller.value;
        return Opacity(
          opacity: (1.0 - val).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(val * 15, -val * 40),
            child: Text(
              val < 0.33 ? 'z' : (val < 0.66 ? 'zZ' : 'zZZ'),
              style: TextStyle(
                fontSize: 14 + val * 8,
                fontWeight: FontWeight.bold,
                color: Colors.blue.shade300,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _BubbleTailClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.lineTo(size.width / 2, size.height);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

// ----------------------------------------------------
// Redesigned Extreme Color & Cozy Cottage Helper widgets
// ----------------------------------------------------

Widget _buildGlowingMoon() {
  return Stack(
    alignment: Alignment.center,
    children: [
      // Outer glow
      Container(
        width: 66,
        height: 66,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0xFF00F0FF).withOpacity(0.12),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF00F0FF).withOpacity(0.35),
              blurRadius: 20,
              spreadRadius: 2,
            )
          ]
        ),
      ),
      // Crescent Moon
      const Icon(
        Icons.nightlight_round,
        color: Color(0xFFE0F7FA),
        size: 46,
      ),
    ],
  );
}

class _MagicParticleField extends StatefulWidget {
  final bool isDark;
  const _MagicParticleField({required this.isDark});

  @override
  State<_MagicParticleField> createState() => _MagicParticleFieldState();
}

class _MagicParticleFieldState extends State<_MagicParticleField> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<_Particle> _particles = [];

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    final random = math.Random();
    for (int i = 0; i < 20; i++) {
      _particles.add(_Particle(
        x: random.nextDouble(),
        y: random.nextDouble(),
        size: random.nextDouble() * 3 + 2,
        speed: random.nextDouble() * 0.04 + 0.015,
        opacity: random.nextDouble() * 0.55 + 0.25,
        angle: random.nextDouble() * math.pi * 2,
      ));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final random = math.Random();
        for (var p in _particles) {
          p.y -= p.speed * 0.01;
          p.x += math.sin(p.angle + _controller.value * math.pi * 2) * 0.0015;
          if (p.y < 0) {
            p.y = 1.0;
            p.x = random.nextDouble();
          }
        }
        return CustomPaint(
          painter: _ParticlePainter(particles: _particles, isDark: widget.isDark),
          child: Container(),
        );
      },
    );
  }
}

class _Particle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;
  double angle;

  _Particle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
    required this.angle,
  });
}

class _ParticlePainter extends CustomPainter {
  final List<_Particle> particles;
  final bool isDark;

  _ParticlePainter({required this.particles, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final glowPaint = Paint()
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    // Draw background stars for night mode
    if (isDark) {
      final starRandom = math.Random(100);
      for (int i = 0; i < 18; i++) {
        final sx = starRandom.nextDouble() * size.width;
        final sy = starRandom.nextDouble() * (size.height * 0.42);
        final opacity = 0.25 + (math.sin(DateTime.now().millisecondsSinceEpoch / 500 + i) + 1.0) / 2.0 * 0.65;
        final starSize = starRandom.nextDouble() * 2 + 1;
        final starPaint = Paint()..color = Colors.white.withOpacity(opacity);
        canvas.drawCircle(Offset(sx, sy), starSize, starPaint);
      }
    }

    for (var p in particles) {
      final color = isDark
          ? const Color(0xFF00FFC2).withOpacity(p.opacity)
          : const Color(0xFFFFD700).withOpacity(p.opacity);

      paint.color = color;
      glowPaint.color = color.withOpacity(p.opacity * 0.45);

      final dx = p.x * size.width;
      final dy = p.y * size.height;

      canvas.drawCircle(Offset(dx, dy), p.size * 1.8, glowPaint);
      canvas.drawCircle(Offset(dx, dy), p.size, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _FarHillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.50);
    path.quadraticBezierTo(
      size.width * 0.3, size.height * 0.42,
      size.width * 0.65, size.height * 0.52,
    );
    path.quadraticBezierTo(
      size.width * 0.85, size.height * 0.55,
      size.width, size.height * 0.48,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _MidHillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.56);
    path.quadraticBezierTo(
      size.width * 0.25, size.height * 0.50,
      size.width * 0.55, size.height * 0.58,
    );
    path.quadraticBezierTo(
      size.width * 0.8, size.height * 0.62,
      size.width, size.height * 0.54,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _NearHillClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.moveTo(0, size.height * 0.62);
    path.quadraticBezierTo(
      size.width * 0.35, size.height * 0.58,
      size.width * 0.7, size.height * 0.64,
    );
    path.quadraticBezierTo(
      size.width * 0.88, size.height * 0.66,
      size.width, size.height * 0.60,
    );
    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();
    return path;
  }
  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _GlowingSun extends StatefulWidget {
  const _GlowingSun();

  @override
  State<_GlowingSun> createState() => _GlowingSunState();
}

class _GlowingSunState extends State<_GlowingSun> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        RotationTransition(
          turns: _controller,
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: SweepGradient(
                colors: [
                  Colors.amber.shade300.withOpacity(0.08),
                  Colors.orange.shade400.withOpacity(0.55),
                  Colors.amber.shade300.withOpacity(0.08),
                ],
              ),
            ),
          ),
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Colors.white, Color(0xFFFBBF24), Color(0xFFF59E0B)],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.orange.withOpacity(0.55),
                blurRadius: 15,
                spreadRadius: 2,
              )
            ]
          ),
        ),
      ],
    );
  }
}

class _GlowLamp extends StatefulWidget {
  final bool isDark;
  const _GlowLamp({required this.isDark});

  @override
  State<_GlowLamp> createState() => _GlowLampState();
}

class _GlowLampState extends State<_GlowLamp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final glowVal = _controller.value;
        final glowColor = widget.isDark ? const Color(0xFF00FFFF) : const Color(0xFFFFD700);
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bracket
            Container(
              width: 14,
              height: 3,
              color: Colors.brown.shade800,
            ),
            // Hanging rope
            Container(
              width: 2,
              height: 10,
              color: Colors.brown.shade800,
            ),
            // Lamp Body
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: glowColor,
                boxShadow: [
                  BoxShadow(
                    color: glowColor.withOpacity(0.5 + glowVal * 0.4),
                    blurRadius: 8 + glowVal * 8,
                    spreadRadius: 1 + glowVal * 3,
                  )
                ],
                border: Border.all(color: Colors.brown.shade800, width: 1.5),
              ),
              child: Center(
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _HeartSmokeAnimation extends StatefulWidget {
  const _HeartSmokeAnimation();

  @override
  State<_HeartSmokeAnimation> createState() => _HeartSmokeAnimationState();
}

class _HeartSmokeAnimationState extends State<_HeartSmokeAnimation> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final progress = _controller.value;
        return Stack(
          clipBehavior: Clip.none,
          children: List.generate(4, (index) {
            final double individualProgress = (progress + (index * 0.25)) % 1.0;
            final double y = -individualProgress * 70;
            final double x = math.sin(individualProgress * math.pi * 3) * 12 + (index % 2 == 0 ? 4 : -4);
            final double opacity = (1.0 - individualProgress).clamp(0.0, 1.0);
            final double scale = 0.5 + (individualProgress * 0.5);

            return Positioned(
              top: y,
              left: x + 15,
              child: Opacity(
                opacity: opacity,
                child: Transform.scale(
                  scale: scale,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFFFF4D80),
                    size: 14,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RoofPainter extends CustomPainter {
  final bool isDark;
  _RoofPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final paint = Paint()
      ..shader = LinearGradient(
        colors: isDark
            ? [const Color(0xFF00FFC2), const Color(0xFF0070F3)]
            : [const Color(0xFFFF007F), const Color(0xFF7928CA)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(rect)
      ..style = PaintingStyle.fill;

    final path = Path()
      ..moveTo(size.width * 0.15, 0)
      ..lineTo(size.width * 0.85, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path, paint);

    final tilePaint = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;

    final tileGlowPaint = Paint()
      ..color = isDark ? const Color(0xFF00FFC2).withOpacity(0.35) : const Color(0xFFFF007F).withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);

    for (int row = 0; row < 3; row++) {
      final y = size.height * (0.25 + row * 0.3);
      final pathRow = Path();
      
      final startX = size.width * (0.15 - row * 0.05);
      final endX = size.width * (0.85 + row * 0.05);
      final width = endX - startX;
      final tileCount = 5 + row;
      final tileWidth = width / tileCount;

      pathRow.moveTo(startX, y);
      for (int i = 0; i < tileCount; i++) {
        final x1 = startX + i * tileWidth;
        final x2 = x1 + tileWidth;
        pathRow.quadraticBezierTo(
          (x1 + x2) / 2, y + 8,
          x2, y,
        );
      }
      
      canvas.drawPath(pathRow, tileGlowPaint);
      canvas.drawPath(pathRow, tilePaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _HouseWallPainter extends CustomPainter {
  final bool isDark;
  _HouseWallPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndCorners(
      rect,
      bottomLeft: const Radius.circular(16),
      bottomRight: const Radius.circular(16),
    );

    final bgPaint = Paint()
      ..shader = LinearGradient(
        colors: isDark
            ? [const Color(0xFF1E1B4B), const Color(0xFF311042)]
            : [const Color(0xFFFFF7ED), const Color(0xFFFFEDD5)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(rect)
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, bgPaint);

    final linePaint = Paint()
      ..color = isDark ? Colors.purpleAccent.withOpacity(0.18) : Colors.brown.shade200.withOpacity(0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    final plankCount = 7;
    final plankHeight = size.height / plankCount;
    for (int i = 1; i < plankCount; i++) {
      final y = i * plankHeight;
      canvas.drawLine(Offset(4, y), Offset(size.width - 4, y), linePaint);
    }

    final borderPaint = Paint()
      ..color = isDark ? const Color(0xFFD946EF) : const Color(0xFFFFB03A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0;
    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ManorButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final List<Color> gradientColors;
  final Color shadowColor;
  final VoidCallback onPressed;
  final String? badge;

  const _ManorButton({
    required this.icon,
    required this.label,
    required this.gradientColors,
    required this.shadowColor,
    required this.onPressed,
    this.badge,
  });

  @override
  State<_ManorButton> createState() => _ManorButtonState();
}

class _ManorButtonState extends State<_ManorButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.88),
          onTapUp: (_) {
            setState(() => _scale = 1.0);
            widget.onPressed();
          },
          onTapCancel: () => setState(() => _scale = 1.0),
          child: Transform.scale(
            scale: _scale,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: widget.gradientColors,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: widget.shadowColor.withOpacity(0.55),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: Icon(widget.icon, color: Colors.white, size: 24),
                ),
                if (widget.badge != null)
                  Positioned(
                    top: -4,
                    right: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Text(
                        widget.badge!,
                        style: const TextStyle(
                          fontSize: 8,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  )
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          widget.label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 1),
                blurRadius: 2,
              )
            ]
          ),
        )
      ],
    );
  }
}

class _FeedStockBagButton extends StatefulWidget {
  final KanbanService service;
  final bool isDark;
  final VoidCallback onTap;

  const _FeedStockBagButton({
    required this.service,
    required this.isDark,
    required this.onTap,
  });

  @override
  State<_FeedStockBagButton> createState() => _FeedStockBagButtonState();
}

class _FeedStockBagButtonState extends State<_FeedStockBagButton> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    final isEating = widget.service.currentState == KanbanState.eating;
    final isHungry = widget.service.feedStock < 100 && !isEating;
    final bagColor = isEating 
        ? [Colors.grey.shade400, Colors.grey.shade500] 
        : (isHungry 
            ? [const Color(0xFFEF4444), const Color(0xFFDC2626)] 
            : [const Color(0xFFFBBF24), const Color(0xFFD97706)]);
    final shadowColor = isEating ? Colors.black26 : (isHungry ? Colors.redAccent : Colors.orangeAccent);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTapDown: (_) => setState(() => _scale = 0.88),
          onTapUp: (_) {
            setState(() => _scale = 1.0);
            widget.onTap();
          },
          onTapCancel: () => setState(() => _scale = 1.0),
          child: Transform.scale(
            scale: _scale,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: bagColor,
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: shadowColor.withOpacity(0.55),
                        blurRadius: 12,
                        spreadRadius: isHungry ? 2 : 0,
                        offset: const Offset(0, 4),
                      )
                    ]
                  ),
                  child: const Icon(
                    Icons.shopping_bag_rounded,
                    color: Colors.white,
                    size: 32,
                  ),
                ),
                Positioned(
                  bottom: -5,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF78350F),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 1),
                    ),
                    child: Text(
                      '${widget.service.feedStock}g',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          '喂食 (100g)',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black54,
                offset: Offset(0, 1),
                blurRadius: 2,
              )
            ]
          ),
        )
      ],
    );
  }
}

class _EffectParticle {
  Offset position;
  Offset velocity;
  Color color;
  double size;
  double opacity;
  IconData? icon;

  _EffectParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.opacity,
    this.icon,
  });
}

class _ConfettiPainter extends CustomPainter {
  final List<_EffectParticle> particles;

  _ConfettiPainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var p in particles) {
      final paint = Paint()
        ..color = p.color.withOpacity(p.opacity)
        ..style = PaintingStyle.fill;

      if (p.icon != null) {
        final textPainter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
            text: String.fromCharCode(p.icon!.codePoint),
            style: TextStyle(
              fontSize: p.size * 2,
              fontFamily: p.icon!.fontFamily,
              package: p.icon!.fontPackage,
              color: p.color.withOpacity(p.opacity),
            ),
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, p.position - Offset(textPainter.width / 2, textPainter.height / 2));
      } else {
        canvas.drawCircle(p.position, p.size, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _BubbleTrianglePainter extends CustomPainter {
  final Color color;
  _BubbleTrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width / 2, size.height)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
