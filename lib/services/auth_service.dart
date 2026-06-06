import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../views/turnstile_verifier_dialog.dart';
import 'url_handler_service.dart';
import '../views/home_screen.dart';
import '../views/login_screen.dart';

class AuthService extends ChangeNotifier {
  AuthService._privateConstructor() {
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

    final navContext = UrlHandlerService.navigatorKey.currentContext;
    if (navContext != null) {
      final targetScreen = loggedIn ? HomeScreen() : const LoginScreen();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(navContext).pushAndRemoveUntil(
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
      });
    }
  }

  // Reactivity state
  bool get isLoggedIn => _currentSession != null || _client.auth.currentSession != null;
  Session? get currentSession => _currentSession ?? _client.auth.currentSession;
  User? get currentUser => currentSession?.user;
  String get userEmail => currentUser?.email ?? '';
  String get userId => currentUser?.id ?? '';

  /// 1. 账号密码登录（原生 UI + Turnstile 弹窗）
  Future<void> signInWithPassword(BuildContext context, String email, String password) async {
    // 拉起人机验证获取 Token
    final captchaToken = await TurnstileVerifierDialog.show(context);
    if (captchaToken == null) {
      throw '验证被取消';
    }

    await _client.auth.signInWithPassword(
      email: email,
      password: password,
      captchaToken: captchaToken,
    );
  }

  /// 2. 账号密码注册（原生 UI + Turnstile 弹窗）
  Future<void> signUp(BuildContext context, String email, String password) async {
    final captchaToken = await TurnstileVerifierDialog.show(context);
    if (captchaToken == null) {
      throw '验证被取消';
    }

    await _client.auth.signUp(
      email: email,
      password: password,
      captchaToken: captchaToken,
      emailRedirectTo: 'moely://auth-callback',
    );
  }

  /// 3. 邮箱免密发送 Magic Link（原生 UI + Turnstile 弹窗）
  Future<void> sendMagicLink(BuildContext context, String email) async {
    final captchaToken = await TurnstileVerifierDialog.show(context);
    if (captchaToken == null) {
      throw '验证被取消';
    }

    await _client.auth.signInWithOtp(
      email: email,
      captchaToken: captchaToken,
      emailRedirectTo: 'moely://auth-callback',
    );
  }

  /// 4. 纯原生 Google 登录（无需 Turnstile 验证）
  Future<void> signInWithGoogle() async {
    try {
      final GoogleSignIn googleSignIn = GoogleSignIn();
      final googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        throw '用户取消了 Google 登录';
      }
      
      final googleAuth = await googleUser.authentication;
      final accessToken = googleAuth.accessToken;
      final idToken = googleAuth.idToken;

      if (idToken == null) {
        throw '无法获取 Google ID Token';
      }

      await _client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
    } catch (e) {
      debugPrint("Native Google Sign In Failed: $e");
      rethrow;
    }
  }

  /// 5. 网页端辅助社交登录（GitHub / Microsoft 等，采用系统安全浏览器）
  Future<void> signInWithWebOAuth(OAuthProvider provider) async {
    await _client.auth.signInWithOAuth(
      provider,
      redirectTo: 'moely://auth-callback',
    );
  }

  /// 6. 登出
  Future<void> signOut() async {
    await _client.auth.signOut();
    notifyListeners();
  }
}
