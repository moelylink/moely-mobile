import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'views/home_screen.dart';
import 'views/video_splash_screen.dart';
import 'services/user_agent_service.dart';
import 'services/settings_service.dart';
import 'services/url_handler_service.dart';
import 'services/log_service.dart';
import 'services/auth_service.dart';
import 'utils/notification_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize notifications
  await NotificationHelper.init();
  
  // Initialize Supabase Client
  await Supabase.initialize(
    url: 'https://fefckqwvcvuadiixvhns.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZlZmNrcXd2Y3Z1YWRpaXh2aG5zIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzYzNDE5OTUsImV4cCI6MjA1MTkxNzk5NX0.-OUllwH7v2K-j4uIx7QQaV654R5Gz5_1jP4BGdkWWfg',
    authOptions: const FlutterAuthClientOptions(
      authFlowType: AuthFlowType.pkce,
    ),
  );
  
  // Initialize dynamic Native User-Agent resolution from platform version definitions
  await UserAgentService.initialize();
  
  // Load AppSettings persistent configurations
  await AppSettings.instance.init();

  // Redirect debugPrint to capture application logs in Debug Mode
  final originalDebugPrint = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) {
      LogService.log(message);
    }
    originalDebugPrint(message, wrapWidth: wrapWidth);
  };
  
  // Initialize Deep Linking listeners
  UrlHandlerService.initialize();
  
  // Pre-initialize AuthService to ensure it starts listening to session recovery events immediately
  AuthService.instance;
  
  // Set preferred orientations and custom system UI overlay styling
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
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
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: lightColorScheme.surface,
              contentTextStyle: TextStyle(
                color: lightColorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
              ),
            ),
            snackBarTheme: SnackBarThemeData(
              behavior: SnackBarBehavior.floating,
              backgroundColor: darkColorScheme.surface,
              contentTextStyle: TextStyle(
                color: darkColorScheme.onSurface,
                fontWeight: FontWeight.w600,
                fontSize: 13,
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
          home: const VideoSplashScreen(),
        );
      },
    );
  }
}
