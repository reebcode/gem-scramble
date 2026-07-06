import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/api_client.dart';
import '../core/result.dart';
import '../models/user.dart';

/// Owns identity: session restore, login/logout, and username updates.
/// Persists the dev-mode user id and keeps [ApiClient.devUserId] in sync so
/// every request is issued as the signed-in user.
class AuthRepository {
  AuthRepository(this._api);

  static const _devUserIdKey = 'user_id';

  final ApiClient _api;

  Future<AuthMode> getAuthMode() => _api.getAuthMode();

  /// Restores a persisted dev-mode session, if any. Returns true when a
  /// session (dev id, or Firebase user) is available.
  Future<bool> restoreSession() async {
    if (await _api.isDevAuth()) {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString(_devUserIdKey);
      _api.devUserId = id;
      return id != null;
    }
    return fb_auth.FirebaseAuth.instance.currentUser != null;
  }

  /// Dev-mode only: login or register by username.
  Future<Result<User>> loginOrRegisterDev(String username) async {
    final result = await _api.postJson(
      'users/login-or-register',
      body: {'username': username},
      authenticated: false,
    );
    return switch (result) {
      Success(:final value) => await _persistDevUser(value),
      Failure(:final message) => Failure(message),
    };
  }

  Future<Result<User>> _persistDevUser(Map<String, dynamic> json) async {
    try {
      final user = User.fromJson(json);
      _api.devUserId = user.id;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_devUserIdKey, user.id);
      return Success(user);
    } catch (e) {
      return Failure('Unexpected login response: $e');
    }
  }

  /// Firebase mode: email/password sign-in. Throws [fb_auth.FirebaseAuthException]
  /// so the UI can map error codes to friendly messages.
  Future<void> signInWithEmail(String email, String password) =>
      fb_auth.FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

  Future<void> signUpWithEmail(String email, String password) =>
      fb_auth.FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

  Future<Result<void>> setUsername(String username) async {
    final result =
        await _api.postJson('users/username', body: {'username': username});
    return result.map((_) {});
  }

  Future<void> logout() async {
    try {
      await fb_auth.FirebaseAuth.instance.signOut();
    } catch (_) {
      // Firebase may not be initialized in dev mode; ignore.
    }
    _api.devUserId = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_devUserIdKey);
  }
}
