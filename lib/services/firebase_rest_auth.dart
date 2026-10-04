// Firebase Auth REST fallback cho nền tảng KHÔNG có FlutterFire plugin (Linux).
//
// Vì sao tồn tại: firebase_core / firebase_auth không phát hành implementation
// native cho Linux → Firebase.initializeApp() văng MissingPluginException →
// app chạy offline hoàn toàn: không đăng nhập, không sync (xem main.dart).
//
// Giải pháp: dùng REST API công khai chính thức của Firebase Identity Platform:
//  - Đăng nhập Google: POST /v1/accounts:signInWithIdp (Google ID token lấy từ
//    OAuth browser flow đã có sẵn trong AuthService._signInWithGoogleDesktop)
//  - Làm mới token:  POST /v1/token (securetoken.googleapis.com)
//  - User nhận được có CÙNG uid với Android/Windows (cùng project) → dữ liệu
//    sync về đúng tài khoản.
//
// Lưu trữ: refresh token + profile trong Hive box 'firebase_rest_auth'
// (nhất quán với offline-first storage của app).

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

import '../firebase_options.dart';

/// Thông tin user thống nhất cho mọi backend auth (plugin hoặc REST).
///
/// UI (nút đăng nhập Home) và các provider sync chỉ nên đọc type này,
/// không phụ thuộc Firebase `User` của plugin.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
  });
}

class FirebaseRestAuthException implements Exception {
  final String message;
  const FirebaseRestAuthException(this.message);

  @override
  String toString() => message;
}

/// Singleton quản lý phiên đăng nhập Firebase qua REST (dùng trên Linux).
///
/// Semantics bám sát `FirebaseAuth.instance`:
///  - `currentUser`: user hiện tại (null nếu chưa đăng nhập)
///  - `authStateChanges`: stream phát trạng thái HIỆN TẠI ngay khi subscribe
///    (mỗi subscriber đều nhận được, giống plugin)
///  - `getIdToken()`: token còn hạn → cache; hết hạn → tự refresh
class FirebaseRestAuth {
  static final FirebaseRestAuth _instance = FirebaseRestAuth._();
  factory FirebaseRestAuth() => _instance;
  FirebaseRestAuth._();

  static const String _boxName = 'firebase_rest_auth';
  static const String _sessionKey = 'session';
  static const Duration _requestTimeout = Duration(seconds: 30);

  final List<StreamController<AppUser?>> _subscribers = [];

  AppUser? _user;
  String? _idToken;
  String? _refreshToken;
  int _expiresAtMs = 0;
  bool _restoring = false;

  // ─── Config (lấy từ firebase_options, không cần plugin native) ──
  String get _apiKey {
    try {
      return DefaultFirebaseOptions.currentPlatform.apiKey;
    } catch (_) {
      // Web API key của project vipsound-df903 (firebase_options.dart)
      return 'AIzaSyD-xDY8nduuCp8-G_S1CPfyoyYdgWvCJCk';
    }
  }

  // ─── State ────────────────────────────────────────────────────
  AppUser? get currentUser => _user;
  bool get isSignedIn => _user != null;

  /// Stream giống FirebaseAuth.authStateChanges: mỗi subscriber nhận trạng
  /// thái hiện tại ngay khi đăng ký, sau đó nhận mọi thay đổi.
  Stream<AppUser?> get authStateChanges {
    late final StreamController<AppUser?> controller;
    controller = StreamController<AppUser?>(
      onListen: () {
        controller.add(_user);
        _subscribers.add(controller);
      },
      onCancel: () {
        _subscribers.remove(controller);
      },
    );
    return controller.stream;
  }

  void _emit(AppUser? user) {
    for (final c in List.of(_subscribers)) {
      if (!c.isClosed) c.add(user);
    }
  }

  // ─── Khôi phục phiên khi mở app ───────────────────────────────
  /// Đọc refresh token từ Hive → phát user (optimistic) → refresh để xác thực.
  /// Nếu token đã bị thu hồi → đăng xuất. Lỗi mạng → giữ phiên optimistic,
  /// lần getIdToken() sau sẽ thử lại.
  Future<void> restoreSession() async {
    if (_restoring) return;
    _restoring = true;
    try {
      final saved = await _loadSaved();
      if (saved == null) return;

      _user = AppUser(
        uid: saved['uid'] as String? ?? '',
        email: saved['email'] as String?,
        displayName: saved['displayName'] as String?,
        photoUrl: saved['photoUrl'] as String?,
      );
      _idToken = saved['idToken'] as String?;
      _refreshToken = saved['refreshToken'] as String?;
      _expiresAtMs = (saved['expiresAtMs'] as num?)?.toInt() ?? 0;

      if (_user!.uid.isEmpty || _refreshToken == null) {
        await _clearLocal();
        return;
      }

      debugPrint('🔁 RestAuth: khôi phục phiên cho ${_user!.email}');
      _emit(_user);

      try {
        await _refresh();
      } catch (e) {
        // Offline / lỗi mạng / lỗi tạm của server: giữ phiên optimistic,
        // lần getIdToken() sau sẽ thử lại (được gọi qua unawaited trong main).
        debugPrint('⚠️ RestAuth: refresh lúc khởi động thất bại (offline?): $e');
      }
    } finally {
      _restoring = false;
    }
  }

