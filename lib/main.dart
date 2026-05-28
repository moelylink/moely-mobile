import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'views/home_screen.dart';
import 'services/user_agent_service.dart';
import 'services/settings_service.dart';
import 'services/url_handler_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize dynamic Native User-Agent resolution from platform version definitions
  await UserAgentService.initialize();
  
  // Load AppSettings persistent configurations
  await AppSettings.instance.init();
  
  // Initialize Deep Linking listeners
  UrlHandlerService.initialize();
  
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
          ),
          
          themeMode: AppSettings.instance.themeMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
