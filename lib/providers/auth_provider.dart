import 'package:firebase_auth/firebase_auth.dart' as fb_auth;
import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/result.dart';
import '../models/user.dart';
import '../repositories/auth_repository.dart';

enum AuthStatus { unknown, unauthenticated, authenticating, authenticated }

/// Presentation state for authentication. Delegates all IO to
/// [AuthRepository] and exposes a simple status machine for the UI.
class AuthProvider extends ChangeNotifier {
  AuthProvider(this._repository);

  final AuthRepository _repository;

  AuthStatus _status = AuthStatus.unknown;
  AuthMode? _authMode;
  String? _error;

  AuthStatus get status => _status;
  AuthMode? get authMode => _authMode;
  bool get isDevMode => _authMode == AuthMode.dev;
  String? get error => _error;

  /// Resolves auth mode and restores any persisted session.
  Future<void> initialize() async {
    _authMode = await _repository.getAuthMode();
    final hasSession = await _repository.restoreSession();
    _status =
        hasSession ? AuthStatus.authenticated : AuthStatus.unauthenticated;
    notifyListeners();

    // In Firebase mode, keep the status in sync with the auth stream
    // (e.g. token revocation, sign-out from another surface).
    if (_authMode == AuthMode.firebase) {
      fb_auth.FirebaseAuth.instance.authStateChanges().listen((user) {
        final next = user != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
        if (next != _status) {
          _status = next;
          notifyListeners();
        }
      });
    }
  }

  /// Dev-mode login (or register) by username.
  Future<User?> loginDev(String username) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();

    final result = await _repository.loginOrRegisterDev(username.trim());
    return result.when(
      success: (user) {
        _status = AuthStatus.authenticated;
        notifyListeners();
        return user;
      },
      failure: (message) {
        _status = AuthStatus.unauthenticated;
        _error = message;
        notifyListeners();
        return null;
      },
    );
  }

  /// Firebase email/password sign-in. Returns null on success or a
  /// user-facing error message on failure.
  Future<String?> signInWithEmail(String email, String password) =>
      _runFirebaseAuth(() => _repository.signInWithEmail(email, password));

  /// Firebase sign-up; also claims the chosen username on the backend.
  Future<String?> signUpWithEmail(
    String email,
    String password,
    String username,
  ) =>
      _runFirebaseAuth(() async {
        await _repository.signUpWithEmail(email, password);
        final result = await _repository.setUsername(username);
        if (result case Failure(:final message)) {
          debugPrint('Could not set username after sign-up: $message');
        }
      });

  Future<String?> _runFirebaseAuth(Future<void> Function() action) async {
    _status = AuthStatus.authenticating;
    _error = null;
    notifyListeners();
    try {
      await action();
      _status = AuthStatus.authenticated;
      notifyListeners();
      return null;
    } on fb_auth.FirebaseAuthException catch (e) {
      _status = AuthStatus.unauthenticated;
      _error = _mapFirebaseError(e);
      notifyListeners();
      return _error;
    } catch (_) {
      _status = AuthStatus.unauthenticated;
      _error = 'An unexpected error occurred.';
      notifyListeners();
      return _error;
    }
  }

  Future<void> logout() async {
    await _repository.logout();
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  static String _mapFirebaseError(fb_auth.FirebaseAuthException e) {
    const prefix = 'Authentication failed. ';
    return switch (e.code) {
      'user-not-found' => '${prefix}No user found with this email.',
      'wrong-password' => '${prefix}Incorrect password.',
      'email-already-in-use' =>
        '${prefix}An account already exists with this email.',
      'weak-password' => '${prefix}Password is too weak.',
      'invalid-email' => '${prefix}Invalid email address.',
      _ => '$prefix${e.message ?? 'Unknown error occurred.'}',
    };
  }
}