  // ─── Đăng nhập bằng Google ID token (đã có từ OAuth desktop flow) ──
  Future<AppUser?> signInWithGoogleIdToken({
    required String googleIdToken,
    required String requestUri,
  }) async {
    final resp = await http
        .post(
          Uri.parse(
              'https://identitytoolkit.googleapis.com/v1/accounts:signInWithIdp?key=$_apiKey'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'postBody': 'id_token=$googleIdToken&providerId=google.com',
            'requestUri': requestUri,
            'returnSecureToken': true,
          }),
        )
        .timeout(_requestTimeout);

    if (resp.statusCode != 200) {
      throw FirebaseRestAuthException(
          'signInWithIdp HTTP ${resp.statusCode}: ${_apiErrorMessage(resp.body)}');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw FirebaseRestAuthException('signInWithIdp: response không hợp lệ: $e');
    }

    final uid = data['localId'] as String?;
    final idToken = data['idToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (uid == null || idToken == null || refreshToken == null) {
      throw FirebaseRestAuthException(
          'signInWithIdp: thiếu localId/idToken/refreshToken trong response');
    }

    _user = AppUser(
      uid: uid,
      email: data['email'] as String?,
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
    _idToken = idToken;
    _refreshToken = refreshToken;
    _expiresAtMs = DateTime.now().millisecondsSinceEpoch +
        ((int.tryParse('${data['expiresIn'] ?? 3600}') ?? 3600) * 1000);

    await _persist();
    _emit(_user);
    debugPrint('✅ RestAuth: signed in → ${_user!.email} ($uid)');
    return _user;
  }

  // ─── ID token cho Firestore REST ──────────────────────────────
  /// Token còn hạn (margin 2 phút) → dùng cache, ngược lại tự refresh.
  /// Trả về null nếu chưa đăng nhập hoặc token đã bị thu hồi (đã sign out).
  Future<String?> getIdToken() async {
    if (_refreshToken == null) return null;
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_idToken != null && _user != null && now < _expiresAtMs - 120000) {
      return _idToken;
    }
    return _refresh();
  }

  Future<String?> _refresh() async {
    final refreshToken = _refreshToken;
    if (refreshToken == null) return null;

    final resp = await http
        .post(
          Uri.parse(
              'https://securetoken.googleapis.com/v1/token?key=$_apiKey'),
          headers: {'Content-Type': 'application/x-www-form-urlencoded'},
          body: {'grant_type': 'refresh_token', 'refresh_token': refreshToken},
        )
        .timeout(_requestTimeout);

    if (resp.statusCode == 400) {
      // Token hết hạn / bị thu hồi / user bị vô hiệu → kết thúc phiên
      debugPrint('⚠️ RestAuth: refresh token không còn hợp lệ → sign out');
      await _clearLocal();
      return null;
    }
    if (resp.statusCode != 200) {
      throw FirebaseRestAuthException(
          'refresh HTTP ${resp.statusCode}: ${_apiErrorMessage(resp.body)}');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(resp.body) as Map<String, dynamic>;
    } catch (e) {
      throw FirebaseRestAuthException('refresh: response không hợp lệ: $e');
    }

    _idToken = (data['id_token'] ?? data['access_token']) as String?;
    _refreshToken = (data['refresh_token'] as String?) ?? refreshToken;
    final expiresIn = int.tryParse('${data['expires_in'] ?? 3600}') ?? 3600;
    _expiresAtMs = DateTime.now().millisecondsSinceEpoch + expiresIn * 1000;

    if (_idToken == null) {
      throw FirebaseRestAuthException('refresh: thiếu id_token trong response');
    }

    await _persist();
    return _idToken;
  }

  // ─── Sign out ─────────────────────────────────────────────────
  Future<void> signOut() async {
    await _clearLocal();
    debugPrint('✅ RestAuth: signed out');
  }

  // ─── Persistence (Hive) ───────────────────────────────────────
  Future<void> _persist() async {
    if (_user == null) return;
    try {
      final box = await _openBox();
      await box.put(_sessionKey, jsonEncode({
            'uid': _user!.uid,
            'email': _user!.email,
            'displayName': _user!.displayName,
            'photoUrl': _user!.photoUrl,
            'idToken': _idToken,
            'refreshToken': _refreshToken,
            'expiresAtMs': _expiresAtMs,
          }));
    } catch (e) {
      debugPrint('⚠️ RestAuth: persist thất bại: $e');
    }
  }

  Future<Map<String, dynamic>?> _loadSaved() async {
    try {
      final box = await _openBox();
      final raw = box.get(_sessionKey);
      if (raw == null) return null;
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('⚠️ RestAuth: đọc session thất bại: $e');
      return null;
    }
  }

  Future<void> _clearLocal() async {
    _user = null;
    _idToken = null;
    _refreshToken = null;
    _expiresAtMs = 0;
    _emit(null);
    try {
      final box = await _openBox();
      await box.delete(_sessionKey);
    } catch (_) {}
  }

  Future<Box<String>> _openBox() async {
    if (!Hive.isBoxOpen(_boxName)) {
      await Hive.openBox<String>(_boxName);
    }
    return Hive.box<String>(_boxName);
  }

  // ─── Helpers ──────────────────────────────────────────────────
  String _apiErrorMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      return error?['message'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }
}
