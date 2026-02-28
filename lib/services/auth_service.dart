// lib/services/auth_service.dart

import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

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

  // ─── Google Sign In ───────────────────────────────────────
  Future<User?> signInWithGoogle() async {
    // Không hỗ trợ Windows / Linux desktop
    if (!kIsWeb && (Platform.isWindows || Platform.isLinux)) {
      debugPrint('⚠️ Auth: Google Sign In không hỗ trợ trên Desktop');
      return null;
    }

    try {
      // Khởi tạo lazy — chỉ tạo 1 lần
      _googleSignIn ??= GoogleSignIn(scopes: ['email']);

      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();

      if (googleUser == null) {
        debugPrint('⚠️ Auth: user cancelled Google sign in');
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Nếu đang anonymous → link để giữ data cũ
      if (_auth.currentUser?.isAnonymous == true) {
        try {
          final result =
              await _auth.currentUser!.linkWithCredential(credential);
          debugPrint('✅ Auth: anonymous linked → ${result.user?.email}');
          return result.user;
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use') {
            // Google account đã tồn tại → đăng nhập thẳng
            final result = await _auth.signInWithCredential(credential);
            debugPrint('✅ Auth: existing account → ${result.user?.email}');
            return result.user;
          }
          rethrow;
        }
      }

      // Đăng nhập bình thường
      final result = await _auth.signInWithCredential(credential);
      debugPrint('✅ Auth: Google signed in → ${result.user?.email}');
      return result.user;
    } catch (e) {
      debugPrint('❌ Auth: Google sign in error: $e');
      return null;
    }
  }

  // ─── Sign Out ─────────────────────────────────────────────
  Future<void> signOut() async {
    try {
      await _googleSignIn?.signOut();
    } catch (e) {
      debugPrint('❌ Auth: Google sign out error: $e');
    }
    await _auth.signOut();
    debugPrint('✅ Auth: signed out');
  }
}
