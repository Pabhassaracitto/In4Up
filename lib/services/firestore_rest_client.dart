// Firestore REST client — fallback sync cho Linux (không có plugin
// cloud_firestore native).
//
// Dùng chính Firestore REST API công khai:
//   https://firestore.googleapis.com/v1/projects/{p}/databases/(default)/...
//  - getDocument:       GET  .../documents/{path}
//  - listCollection:    GET  .../documents/{collectionPath}?pageToken=...
//  - runQuery:          POST .../documents:runQuery (structuredQuery)
//  - commitWrites:      POST .../documents:commit (batch ≤500 writes)
//
// Auth: Bearer ID token từ [FirebaseRestAuth] (cùng uid Android/Windows).
// Định dạng dữ liệu tương thích 2 chiều với plugin: int/string/bool/double/
// list/map/timestampValue ↔ Timestamp.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../firebase_options.dart';
import 'firebase_rest_auth.dart';

class FirestoreRestDoc {
  final String id;
  final Map<String, dynamic> data;

  /// Firestore REST có thể trả `readTime` trong mỗi phần tử của
  /// `documents:runQuery` — dùng làm con trỏ phân trang `startAt`.
  final DateTime? readTime;

  const FirestoreRestDoc(this.id, this.data, {this.readTime});
}

class FirestoreRestException implements Exception {
  final int statusCode;
  final String message;
  const FirestoreRestException(this.statusCode, this.message);

  @override
  String toString() => 'FirestoreRest($statusCode): $message';
}

class FirestoreRestClient {
  static final FirestoreRestClient _instance = FirestoreRestClient._();
  factory FirestoreRestClient() => _instance;
  FirestoreRestClient._();

  static const Duration _requestTimeout = Duration(seconds: 30);
  static const int _maxWritesPerCommit = 400; // limit của API là 500

  String get projectId {
    try {
      return DefaultFirebaseOptions.currentPlatform.projectId;
    } catch (_) {
      return 'vipsound-df903';
    }
  }

  String get _documentsBaseUrl =>
      'https://firestore.googleapis.com/v1/projects/$projectId/databases/(default)/documents';

  /// Tên resource tuyệt đối của 1 document (dùng trong commit writes).
  String docName(String relativePath) =>
      'projects/$projectId/databases/(default)/documents/$relativePath';

  // ═════════════════════════════════════════════════════════════
  // Write helpers (dùng kèm commitWrites)
  // ═════════════════════════════════════════════════════════════

  /// Ghi đè toàn bộ document (giống batch.set của plugin, không merge).
  Map<String, dynamic> updateWrite(
          String relativePath, Map<String, dynamic> fields) =>
      {
        'update': {
          'name': docName(relativePath),
          'fields': encodeFields(fields),
        }
      };

  /// Đặt 1 field = server timestamp (thay FieldValue.serverTimestamp()).
  Map<String, dynamic> serverTimeWrite(String relativePath, String fieldPath) =>
      {
        'transform': {
          'document': docName(relativePath),
          'fieldTransforms': [
            {'fieldPath': fieldPath, 'setToServerValue': 'REQUEST_TIME'}
          ],
        }
      };

  Map<String, dynamic> deleteWrite(String relativePath) =>
      {'delete': docName(relativePath)};

  /// Commit một batch writes (tự chia chunk ≤ 400 writes/request).
  Future<void> commitWrites(List<Map<String, dynamic>> writes) async {
    if (writes.isEmpty) return;
    for (int i = 0; i < writes.length; i += _maxWritesPerCommit) {
      final chunk = writes.skip(i).take(_maxWritesPerCommit).toList();
      await _post(
          '$_documentsBaseUrl:commit', {'writes': chunk});
    }
  }

  // ═════════════════════════════════════════════════════════════
  // Reads
  // ═════════════════════════════════════════════════════════════

  /// Lấy 1 document. Trả về null nếu không tồn tại (404).
  Future<Map<String, dynamic>?> getDocument(String relativePath) async {
    final resp = await _get('$_documentsBaseUrl/$relativePath');
    if (resp.statusCode == 404) return null;
    if (resp.statusCode != 200) {
      throw FirestoreRestException(
          resp.statusCode, _errorMessage(resp.body));
    }
    final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
    return decodeFields(decoded['fields'] as Map<String, dynamic>?);
  }

