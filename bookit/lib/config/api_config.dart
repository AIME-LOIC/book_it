/// API environment configuration for the BookIt mobile client.
class ApiConfig {
  const ApiConfig._();

  /// Deployed BookIt API prefix. Override with --dart-define=API_BASE_URL=...
  static const String _baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://bookit.1percent.rw/rw/v1/bk',
  );

  static bool get isConfigured => _baseUrl.isNotEmpty;

  static String endpoint(String path) =>
      '${_baseUrl.replaceFirst(RegExp(r'/+$'), '')}/${path.replaceFirst(RegExp(r'^/+'), '')}';
}
