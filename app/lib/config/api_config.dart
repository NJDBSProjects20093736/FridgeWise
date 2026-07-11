/// API base URL — use 10.0.2.2:8000 for Android emulator, localhost for iOS sim / desktop.
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://127.0.0.1:8000',
  );

  static const int demoUserId = 5060;
}
