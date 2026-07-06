import 'package:flutter/foundation.dart';

/// Single source of truth for build-time configuration.
///
/// The API base URL can be overridden at build time:
///   flutter run --dart-define=API_BASE_URL=https://api.example.com
///
/// Hosted Firebase builds auto-detect [gemscramble.web.app] and point at the
/// Railway API so you don't need --dart-define for production deploys.
class AppConfig {
  AppConfig._();

  static const String _definedBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Production Railway API used by Firebase Hosting builds.
  static const String productionApiBaseUrl =
      'https://scramblecash-production.up.railway.app';

  static String get apiBaseUrl {
    if (_definedBaseUrl.isNotEmpty) return _definedBaseUrl;
    if (kIsWeb) {
      final host = Uri.base.host.toLowerCase();
      if (host == 'localhost' || host == '127.0.0.1') {
        return 'http://localhost:8080';
      }
      if (host == 'gemscramble.web.app' ||
          host == 'gemscramble.firebaseapp.com') {
        return productionApiBaseUrl;
      }
      // Other hosted web builds: set API_BASE_URL via --dart-define.
      return '';
    }
    return kDebugMode ? 'http://localhost:8080' : productionApiBaseUrl;
  }
}
