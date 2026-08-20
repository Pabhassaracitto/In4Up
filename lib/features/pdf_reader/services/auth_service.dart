import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
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

  // ─── Flavor & Platform detection ──────────────────────────
  bool get _isDesktop =>
      !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

  String get _flavor {
    const flavor = String.fromEnvironment('FLAVOR', defaultValue: 'stable');
    return flavor;
  }

  // ─── OAuth Client IDs (vipsound-df903 project) ─────────────
  static const String _defaultWebClientId =
      '342774597309-tnje3k849jc42tmkukl8knl5jcvg13tc.apps.googleusercontent.com';
  static const String _envWebClientId =
      '342774597309-7nqkge1vl8mljh6dcd5g3t1qbfi4g618.apps.googleusercontent.com';

  static const String _desktopClientId =
      '342774597309-tjmq927kqhh510vjfsqv9vcmcu947rpn.apps.googleusercontent.com';
  // IMPORTANT: Do not hardcode real secret! Use --dart-define.
  static const String _desktopClientSecretPlaceholder = '';

  String get _webClientId {
    const fromEnv = String.fromEnvironment('GOOGLE_WEB_CLIENT_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    final envVar = Platform.environment['GOOGLE_WEB_CLIENT_ID'];
    if (envVar != null && envVar.isNotEmpty) return envVar;
    return _envWebClientId;
  }

  String get _desktopClientIdEnv {
    const fromEnv = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_ID');
    if (fromEnv.isNotEmpty) return fromEnv;
    final envVar = Platform.environment['GOOGLE_DESKTOP_CLIENT_ID'];
    if (envVar != null && envVar.isNotEmpty) return envVar;
    return _desktopClientId;
  }

  String get _desktopClientSecretEnv {
    const fromEnv = String.fromEnvironment('GOOGLE_DESKTOP_CLIENT_SECRET');
    if (fromEnv.isNotEmpty) return fromEnv;
    final envVar = Platform.environment['GOOGLE_DESKTOP_CLIENT_SECRET'];
    if (envVar != null && envVar.isNotEmpty) return envVar;
    return _desktopClientSecretPlaceholder;
  }

  // ─── Anonymous ────────────────────────────────────────────
  Future<User?> signInAnonymously() async {
    try {
      if (isSignedIn) return currentUser;
      final result = await _auth.signInAnonymously();
      debugPrint('✅ Auth: anonymous → ${result.user?.uid}');
      return result.user;
    } catch (e, st) {
      debugPrint('❌ Auth: anonymous error: $e\n$st');
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
      final serverId = _webClientId;
      debugPrint('🔥 Auth Mobile: flavor=$_flavor, serverClientId=$serverId');

      _googleSignIn ??= GoogleSignIn(
        scopes: ['email', 'profile', 'openid'],
        serverClientId: serverId,
      );

      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      if (googleUser == null) {
        debugPrint('⚠️ Auth: user cancelled Google sign-in');
        return null;
      }

      debugPrint('🔥 Auth Mobile: googleUser=${googleUser.email}');

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      debugPrint(
          '🔥 Auth Mobile: idToken present=${googleAuth.idToken != null}, accessToken present=${googleAuth.accessToken != null}');

      if (googleAuth.idToken == null) {
        debugPrint('❌ Auth Mobile: idToken is null! Check SHA1/SHA256 in Firebase Console and serverClientId');
        throw AuthException(
          'Không lấy được ID token từ Google. '
          'Kiểm tra:\n'
          '1. SHA-1/SHA-256 đã thêm vào Firebase Console chưa? (Project Settings > Your apps)\n'
          '2. Google Sign-In provider đã bật trong Firebase Console > Authentication > Sign-in method chưa?\n'
          '3. serverClientId=$_webClientId có đúng Web client không?',
        );
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      return _signInToFirebase(credential);
    } on FirebaseAuthException catch (e, st) {
      debugPrint('❌ Auth Mobile: FirebaseAuthException ${e.code} ${e.message}\n$st');
      if (e.code == 'account-exists-with-different-credential') {
        throw AuthException(
          'Email này đã được đăng ký bằng phương thức khác. '
          'Hãy đăng nhập bằng phương thức cũ trước, rồi liên kết Google.',
        );
      }
      if (e.code == 'invalid-credential' || e.code == 'ERROR_INVALID_CREDENTIAL') {
        throw AuthException(
          'Credential không hợp lệ. Có thể do SHA-1 chưa khớp hoặc OAuth client sai.\n'
          'Chi tiết: ${e.message}',
        );
      }
      throw AuthException('Lỗi Firebase Auth (${e.code}): ${e.message}');
    } catch (e, st) {
      debugPrint('❌ Auth: mobile Google error: $e\n$st');
      if (e is AuthException) rethrow;
      throw AuthException('Lỗi đăng nhập Google: $e');
    }
  }

  // ─── Desktop: OAuth2 qua localhost + browser ─────────────
  Future<User?> _signInWithGoogleDesktop() async {
    final clientId = _desktopClientIdEnv;
    final clientSecret = _desktopClientSecretEnv;

    if (clientId.isEmpty || clientId.startsWith('YOUR_')) {
      debugPrint('❌ Auth: Chưa cấu hình Desktop OAuth Client ID');
      throw AuthException(
        'Chưa cấu hình Google Sign In cho Desktop.\n'
        'Tạo OAuth client ID loại Desktop app trong Google Cloud Console > APIs & Services > Credentials.\n'
        'Truyền qua --dart-define=GOOGLE_DESKTOP_CLIENT_ID=xxx --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=yyy '
        'hoặc đặt env var GOOGLE_DESKTOP_CLIENT_ID/SECRET.',
      );
    }

    if (clientSecret.isEmpty) {
      debugPrint('❌ Auth: Chưa cấu hình Desktop OAuth Client Secret');
      throw AuthException(
        'Chưa cấu hình GOOGLE_DESKTOP_CLIENT_SECRET.\n'
        'Lấy secret từ Google Cloud Console và truyền qua --dart-define hoặc env.\n'
        'Ví dụ: flutter run -d windows --dart-define=GOOGLE_DESKTOP_CLIENT_SECRET=GOCSPX-...',
      );
    }

    debugPrint('🔥 Auth Desktop: clientId=$clientId, flavor=$_flavor');

    HttpServer? server;
    try {
      server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final port = server.port;
      final redirectUri = 'http://localhost:$port';

      debugPrint('🔥 Auth Desktop: localhost server on port $port');

      final authUrl = Uri.https('accounts.google.com', '/o/oauth2/v2/auth', {
        'client_id': clientId,
        'redirect_uri': redirectUri,
        'response_type': 'code',
        'scope': 'openid email profile',
        'access_type': 'offline',
        'prompt': 'select_account',
      });

      debugPrint('🔥 Auth Desktop: opening browser $authUrl');
      if (!await launchUrl(authUrl, mode: LaunchMode.externalApplication)) {
        throw AuthException('Không thể mở trình duyệt. Hãy thử copy URL: $authUrl');
      }

      debugPrint('🔥 Auth Desktop: waiting for redirect (3 min timeout)...');
      final code = await _waitForCode(server).timeout(
        const Duration(minutes: 3),
        onTimeout: () => throw AuthException('Hết giờ đăng nhập (3 phút) - bạn chưa hoàn tất trong browser'),
      );

      if (code == null) {
        throw AuthException('Không nhận được authorization code từ Google. Bạn có bấm Deny không?');
      }

      debugPrint('🔥 Auth Desktop: got code, exchanging for token...');

      final tokenResponse = await http.post(
        Uri.https('oauth2.googleapis.com', '/token'),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {
          'client_id': clientId,
          'client_secret': clientSecret,
          'code': code,
          'grant_type': 'authorization_code',
          'redirect_uri': redirectUri,
        },
      );

      debugPrint('🔥 Auth Desktop: token response ${tokenResponse.statusCode} ${tokenResponse.body}');

      if (tokenResponse.statusCode != 200) {
        throw AuthException(
            'Token exchange thất bại (${tokenResponse.statusCode}): ${tokenResponse.body}\n'
            'Kiểm tra clientSecret và redirectUri.');
      }

      final tokenData = jsonDecode(tokenResponse.body) as Map<String, dynamic>;
      final idToken = tokenData['id_token'] as String?;
      final accessToken = tokenData['access_token'] as String?;

      if (idToken == null) {
        throw AuthException('Không nhận được ID token từ Google. Response: ${tokenResponse.body}');
      }

      final credential = GoogleAuthProvider.credential(
        idToken: idToken,
        accessToken: accessToken,
      );

      return _signInToFirebase(credential);
    } on AuthException {
      rethrow;
    } catch (e, st) {
      debugPrint('❌ Auth Desktop: error: $e\n$st');
      throw AuthException('Lỗi đăng nhập Desktop: $e');
    } finally {
      await server?.close(force: true);
    }
  }

  Future<String?> _waitForCode(HttpServer server) async {
    await for (final request in server) {
      final code = request.uri.queryParameters['code'];
      final error = request.uri.queryParameters['error'];

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
    p { margin: 0; color: #aaa; text-align: center; padding: 0 20px; }
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
    try {
      if (_auth.currentUser?.isAnonymous == true) {
        try {
          final result =
              await _auth.currentUser!.linkWithCredential(credential);
          final user = result.user;
          debugPrint('✅ Auth: anonymous linked → ${user?.email} ${user?.uid}');
          return result.user;
        } on FirebaseAuthException catch (e) {
          debugPrint('⚠️ Auth: link failed ${e.code}, try signIn: ${e.message}');
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            final result = await _auth.signInWithCredential(credential);
            final user = result.user;
            debugPrint('✅ Auth: existing account → ${user?.email} ${user?.uid}');
            return result.user;
          }
          rethrow;
        }
      }

      final result = await _auth.signInWithCredential(credential);
      final user = result.user;
      debugPrint('✅ Auth: signed in → ${user?.email} ${user?.uid} flavor=$_flavor');
      return result.user;
    } on FirebaseAuthException catch (e, st) {
      debugPrint('❌ Auth _signInToFirebase FirebaseException ${e.code}: ${e.message}\n$st');
      if (e.code == 'unknown' || e.code == 'unknown-error') {
        throw AuthException(
          'Firebase Auth lỗi không xác định (unknown-error).\n'
          'Nguyên nhân thường gặp:\n'
          '1. FirebaseOptions sai project (gen-lang vs vipsound-df903) - ĐÃ FIX bằng firebase_options.dart mới\n'
          '2. google-services.json thiếu SHA-1/SHA-256 cho flavor $_flavor\n'
          '   → Vào Firebase Console > Project Settings > Your apps > SHA certificate fingerprints > thêm SHA-1 và SHA-256 từ keystore\n'
          '   Debug keystore SHA-1 hiện tại thường là: lấy bằng `gradlew signingReport`\n'
          '3. Google provider chưa bật: Firebase Console > Authentication > Sign-in method > Google > Enable\n'
          '4. API key bị hạn chế: Google Cloud Console > APIs & Services > Credentials > API key > Application restrictions\n'
          'Chi tiết gốc: ${e.message}',
        );
      }
      rethrow;
    }
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
    debugPrint('✅ Auth: signed out flavor=$_flavor');
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}
