import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'url_handler_service.dart';
import '../views/home_screen.dart';
import '../views/login_screen.dart';

class AuthService extends ChangeNotifier {
  AuthService._privateConstructor() {
    _currentSession = _client.auth.currentSession;
    // 监听 Supabase 会话状态变更
    _client.auth.onAuthStateChange.listen((data) {
      _currentSession = data.session;
      debugPrint("Auth State Change: Event = ${data.event}, User = ${currentUser?.email}");
      notifyListeners();
      _handleAuthTransition();
    });
  }

  static final AuthService instance = AuthService._privateConstructor();
  
  final SupabaseClient _client = Supabase.instance.client;
  Session? _currentSession;

  /// 外部显式更新 Session 并分发状态变更
  void updateSession(Session? session) {
    _currentSession = session;
    _isReadyForTransitions = true;
    debugPrint("AuthService updateSession: User = ${currentUser?.email}");
    notifyListeners();
    _handleAuthTransition();
  }

  bool _isReadyForTransitions = false;
  bool? _wasLoggedIn;

  set isReadyForTransitions(bool value) {
    _isReadyForTransitions = value;
    if (value) {
      _wasLoggedIn = isLoggedIn;
    }
  }

  void _handleAuthTransition() {
    if (!_isReadyForTransitions) return;

    final loggedIn = isLoggedIn;
    if (_wasLoggedIn == loggedIn) return;
    _wasLoggedIn = loggedIn;

    final navState = UrlHandlerService.navigatorKey.currentState;
    if (navState != null) {
      final targetScreen = loggedIn ? HomeScreen() : const LoginScreen();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (loggedIn && navState.canPop()) {
          navState.popUntil((route) => route.isFirst);
        } else {
          navState.pushAndRemoveUntil(
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
      });
    }
  }

  // Reactivity state
  bool get isLoggedIn => _currentSession != null || _client.auth.currentSession != null;
  Session? get currentSession => _currentSession ?? _client.auth.currentSession;
  User? get currentUser => currentSession?.user;
  String get userEmail => currentUser?.email ?? '';
  String get userId => currentUser?.id ?? '';

  /// 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
    _currentSession = null;
    notifyListeners();
  }
}
