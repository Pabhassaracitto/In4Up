// lib/features/great_library/services/contribution_transport_firestore.dart
//
// GLIB-006 — ContributionTransport thật: ghi doc `gl_contributions` qua
// Firestore REST (POST documents/gl_contributions). BẮT BUỘC idToken (rules:
// create chỉ khi đăng nhập, authorUid == auth.uid, status == 'pending').

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../services/firebase_rest_auth.dart';
import '../../../services/firestore_rest_client.dart';
import 'pack_contribution_service.dart';

class FirestoreContributionTransport implements ContributionTransport {
  FirestoreContributionTransport({
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

  @override
  Future<String> submitContribution({
    required String packId,
    required Map<String, dynamic> manifestJson,
    required String storageBackend,
    required String storagePath,
    required int zipBytes,
    required String sha256,
  }) async {
    final String? token;
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

    final fields = FirestoreRestClient().encodeFields(<String, dynamic>{
      'packId': packId,
      'authorUid': manifestJson['author'] is Map
          ? ((manifestJson['author'] as Map)['uid'] ?? '')
          : '',
      'status': 'pending',
      'manifest': manifestJson,
      'storage': <String, dynamic>{
        'backend': storageBackend,
        'path': storagePath,
      },
      'zipBytes': zipBytes,
      'sha256': sha256,
      'submittedAt': DateTime.now().toUtc(),
    });

    final uri = Uri.https(
      'firestore.googleapis.com',
      '/v1/projects/$_projectId/databases/(default)/documents/gl_contributions',
    );
    final http.Response response;
    try {
      response = await _client
          .post(uri,
              headers: <String, String>{
                'Content-Type': 'application/json',
                'Authorization': 'Bearer $token',
              },
              body: jsonEncode(<String, dynamic>{'fields': fields}))
          .timeout(requestTimeout);
    } on TimeoutException {
      throw const ContributionException('timeout');
    } on http.ClientException catch (e) {
      throw ContributionException('network', e.message);
    }
    if (response.statusCode != 200) {
      throw ContributionException(
          'http-${response.statusCode}', response.body);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final name = decoded['name'] as String? ?? '';
    return name.split('/').last;
  }

  void dispose() {
    if (_ownsClient) _client.close();
  }
}
