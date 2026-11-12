import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';
import '../services/app_bootstrap_service.dart';

class LottieSplashScreen extends StatefulWidget {
  const LottieSplashScreen({super.key});

  @override
  State<LottieSplashScreen> createState() => _LottieSplashScreenState();
}

class _LottieSplashScreenState extends State<LottieSplashScreen> with TickerProviderStateMixin {
  late final AnimationController _lottieController;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _lottieController = AnimationController(vsync: this);
    _lottieController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _navigateToHome();
      }
    });
  }

  Future<void> _navigateToHome() async {
    if (_navigated || !mounted) return;
    _navigated = true;

    // Await background bootstrap completion (in most cases already finished during 3s lottie playback)
    try {
      await AppBootstrapService.start().timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[LottieSplash] Bootstrap wait timeout or error: $e');
    }

    if (!mounted) return;

    final isLoggedIn = AuthService.instance.isLoggedIn;
    final targetScreen = isLoggedIn ? HomeScreen() : const LoginScreen();

    AuthService.instance.isReadyForTransitions = true;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => targetScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: animation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _lottieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = AppSettings.instance.themeMode;
    bool isDark = false;
    if (themeMode == ThemeMode.dark) {
      isDark = true;
    } else if (themeMode == ThemeMode.light) {
      isDark = false;
    } else {
      isDark = Theme.of(context).brightness == Brightness.dark;
    }

    // In web theme: dark is #222222, light is #FFFFFF
    final bgColor = isDark ? const Color(0xFF222222) : const Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Centered Lottie Animation
          Center(
            child: SizedBox(
              width: 320,
              height: 320,
              child: Lottie.asset(
                'assets/moely_loader.json',
                controller: _lottieController,
                fit: BoxFit.contain,
                onLoaded: (composition) {
                  _lottieController.duration = composition.duration;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted && !_lottieController.isAnimating) {
                      _lottieController.forward(from: 0.0);
                    }
                  });
                },
              ),
            ),
          ),

          // Glassmorphic Skip Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Material(
                    color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.08),
                    child: InkWell(
                      onTap: _navigateToHome,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.12),
                            width: 1.0,
                          ),
                        ),
                        child: AnimatedBuilder(
                          animation: _lottieController,
                          builder: (context, _) {
                            final progress = _lottieController.value;
                            final textColor = isDark ? Colors.white : Colors.black87;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '跳过',
                                  style: TextStyle(
                                    color: textColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                SizedBox(
                                  width: 14,
                                  height: 14,
                                  child: CircularProgressIndicator(
                                    value: progress,
                                    strokeWidth: 2,
                                    backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      isDark ? Colors.white : const Color(0xFFFF00B4),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