  /// Liệt kê toàn bộ collection (có pagination).
  Future<List<FirestoreRestDoc>> listCollection(String collectionPath,
      {int pageSize = 300}) async {
    final result = <FirestoreRestDoc>[];
    String? pageToken;
    do {
      var url = '$_documentsBaseUrl/$collectionPath?pageSize=$pageSize';
      if (pageToken != null) url += '&pageToken=${Uri.encodeQueryComponent(pageToken)}';
      final resp = await _get(url);
      if (resp.statusCode != 200) {
        throw FirestoreRestException(
            resp.statusCode, _errorMessage(resp.body));
      }
      final decoded = jsonDecode(resp.body) as Map<String, dynamic>;
      final docs = decoded['documents'] as List<dynamic>?;
      if (docs != null) {
        for (final d in docs) {
          final doc = _parseDocument(d as Map<String, dynamic>);
          if (doc != null) result.add(doc);
        }
      }
      pageToken = decoded['nextPageToken'] as String?;
    } while (pageToken != null);
    return result;
  }

  /// Dung lượng mỗi lần gọi `runQuery`. Giới hạn mềm để MỘT trang không quá
  /// nặng; việc lấy ĐỦ dữ liệu nằm ở vòng lặp phân trang (startAt) bên dưới,
  /// KHÔNG phải nhờ con số này — tăng nó chỉ giảm số request, không "vá" mất
  /// dữ liệu.
  static const int _runQueryPageSize = 1000;

  /// Số trang tối đa cho một lần query — chỉ là cầu an toàn chống vòng lặp
  /// vô hạn khi server trả con trỏ không tiến. 100 trang × 1000 = 100.000
  /// document, xa trên mọi kho từ thực tế.
  static const int _runQueryMaxPages = 100;

  /// Query collection con của [parentPath] (vd 'users/{uid}'),
  /// lọc field > [filterAfter] (vd '_syncedAt' > checkpoint).
  ///
  /// PSRC-262 — PHÂN TRANG ĐẦY ĐỦ. Trước đây hàm chỉ bắn MỘT request rồi
  /// dừng: Firestore trả về theo TỪNG TRANG, nên khi kho đồng bộ lớn
  /// (vài nghìn từ), mọi document sau trang đầu bị BỎ SÓT âm thầm → Worklist
  /// trên Linux/desktop thiếu hàng loạt từ, kể cả từ mới lưu. Giờ vòng lặp
  /// đi theo con trỏ `startAt(readTime của doc cuối trang trước)` cho tới
  /// khi server trả ít hơn một trang (hết dữ liệu).
  Future<List<FirestoreRestDoc>> runQuery({
    required String parentPath,
    required String collectionId,
    String? filterField,
    Object? filterAfter,
  }) async {
    final result = <FirestoreRestDoc>[];
    final seen = <String>{};
    DateTime? cursor;
    for (var page = 0; page < _runQueryMaxPages; page++) {
      final pageDocs = await _runQueryPage(
        parentPath: parentPath,
        collectionId: collectionId,
        filterField: filterField,
        filterAfter: filterAfter,
        startAfter: cursor,
      );
      if (pageDocs.isEmpty) break;

      var progressed = false;
      for (final doc in pageDocs) {
        if (seen.add(doc.id)) result.add(doc);
        final rt = doc.readTime;
        if (rt != null && (cursor == null || rt.isAfter(cursor))) {
          cursor = rt;
          progressed = true;
        }
      }

      // Điều kiện dừng:
      //  - Server trả ÍT HƠN một trang → đã hết dữ liệu.
      //  - Không còn con trỏ để tiến (server không trả readTime, hoặc toàn
      //    doc trùng) → tránh vòng lặp vô hạn; coi như đã đọc hết.
      if (pageDocs.length < _runQueryPageSize) break;
      if (!progressed) break;
    }
    return result;
  }

  /// Một trang `runQuery`. Khi [startAfter] (readTime của doc cuối trang
  /// trước) được cung cấp, thêm `startAt` để lấy trang KẾ TIẾP — đây là cơ
  /// chế phân trang chuẩn của Firestore REST cho `structuredQuery`.
  Future<List<FirestoreRestDoc>> _runQueryPage({
    required String parentPath,
    required String collectionId,
    String? filterField,
    Object? filterAfter,
    DateTime? startAfter,
  }) async {
    final structured = <String, dynamic>{
      'from': [
        {'collectionId': collectionId}
      ],
      'limit': _runQueryPageSize,
    };
    if (filterField != null && filterAfter != null) {
      structured['where'] = {
        'fieldFilter': {
          'field': {'fieldPath': filterField},
          'op': 'GREATER_THAN',
          'value': encodeValue(filterAfter),
        },
      };
      structured['orderBy'] = [
        {
          'field': {'fieldPath': filterField},
          'direction': 'ASCENDING',
        }
      ];
    }
    if (startAfter != null) {
      // Con trỏ phân trang: bắt đầu SAU readTime của trang trước. readTime
      // tăng dần theo thứ tự trả về nên luôn tiến được, không sót/trùng.
      structured['startAt'] = {
        'values': [
          {'readTime': startAfter.toUtc().toIso8601String()}
        ],
        'before': false,
      };
    }

    final resp = await _post('$_documentsBaseUrl:runQuery', {
      'parent': 'projects/$projectId/databases/(default)/documents/$parentPath',
      'structuredQuery': structured,
    });

    final decoded = jsonDecode(resp.body) as List<dynamic>;
    final result = <FirestoreRestDoc>[];
    for (final item in decoded) {
      final map = item as Map<String, dynamic>;
      final docMap = map['document'] as Map<String, dynamic>?;
      if (docMap == null) continue;
      final doc = _parseDocument(docMap);
      if (doc != null) result.add(doc);
    }
    return result;
  }

