import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import '../services/kanban_service.dart';
import '../services/widget_service.dart';
import '../utils/toast_helper.dart';

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
    final success = await WidgetService.pinWidget('PetWidgetProvider');
    if (mounted) {
      if (success) {
        ToastHelper.show(context, '已向系统发起添加小组件申请！', type: ToastType.success);
      } else {
        ToastHelper.show(context, '添加小组件失败，可能当前系统不支持或未授权', type: ToastType.error);
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
                left: 20,
                bottom: 20,
                child: Row(
                  children: [
                    _ManorButton(
                      icon: Icons.favorite_rounded,
                      label: '亲密度',
                      gradientColors: const [Color(0xFFF472B6), Color(0xFFE11D48)], // Warm pink
                      shadowColor: Colors.pinkAccent,
                      onPressed: () => _showGoodwillDialog(context, service),
                      badge: 'LV ${(service.goodwill ~/ 100) + 1}',
                    ),
                    const SizedBox(width: 12),
                    _ManorButton(
                      icon: Icons.store_rounded,
                      label: '美食商店',
                      gradientColors: const [Color(0xFFFBBF24), Color(0xFFD97706)], // Warm orange
                      shadowColor: Colors.orangeAccent,
                      onPressed: () => _showFoodShopDialog(context, service),
                    ),
                    const SizedBox(width: 12),
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
    String labelText = '';

    if (isEating && service.eatingEndTime != null) {
      final diff = service.eatingEndTime!.difference(service.nowTime);
      if (!diff.isNegative) {
        final minutes = diff.inMinutes.remainder(60).toString().padLeft(2, '0');
        final seconds = diff.inSeconds.remainder(60).toString().padLeft(2, '0');
        final hours = diff.inHours;
        labelText = hours > 0 ? '$hours:$minutes:$seconds' : '$minutes:$seconds';
      }
    } else if (amount > 0) {
      labelText = '${amount}g';
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 52,
              height: 26,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark 
                      ? [const Color(0xFFD946EF), const Color(0xFF8B5CF6)] 
                      : [const Color(0xFFFBBF24), const Color(0xFFF59E0B)],
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
                border: Border.all(color: Colors.white, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: (isDark ? const Color(0xFFD946EF) : const Color(0xFFFBBF24)).withOpacity(0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  )
                ]
              ),
            ),
            Positioned(
              top: 2,
              child: Container(
                width: 40,
                height: 10,
                decoration: BoxDecoration(
                  color: const Color(0xFF78350F),
                  borderRadius: BorderRadius.circular(5),
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
              color: Colors.black.withOpacity(0.5),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white24, width: 0.8),
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
                  const Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 13),
                  const SizedBox(width: 3),
                  Text(
                    '爱心: ${service.collectedHearts} ❤️ (速度+$speedPercent%)',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.redAccent),
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
        assetPath = 'assets/pet/capoo/$temporaryAction.webp';
      } else if (service.isHungry && state == KanbanState.idle) {
        assetPath = 'assets/pet/capoo/hungry.webp';
      } else {
        switch (state) {
          case KanbanState.idle:
            assetPath = 'assets/pet/capoo/play.webp';
            break;
          case KanbanState.studying:
            assetPath = 'assets/pet/capoo/work.webp';
            break;
          case KanbanState.sleeping:
            assetPath = 'assets/pet/capoo/sleep.webp';
            break;
          case KanbanState.eating:
            assetPath = 'assets/pet/capoo/eating.webp';
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
        title: const Text('如何玩转萌哩小屋？', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text(
          '1. 🥣 **干饭升级**：倒入 100g 饲料需要吃 1 小时。吃完增加经验升级！等级越高，学习与工作速度越快！\n'
          '2. 📝 **学习模式**：每 2 小时消耗 50g 饲料，收获 1 颗星星 ⭐（受等级加速！）。\n'
          '3. 💤 **睡觉模式**：无需消耗饲料，每 6 小时自动产出 1 颗星星 ⭐。\n'
          '4. ⭐ **星星兑换**：收获的星星类似庄园金蛋，可在衣帽间兑换限定专属皮肤装扮！\n'
          '5. ❤️ **亲密互动**：点击萌哩摸摸头增进好感，成长满进度获得神秘爱心。\n'
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

  void _showGoodwillDialog(BuildContext context, KanbanService service) {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final level = (service.goodwill ~/ 100) + 1;
            final progress = (service.goodwill % 100) / 100.0;
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              title: const Row(
                children: [
                  Icon(Icons.favorite_rounded, color: Colors.pinkAccent),
                  SizedBox(width: 8),
                  Text('萌哩亲密度', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '当前等级: LV $level',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 12,
                      backgroundColor: theme.colorScheme.onSurface.withOpacity(0.06),
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${service.goodwill % 100} / 100 Pts (总好感点: ${service.goodwill})',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('今日好感度提升 (摸头):'),
                      Text(
                        '${service.dailyTouches} / 5',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: service.dailyTouches >= 5 ? Colors.green : Colors.pinkAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    service.dailyTouches >= 5
                        ? '今日好感已达上限，明天再来摸摸我吧！'
                        : '每次摸摸头可以提升 10 点好感度噢~',
                    style: const TextStyle(fontSize: 11, color: Colors.blueGrey),
                  ),
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('重置庄园？'),
                          content: const Text('此操作将清空所有好感度、饲料及爱心！确认要重新开始吗？'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('取消'),
                            ),
                            TextButton(
                              onPressed: () async {
                                await service.resetGoodwill();
                                if (ctx.mounted) {
                                  Navigator.pop(ctx);
                                }
                                setDialogState(() {});
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ToastHelper.show(context, '庄园已恢复初始状态！', type: ToastType.info);
                                }
                              },
                              child: const Text('确认重置', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, color: Colors.redAccent, size: 16),
                    label: const Text('重新开始庄园生活', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  )
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
              title: const Row(
                children: [
                  Icon(Icons.store_rounded, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('庄园美食铺', style: TextStyle(fontWeight: FontWeight.bold)),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
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
                              const Icon(Icons.favorite_rounded, color: Colors.pinkAccent, size: 16),
                              const SizedBox(width: 4),
                              Text('亲密度: ${service.goodwill}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          Row(
                            children: [
                              const Icon(Icons.favorite_sharp, color: Colors.red, size: 16),
                              const SizedBox(width: 4),
                              Text('爱心: ${service.collectedHearts}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            ],
                          )
                        ],
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.bakery_dining_rounded, color: Colors.orange.shade400, size: 36),
                      title: const Text('精选杂粮 (100g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('价格: 50 亲密度', style: TextStyle(fontSize: 12)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: service.goodwill >= 50
                            ? () async {
                                final success = await service.buyFeedWithGoodwill(50, 100);
                                if (success) {
                                  setDialogState(() {});
                                  if (context.mounted) {
                                    ToastHelper.show(context, '购买成功，获得 100g 饲料！', type: ToastType.success);
                                  }
                                }
                              }
                            : null,
                        child: const Text('购买'),
                      ),
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.savings_rounded, color: Colors.red.shade400, size: 36),
                      title: const Text('金枪鱼豪华大餐 (250g)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: const Text('价格: 1 颗爱心 ❤️', style: TextStyle(fontSize: 12)),
                      trailing: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 0,
                        ),
                        onPressed: service.collectedHearts >= 1
                            ? () async {
                                final success = await service.buyFeedWithHearts(1, 250);
                                if (success) {
                                  setDialogState(() {});
                                  if (context.mounted) {
                                    ToastHelper.show(context, '购买成功，获得 250g 饲料！', type: ToastType.success);
                                  }
                                }
                              }
                            : null,
                        child: const Text('兑换'),
                      ),
                    ),
                  ],
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
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite_sharp, color: Colors.red, size: 14),
                      const SizedBox(width: 2),
                      Text('${service.collectedHearts}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.red)),
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
                                final success = await service.unlockSkin(id, cost, useStars: true);
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
