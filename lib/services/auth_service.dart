// lib/services/auth_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart' as gsi;
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class AuthService {
  static final AuthService _instance = AuthService._();
  factory AuthService() => _instance;
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  GoogleSignIn? _googleSignIn;

  // ─── Getters ──────────────────────────────────────────────
  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  bool get isAnonymous => currentUser?.isAnonymous ?? true;
  String? get userId => currentUser?.uid;
  String? get displayName => currentUser?.displayName;
  String? get email => currentUser?.email;
  String? get photoUrl => currentUser?.photoURL;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ─── Phát hiện platform ───────────────────────────────────
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  // ─── Anonymous ────────────────────────────────────────────
  Future<User?> signInAnonymously() async {
    try {
      if (isSignedIn) return currentUser;
      final result = await _auth.signInAnonymously();
      debugPrint('✅ Auth: anonymous → ${result.user?.uid}');
      return result.user;
    } catch (e) {
      debugPrint('❌ Auth: anonymous error: $e');
      return null;
    }
  }

  // ─── Google Sign In (cross-platform) ─────────────────────
  Future<User?> signInWithGoogle() async {
    if (_isDesktop) {
      return _signInWithGoogleDesktop();
    }
    return _signInWithGoogleMobile();
  }

  // ─── Mobile: dùng google_sign_in package ─────────────────
  Future<User?> _signInWithGoogleMobile() async {
    try {
      _googleSignIn ??= GoogleSignIn(scopes: ['email', 'profile']);

      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Auth: user cancelled');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return _signInToFirebase(credential);
    } catch (e) {
      debugPrint('❌ Auth: mobile Google error: $e');
      return null;
    }
  }

  // ─── Desktop: OAuth2 qua localhost + browser ─────────────
  //
  // Flow:
  //   1. App mở localhost server tạm thời
  //   2. Mở browser → Google OAuth consent screen
  //   3. User đăng nhập, Google redirect về localhost
  //   4. App nhận authorization code
  //   5. Đổi code lấy token → đăng nhập Firebase
  //
  // Cần tạo OAuth 2.0 Client ID loại "Desktop app" trong Google Cloud Console
  // Xem SETUP_GUIDE bên dưới để biết cách lấy clientId và clientSecret

  // ★ ĐIỀN thông tin từ Google Cloud Console vào đây:
  //   Console → APIs & Services → Credentials → Create Credentials
  //   → OAuth client ID → Application type: Desktop app
  static const String _desktopClientId =
      '59345...your_actual_id.apps.googleusercontent.com'; // Cần điền ID thật
  static const String _desktopClientSecret =
      'GOCSPX-...actual_secret'; // Cần điền Secret thật

  Future<User?> _signInWithGoogleDesktop() async {
    if (_desktopClientId.startsWith('YOUR_')) {
      debugPrint('❌ Auth: Chưa cấu hình Desktop OAuth Client ID');
      throw AuthException(
        'Chưa cấu hình Google Sign In cho Desktop.\n'
        'Xem hướng dẫn trong auth_service.dart',
      );
    }

    HttpServer? server;
    try {
      // 1. Mở localhost server trên port ngẫu nhiên
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      debugPrint('🔥 Auth Desktop: localhost server on port $port');

      // 2. Tạo Google OAuth URL
      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': _desktopClientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      // 3. Mở browser
      debugPrint('🔥 Auth Desktop: opening browser...');
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw AuthException('Không thể mở trình duyệt');
      }

      // 4. Chờ Google redirect về localhost
      debugPrint('🔥 Auth Desktop: waiting for redirect...');
      final code = await _waitForCode(server).timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw AuthException('Hết giờ đăng nhập (3 phút)'),
      );

      if (code == null) {
        throw AuthException('Không nhận được authorization code');
      }

      debugPrint('🔥 Auth Desktop: got code, exchanging for token...');

      // 5. Đổi authorization code lấy token
      final tokenResponse = await http.post(
        Uri.https('oauth2.googleapis.com', '/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': _desktopClientId,
          'client_secret': _desktopClientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      if (tokenResponse.statusCode != 200) {
        throw AuthException(
            'Token exchange thất bại: ${tokenResponse.statusCode}');
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final idToken = tokenData['id_token'] as String?;
      final accessToken = tokenData['access_token'] as String?;

      if (idToken == null) {
        throw AuthException('Không nhận được ID token từ Google');
      }

      // 6. Đăng nhập Firebase với token
      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      return _signInToFirebase(credential);
    } on AuthException {
      rethrow;
    } catch (e) {
      debugPrint('❌ Auth Desktop: error: $e');
      throw AuthException('Lỗi đăng nhập: $e');
    } finally {
      await server?.close(force: true);
    }
  }

  /// Lắng nghe 1 request từ browser (Google redirect về localhost)
  Future<String?> _waitForCode(HttpServer server) async {
    await for (final request in server) {
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];

      // Gửi trang HTML đóng browser tự động
      final html = '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <title>VipSound - Đăng nhập</title>
  <style>
    body { font-family: sans-serif; display: flex; justify-content: center;
           align-items: center; height: 100vh; margin: 0;
           background: #0F0F23; color: white; flex-direction: column; gap: 16px; }
    .icon { font-size: 48px; }
    h2 { margin: 0; }
    p { margin: 0; color: #aaa; }
  </style>
</head>
<body>
  ${error != null ? '''
    <div class="icon">❌</div>
    <h2>Đăng nhập thất bại</h2>
    <p>$error</p>
  ''' : '''
    <div class="icon">✅</div>
    <h2>Đăng nhập thành công!</h2>
    <p>Bạn có thể đóng tab này và quay lại VipSound.</p>
    <script>setTimeout(() => window.close(), 2000);</script>
  '''}
</body>
</html>''';

      request.response
        ..statusCode = 200
        ..headers.set('Content-Type', 'text/html; charset=utf-8')
        ..write(html);
      await request.response.close();

      if (error != null) {
        debugPrint('⚠️ Auth Desktop: OAuth error: $error');
        return null;
      }

      return code;
    }
    return null;
  }

  // ─── Firebase sign in (shared) ────────────────────────────
  Future<User?> _signInToFirebase(OAuthCredential credential) async {
    // Nếu đang anonymous → link account để giữ data
    if (_auth.currentUser?.isAnonymous == true) {
      try {
        final result = await _auth.currentUser!.linkWithCredential(credential);
        final user = result.user;
        debugPrint('✅ Auth: anonymous linked → ${user?.email}');
        return result.user;
      } on FirebaseAuthException catch (e) {
        if (e.code == 'credential-already-in-use') {
          // Google account đã tồn tại → sign in thẳng
          final result = await _auth.signInWithCredential(credential);
          final user = result.user;
          debugPrint('✅ Auth: existing account → ${user?.email}');
          return result.user;
        }
        rethrow;
      }
    }

    final result = await _auth.signInWithCredential(credential);
    final user = result.user;
    debugPrint('✅ Auth: signed in → ${user?.email}');
    return result.user;
  }

  // ─── Sign Out ─────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      if (!_isDesktop) {
        await _googleSignIn?.signOut();
      }
    } catch (e) {
      debugPrint('❌ Auth: Google sign out error: $e');
    }
    await _auth.signOut();
    debugPrint('✅ Auth: signed out');
  }
}

/// Custom exception để phân biệt lỗi auth với lỗi khác
class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
