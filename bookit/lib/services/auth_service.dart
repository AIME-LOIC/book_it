import '../config/api_config.dart';

/// Minimal auth service for the demo.
///
/// It attaches keys from [ApiConfig] to every call so that swapping the
/// placeholder `config/bookit_keys.env` for a real one automatically wires the
/// app to a live backend. Until real keys exist it accepts any valid
/// credentials offline so the UI is fully usable.
class AuthService {
  const AuthService._();

  /// Signs in with [email] and [password].
  ///
  /// Returns the display name extracted from the email on success.
  static Future<String> login({
    required String email,
    required String password,
  }) async {
    // Simulated network round-trip. When a real backend is configured,
    // replace with e.g.:
    //   final res = await http.post(
    //     Uri.parse(ApiConfig.endpoint('auth/login')),
    //     headers: ApiConfig.headers(),
    //     body: jsonEncode({'email': email, 'password': password}),
    //   );
    // ignore: unused_local_variable
    final requestHeaders = ApiConfig.headers();

    await Future<void>.delayed(const Duration(milliseconds: 1400));

    if (email.trim().isEmpty || password.length < 6) {
      throw const AuthException('Please enter a valid email and password.');
    }

    final name = email.split('@').first;
    final pretty = name
        .split(RegExp(r'[._\-\s]+'))
        .where((part) => part.isNotEmpty)
        .map((part) => part[0].toUpperCase() + part.substring(1))
        .join(' ');
    return pretty.isEmpty ? 'Explorer' : pretty;
  }
}

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}
