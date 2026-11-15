// lib/services/auth_service.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      // Helpful in debug console to see the *real* reason
      debugPrint('signIn error: ${e.code} | ${e.message}');
      return null;
    } catch (e) {
      debugPrint('signIn unknown error: $e');
      return null;
    }
  }

  Future<User?> signUp(String email, String password) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      return cred.user;
    } on FirebaseAuthException catch (e) {
      debugPrint('signUp error: ${e.code} | ${e.message}');
      return null;
    } catch (e) {
      debugPrint('signUp unknown error: $e');
      return null;
    }
  }

  Future<void> signOut() => _auth.signOut();
}
