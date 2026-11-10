import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Optional Firebase layer for the browser entrypoint.
///
/// The Web Core remains usable when Firebase is not configured, so a Firebase
/// initialization error never turns the static web app into a blank page.
class WebCloudService extends ChangeNotifier {
  FirebaseAuth? _auth;
  FirebaseFirestore? _firestore;
  StreamSubscription<User?>? _authStateSubscription;
  String? _initializationError;

  static Future<WebCloudService> initialize() async {
    final service = WebCloudService();
    try {
      final app = Firebase.apps.isNotEmpty
          ? Firebase.app()
          : await Firebase.initializeApp(
              options: DefaultFirebaseOptions.web,
            );
      service._auth = FirebaseAuth.instanceFor(app: app);
      service._firestore = FirebaseFirestore.instanceFor(app: app);
      service._authStateSubscription =
          service._auth!.authStateChanges().listen((_) {
        service.notifyListeners();
      });
    } catch (error) {
      service._initializationError = error.toString();
      debugPrint('[web-core] Firebase unavailable: $error');
    }
    return service;
  }

  bool get isConfigured => _auth != null && _firestore != null;
  String? get initializationError => _initializationError;
  User? get user => _auth?.currentUser;
  bool get isSignedIn => user != null;

  @override
  void dispose() {
    final subscription = _authStateSubscription;
    if (subscription != null) unawaited(subscription.cancel());
    super.dispose();
  }

  Future<void> signInWithGoogle() async {
    final auth = _auth;
    if (auth == null) {
      throw StateError('Firebase Web chưa được cấu hình.');
    }

    final provider = GoogleAuthProvider()
      ..addScope('email')
      ..setCustomParameters({'prompt': 'select_account'});
    await auth.signInWithPopup(provider);
    notifyListeners();
  }

  Future<void> signOut() async {
    await _auth?.signOut();
    notifyListeners();
  }

  Future<void> saveVocabularyWord(String word) async {
    final firestore = _firestore;
    final currentUser = user;
    final normalized = word.trim();
    if (firestore == null || currentUser == null || normalized.isEmpty) return;

    final documentId = base64Url
        .encode(utf8.encode(normalized.toLowerCase()))
        .replaceAll('=', '');
    await firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('web_core_vocab')
        .doc(documentId)
        .set({
      'word': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
      'source': 'web_core',
    }, SetOptions(merge: true));
  }

  Future<List<String>> loadVocabularyWords() async {
    final firestore = _firestore;
    final currentUser = user;
    if (firestore == null || currentUser == null) return const [];

    final snapshot = await firestore
        .collection('users')
        .doc(currentUser.uid)
        .collection('web_core_vocab')
        .orderBy('updatedAt', descending: true)
        .limit(500)
        .get();

    return snapshot.docs
        .map((doc) => doc.data()['word'])
        .whereType<String>()
        .map((word) => word.trim())
        .where((word) => word.isNotEmpty)
        .toList(growable: false);
  }
}
