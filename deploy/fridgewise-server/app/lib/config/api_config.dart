import 'package:flutter/foundation.dart' show kIsWeb;

/// API base URL — use 10.0.2.2:8000 for Android emulator, localhost for iOS sim / desktop.
/// Docker/web: leave [API_BASE_URL] unset at build time to use `{origin}/api` behind nginx.
class ApiConfig {
  static const String _envBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_envBaseUrl.isNotEmpty) {
      return _envBaseUrl.replaceAll(RegExp(r'/+$'), '');
    }
    if (kIsWeb) {
      return '${Uri.base.origin}/api';
    }
    return 'http://127.0.0.1:8000';
  }

  static const int demoUserId = 5060;
}
