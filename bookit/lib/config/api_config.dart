/// Central place where every API key / endpoint used by BookIt is read from.
///
/// Keys are injected at build/run time with Flutter's `--dart-define-from-file`
/// flag (no source changes needed to swap environments):
///
///   flutter run --dart-define-from-file=config/bookit_keys.env
///
/// Create your own `config/bookit_keys.env` from the provided
/// `config/bookit_keys.example.env` template. The `.env` files are
/// git-ignored so real keys never hit source control.
class ApiConfig {
  const ApiConfig._();

  /// Base URL of the BookIt REST API.
  static const String _baseUrl =
      String.fromEnvironment('API_BASE_URL', defaultValue: '');

  /// Public client key sent with every request as `x-api-key`.
  static const String _apiKey =
      String.fromEnvironment('API_KEY', defaultValue: '');

  /// Key used by the auth endpoints (falls back to [apiKey]) or special auth
  /// providers that need a dedicated key.
  static const String _authApiKey =
      String.fromEnvironment('AUTH_API_KEY', defaultValue: '');

  /// Application id used by analytics / push notification providers.
  static const String appId = String.fromEnvironment('APP_ID', defaultValue: '');

  // ------------------------------------------------------------------------

  /// Full URL for [path], guaranteed not to double up slashes.
  static String endpoint(String path) =>
      '$_baseUrl/${path.startsWith('/') ? path.substring(1) : path}';

  /// HTTP headers that should accompany every API request.
  static Map<String, String> headers({String? authToken}) => {
        'Content-Type': 'application/json',
        if (apiKeyConfigured) 'x-api-key': _apiKey,
        if (authToken != null) 'Authorization': 'Bearer $authToken',
      };

  /// Raw auth key (for endpoints that use a separate key from the main one).
  static String get authApiKeyRaw =>
      _authApiKey.isNotEmpty ? _authApiKey : _apiKey;

  /// A key is considered "configured" when a real (non-placeholder) value was
  /// provided via --dart-define-from-file.
  static bool get apiKeyConfigured => _apiKey.isNotEmpty &&
      !_placeholders.contains(_apiKey.trim().toLowerCase());
  static bool get baseUrlConfigured =>
      _baseUrl.isNotEmpty && !_placeholders.contains(_baseUrl.toLowerCase());
  static bool get isConfigured => apiKeyConfigured && baseUrlConfigured;

  /// Path of the env file shipped as a template in the repo.
  static const String templatePath = 'config/bookit_keys.example.env';

  static const List<String> _placeholders = [
    '',
    'replace_with_api_key',
    'replace_with_auth_key',
    'replace_with_app_id',
    'https://api.bookit.example.com/v1',
  ];
}
