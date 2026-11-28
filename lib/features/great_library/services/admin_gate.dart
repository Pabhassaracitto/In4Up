// lib/features/great_library/services/admin_gate.dart
//
// GLIB-007 — cổng admin Thư Viện Chung (PLAN-049 §GLIB-007, ADR-0036 D4).
//
// Gate: đăng nhập → uid ∈ `gl_config/admins.uids` → hiện entry "Duyệt pack".
// Fetcher pluggable (Firestore thật / fake test) → logic thuần test được.
//
// Bảo mật thật nằm ở Firestore rules (chỉ admin ghi status/đọc contributions);
// gate này chỉ quyết định UI có hiện entry không (AT3 PLAN-049: tài khoản
// thường bị chặn CẢ UI lẫn rules).

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/firebase_rest_auth.dart';
import '../../../services/firestore_rest_client.dart';

/// Cổng đọc danh sách admin uid (pluggable cho test).
abstract class AdminGateFetcher {
  /// Trả null khi: chưa đăng nhập / lỗi mạng / không có quyền đọc
  /// gl_config/admins (rules `allow read: if glIsAdmin()`).
  Future<Set<String>?> fetchAdminUids();
}

/// Gate thuần — quyết định quyền admin theo uid.
class AdminGate {
  AdminGate({required AdminGateFetcher fetcher, String? currentUid})
      : _fetcher = fetcher,
        _currentUid = currentUid;

  final AdminGateFetcher _fetcher;
  final String? _currentUid;

  /// Cache trong phiên (gate gọi mỗi lần mở Thư Viện Chung).
  bool? _cached;

  /// uid hiện tại có phải admin không. Lỗi fetch → false (an toàn: ẩn entry).
  Future<bool> isAdmin() async {
    final cached = _cached;
    if (cached != null) return cached;
    final uid = _currentUid ?? '';
    if (uid.isEmpty) {
      _cached = false;
      return false;
    }
    final uids = await _fetcher.fetchAdminUids();
    final result = uids != null && uids.contains(uid);
    _cached = result;
    return result;
  }

  /// Xoá cache (đăng xuất/đổi tài khoản).
  void invalidate() => _cached = null;
}

/// Fetcher thật: GET gl_config/admins qua Firestore REST (cần idToken admin).
class FirestoreAdminGateFetcher implements AdminGateFetcher {
  FirestoreAdminGateFetcher({
    http.Client? client,
    String? projectIdOverride,
    Future<String?> Function()? idTokenProvider,
    this.requestTimeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _projectIdOverride = projectIdOverride,
        _idTokenProvider = idTokenProvider;

  final http.Client _client;
  final bool _ownsClient;
  final String? _projectIdOverride;
  final Future<String?> Function()? _idTokenProvider;
  final Duration requestTimeout;

  String get _projectId =>
      _projectIdOverride ?? FirestoreRestClient().projectId;

  @override
  Future<Set<String>?> fetchAdminUids() async {
    String? token;
    try {
      token = await (_idTokenProvider != null
          ? _idTokenProvider!()
          : FirebaseRestAuth().getIdToken());
    } on Object {
      token = null;
    }
    if (token == null || token.isEmpty) return null;

    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/(default)/documents/gl_config/admins',
    );
    final http.Response response;
    try {
      response = await _client
          .get(uri, headers: {'Authorization': 'Bearer $token'})
          .timeout(requestTimeout);
    } on Object {
      return null;
    }
    if (response.statusCode != 200) return null;
    try {
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      final fields =
          FirestoreRestClient().decodeFields(decoded['fields'] as Map<String, dynamic>?);
      final uids = fields['uids'];
      if (uids is! List) return null;
      return uids.whereType<String>().toSet();
    } on Object {
      return null;
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