  FirestoreRestDoc? _parseDocument(Map<String, dynamic> docMap) {
    final name = docMap['name'] as String?;
    if (name == null) return null;
    final id = name.split('/').last;
    final fields = decodeFields(docMap['fields'] as Map<String, dynamic>?);
    final readTime = DateTime.tryParse('${docMap['readTime'] ?? ''}');
    return FirestoreRestDoc(id, fields, readTime: readTime);
  }

  // ═════════════════════════════════════════════════════════════
  // HTTP
  // ═════════════════════════════════════════════════════════════

  Future<http.Response> _get(String url) async {
    final token = await _requireIdToken();
    return http
        .get(Uri.parse(url), headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        })
        .timeout(_requestTimeout);
  }

  Future<http.Response> _post(String url, Map<String, dynamic> body) async {
    final token = await _requireIdToken();
    final resp = await http
        .post(Uri.parse(url),
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body))
        .timeout(_requestTimeout);
    if (resp.statusCode != 200) {
      throw FirestoreRestException(
          resp.statusCode, _errorMessage(resp.body));
    }
    return resp;
  }

  Future<String> _requireIdToken() async {
    final token = await FirebaseRestAuth().getIdToken();
    if (token == null) {
      throw const FirebaseRestAuthException(
          'Chưa đăng nhập (REST session hết hạn)');
    }
    return token;
  }

  String _errorMessage(String body) {
    try {
      final decoded = jsonDecode(body) as Map<String, dynamic>;
      final error = decoded['error'] as Map<String, dynamic>?;
      return error?['message'] as String? ?? body;
    } catch (_) {
      return body;
    }
  }

  // ═════════════════════════════════════════════════════════════
  // Value codec: Dart JSON ↔ Firestore REST "fields" format
  // ═════════════════════════════════════════════════════════════

  Map<String, dynamic> encodeFields(Map<String, dynamic> fields) =>
      {for (final e in fields.entries) e.key: encodeValue(e.value)};

  Map<String, dynamic> decodeFields(Map<String, dynamic>? fields) =>
      {for (final e in (fields ?? {}).entries) e.key: decodeValue(e.value)};

  /// Dart value → Firestore REST value wrapper.
  Map<String, dynamic> encodeValue(Object? v) {
    if (v == null) return {'nullValue': null};
    if (v is bool) return {'booleanValue': v};
    if (v is int) return {'integerValue': '$v'};
    if (v is num) return {'doubleValue': v};
    if (v is String) return {'stringValue': v};
    if (v is DateTime) {
      return {'timestampValue': v.toUtc().toIso8601String()};
    }
    if (v is Iterable) {
      return {
        'arrayValue': {
          'values': [for (final e in v) encodeValue(e)],
        }
      };
    }
    if (v is Map) {
      return {
        'mapValue': {'fields': encodeFields(Map<String, dynamic>.from(v))}
      };
    }
    // Fallback: không mất dữ liệu khi lưu
    return {'stringValue': v.toString()};
  }

  /// Firestore REST value wrapper → Dart value.
  Object? decodeValue(Object? raw) {
    if (raw is! Map) return null;
    final v = raw;
    if (v.containsKey('nullValue')) return null;
    if (v.containsKey('booleanValue')) return v['booleanValue'] as bool?;
    if (v.containsKey('integerValue')) {
      return int.tryParse('${v['integerValue']}');
    }
    if (v.containsKey('doubleValue')) return (v['doubleValue'] as num?)?.toDouble();
    if (v.containsKey('stringValue')) return v['stringValue'] as String?;
    if (v.containsKey('timestampValue')) {
      return DateTime.tryParse('${v['timestampValue']}');
    }
    if (v.containsKey('mapValue')) {
      final inner = v['mapValue'] as Map<dynamic, dynamic>?;
      return decodeFields(
          inner?['fields'] as Map<String, dynamic>?);
    }
    if (v.containsKey('arrayValue')) {
      final inner = v['arrayValue'] as Map<dynamic, dynamic>?;
      final values = inner?['values'] as List<dynamic>? ?? [];
      return [for (final e in values) decodeValue(e)];
    }
    return null;
  }
}
