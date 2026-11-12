import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'views/lottie_splash_screen.dart';
import 'services/settings_service.dart';
import 'services/url_handler_service.dart';
import 'services/log_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Redirect debugPrint to capture application logs in Debug Mode
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      LogService.log(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };

  // Set preferred orientations
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Load settings before first frame so AnimatedBuilder never triggers a
  // mid-splash rebuild that resets the Lottie animation.
  await AppSettings.instance.init();

  // Instantly mount app so first frame renders immediately and dismisses system splash
  runApp(const MoelyApp());
}

class MoelyApp extends StatelessWidget {
  const MoelyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: AppSettings.instance,
      builder: (context, _) {
        final seedColor = AppSettings.instance.themeColor;
        final currentFont = AppSettings.instance.currentFontFamily;
        
        // Curated Harmonious premium colors matching modern sleek guidelines
        final lightColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.light,
          background: const Color(0xFFF8FAFC), // Slate 50
          surface: const Color(0xFFFFFFFF),
          primary: seedColor,
          onPrimary: const Color(0xFFFFFFFF),
          secondary: seedColor.withBlue(seedColor.blue > 200 ? 100 : 220), 
          primaryContainer: seedColor.withOpacity(0.08),
          onPrimaryContainer: seedColor,
        );

        final darkColorScheme = ColorScheme.fromSeed(
          seedColor: seedColor,
          brightness: Brightness.dark,
          background: const Color(0xFF0B0F19), // Midnight Blue
          surface: const Color(0xFF171E2E), // Slate Dark
          primary: seedColor,
          onPrimary: const Color(0xFF0F172A),
          secondary: seedColor.withBlue(seedColor.blue > 200 ? 100 : 220),
          primaryContainer: seedColor.withOpacity(0.12),
          onPrimaryContainer: seedColor.withOpacity(0.9),
        );

        return MaterialApp(
          navigatorKey: UrlHandlerService.navigatorKey,
          title: '萌哩 - 二次元美图',
          debugShowCheckedModeBanner: false,
          
          // Light Mode Theme config
          theme: ThemeData(
            useMaterial3: true,
            fontFamily: currentFont,
            colorScheme: lightColorScheme,
            scaffoldBackgroundColor: lightColorScheme.background,
            cardTheme: CardThemeData(
              color: lightColorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 2,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(color: lightColorScheme.onBackground),
              titleTextStyle: TextStyle(
                color: lightColorScheme.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: currentFont,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: lightColorScheme.surface,
              contentTextStyle: TextStyle(
                color: lightColorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: currentFont,
              ),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: lightColorScheme.onSurface.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
          ),

          // Dark Mode Theme config
          darkTheme: ThemeData(
            useMaterial3: true,
            fontFamily: currentFont,
            colorScheme: darkColorScheme,
            scaffoldBackgroundColor: darkColorScheme.background,
            cardTheme: CardThemeData(
              color: darkColorScheme.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 4,
            ),
            appBarTheme: AppBarTheme(
              backgroundColor: Colors.transparent,
              surfaceTintColor: Colors.transparent,
              iconTheme: IconThemeData(color: darkColorScheme.onBackground),
              titleTextStyle: TextStyle(
                color: darkColorScheme.onBackground,
                fontSize: 20,
                fontWeight: FontWeight.bold,
                fontFamily: currentFont,
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: darkColorScheme.surface,
              contentTextStyle: TextStyle(
                color: darkColorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
                fontFamily: currentFont,
              ),
              elevation: 6,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: darkColorScheme.onSurface.withOpacity(0.08),
                  width: 1,
                ),
              ),
            ),
          ),
          
          themeMode: AppSettings.instance.themeMode,
          home: const LottieSplashScreen(),
        );
      },
    );
  }
}
