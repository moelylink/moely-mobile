import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'home_screen.dart';
import 'login_screen.dart';
import '../services/settings_service.dart';
import '../services/auth_service.dart';

class VideoSplashScreen extends StatefulWidget {
  const VideoSplashScreen({super.key});

  @override
  State<VideoSplashScreen> createState() => _VideoSplashScreenState();
}

class _VideoSplashScreenState extends State<VideoSplashScreen> with SingleTickerProviderStateMixin {
  late VideoPlayerController _controller;
  bool _initialized = false;
  bool _hasError = false;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _initializeVideo();
  }

  Future<void> _initializeVideo() async {
    _controller = VideoPlayerController.asset('moely.mp4');
    try {
      await _controller.initialize();
      if (!mounted) return;
      setState(() {
        _initialized = true;
      });
      _fadeController.forward();
      await _controller.play();
      _controller.setLooping(false);

      // Listen for video completion to auto-navigate
      _controller.addListener(_videoListener);
    } catch (e) {
      debugPrint('Error loading splash video: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        _navigateToHome();
      }
    }
  }

  void _videoListener() {
    if (!mounted) return;
    if (_controller.value.position >= _controller.value.duration) {
      _navigateToHome();
    }
    // Update the UI for progress indicator on skip button
    setState(() {});
  }

  void _navigateToHome() {
    // Remove listener first to avoid multiple navigation triggers
    _controller.removeListener(_videoListener);
    
    final isLoggedIn = AuthService.instance.isLoggedIn;
    final targetScreen = isLoggedIn ? HomeScreen() : const LoginScreen();

    // Enable automatic transitions before navigating
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
        transitionDuration: const Duration(milliseconds: 800),
      ),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _controller.removeListener(_videoListener);
    _controller.dispose();
    _fadeController.dispose();
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
    
    final bgColor = isDark ? Colors.black : Colors.white;
    final progressColor = isDark ? Colors.white : Colors.black;

    if (_hasError) {
      return Scaffold(
        backgroundColor: bgColor,
        body: Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(progressColor),
          ),
        ),
      );
    }

    if (!_initialized) {
      return Scaffold(
        backgroundColor: bgColor,
        body: const SizedBox.shrink(),
      );
    }

    final double progress = _controller.value.duration.inMilliseconds > 0
        ? _controller.value.position.inMilliseconds / _controller.value.duration.inMilliseconds
        : 0.0;

    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Video Player Layer with Fade-in Animation
          FadeTransition(
            opacity: _fadeAnimation,
            child: SizedBox.expand(
              child: FittedBox(
                fit: BoxFit.cover,
                child: SizedBox(
                  width: _controller.value.size.width,
                  height: _controller.value.size.height,
                  child: VideoPlayer(_controller),
                ),
              ),
            ),
          ),
          
          // Top Glassmorphic Skip Button Layer
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            right: 16,
            child: SafeArea(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Material(
                    color: Colors.black.withOpacity(0.4),
                    child: InkWell(
                      onTap: _navigateToHome,
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.15),
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '跳过',
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.9),
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
                                backgroundColor: Colors.white.withOpacity(0.2),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          ],
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
