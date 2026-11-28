// lib/features/great_library/services/moderation_transport_firestore.dart
//
// GLIB-007 — ModerationTransport thật qua Firestore REST (bắt buộc idToken
// admin; rules: chỉ admin đọc mọi contribution / ghi status / ghi gl_packs).

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/firebase_rest_auth.dart';
import '../../../services/firestore_rest_client.dart';
import 'admin_moderation_service.dart';
import 'pack_contribution_service.dart';

class FirestoreModerationTransport implements ModerationTransport {
  FirestoreModerationTransport({
    http.Client? client,
    String? projectIdOverride,
    Future<String?> Function()? idTokenProvider,
    this.requestTimeout = const Duration(seconds: 20),
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

  String get _base =>
      '/v1/projects/$_projectId/databases/(default)/documents';

  Future<String> _token() async {
    String? token;
    try {
      token = await (_idTokenProvider != null
          ? _idTokenProvider!()
          : FirebaseRestAuth().getIdToken());
    } on Object {
      token = null;
    }
    if (token == null || token.isEmpty) {
      throw const ContributionException('not-signed-in');
    }
    return token;
  }

  Map<String, String> _headers(String token) => <String, String>{
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  @override
  Future<List<PendingContribution>> fetchPending() async {
    final token = await _token();
    final body = <String, dynamic>{
      'parent': 'projects/$_projectId/databases/(default)/documents',
      'structuredQuery': <String, dynamic>{
        'from': <Map<String, dynamic>>[
          <String, dynamic>{'collectionId': 'gl_contributions'},
        ],
        'where': <String, dynamic>{
          'fieldFilter': <String, dynamic>{
            'field': <String, dynamic>{'fieldPath': 'status'},
            'op': 'EQUAL',
            'value': <String, dynamic>{'stringValue': 'pending'},
          },
        },
      },
    };
    final uri = Uri.https('firestore.googleapis.com', '$_base:runQuery');
    final http.Response response;
    try {
      response = await _client
          .post(uri, headers: _headers(token), body: jsonEncode(body))
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const ContributionException('timeout');
    } on http.ClientException catch (e) {
      throw ContributionException('network', e.message);
    }
    if (response.statusCode != 200) {
      throw ContributionException('http-${response.statusCode}');
    }
    final List<dynamic> rows = jsonDecode(response.body) as List<dynamic>;
    final decoder = FirestoreRestClient();
    final result = <PendingContribution>[];
    for (final row in rows) {
      final doc = (row as Map<String, dynamic>)['document'];
      if (doc is! Map<String, dynamic>) continue;
      final name = doc['name'] as String? ?? '';
      final fields = decoder
          .decodeFields(doc['fields'] as Map<String, dynamic>?);
      result.add(PendingContribution.fromDoc(name.split('/').last, fields));
    }
    // Mới nhất trước.
    result.sort((a, b) => b.submittedAtMs.compareTo(a.submittedAtMs));
    return result;
  }

  @override
  Future<void> updateStatus(
    String contributionId, {
    required String newStatus,
    String? reviewerNote,
  }) async {
    final token = await _token();
    final fields = <String, dynamic>{
      'status': newStatus,
      'reviewedAt': DateTime.now().toUtc(),
      if (reviewerNote != null) 'reviewerNote': reviewerNote,
    };
    // updateMask.fieldPaths lặp key — build query tay (Uri.https chỉ nhận
    // 1 value/key). Rules siết: chỉ đụng status/reviewedAt/reviewerNote.
    final query =
        fields.keys.map((k) => 'updateMask.fieldPaths=$k').join('&');
    final uriFull = Uri.https(
      'firestore.googleapis.com',
      '$_base/gl_contributions/$contributionId',
    ).replace(query: query);
    final http.Response response;
    try {
      response = await _client
          .patch(uriFull,
              headers: _headers(token),
              body: jsonEncode(<String, dynamic>{
                'fields': FirestoreRestClient().encodeFields(fields),
              }))
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const ContributionException('timeout');
    } on http.ClientException catch (e) {
      throw ContributionException('network', e.message);
    }
    if (response.statusCode != 200) {
      throw ContributionException('http-${response.statusCode}');
    }
  }

  @override
  Future<void> publishPack(PendingContribution contribution) async {
    final token = await _token();
    final manifest = Map<String, dynamic>.from(contribution.manifest);
    manifest['status'] = 'published';
    manifest['publishedAt'] = DateTime.now().toUtc().toIso8601String();
    final uri = Uri.https(
      'firestore.googleapis.com',
      '$_base/gl_packs/${contribution.packId}',
    );
    final http.Response response;
    try {
      response = await _client
          .patch(uri,
              headers: _headers(token),
              body: jsonEncode(<String, dynamic>{
                'fields': FirestoreRestClient().encodeFields(manifest),
              }))
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const ContributionException('timeout');
    } on http.ClientException catch (e) {
      throw ContributionException('network', e.message);
    }
    if (response.statusCode != 200) {
      throw ContributionException('http-${response.statusCode}');
    }
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
