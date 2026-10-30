import 'api_client.dart';
class AuthService {
  AuthService._();
  static Future<String> login({required String email,required String password}) async {
    try {
      final res=await ApiClient.post('auth/login',body:{'email':email.trim(),'password':password});
      if(res is! Map||res['user'] is! Map||res['token']==null) {
        throw const AuthException('The deployed API did not return a mobile access token. Redeploy the backend update and try again.');
      }
      await ApiClient.saveToken(res['token'].toString());
      final user=Map<String,dynamic>.from(res['user'] as Map);
      return (user['name']??email.split('@').first).toString();
    } on ApiException catch(e) { throw AuthException(e.message); }
  }
  static Future<String?> restoreSession() async {
    try {
      await ApiClient.loadToken();
      if (!ApiClient.hasToken) return null;
      final res = await ApiClient.get('auth/me', auth: true);
      final rawUser = res is Map && res['user'] is Map ? res['user'] : res;
      if (rawUser is Map) {
        final user = Map<String, dynamic>.from(rawUser);
        return (user['name'] ?? user['full_name'] ?? user['email'] ?? 'BookIt user').toString();
      }
      return 'BookIt user';
    } on ApiException catch (e) {
      if (e.message.contains('HTTP 401') || e.message.contains('HTTP 403')) {
        try { await ApiClient.clearToken(); } catch (_) {}
      }
      return null;
    } catch (_) {
      return null;
    }
  }
  static Future<String> register({required String name,required String email,required String phone,required String password}) async {
    try {
      await ApiClient.post('auth/register',body:{'name':name.trim(),'email':email.trim(),'phone':phone.trim(),'password':password});
      return await login(email:email,password:password);
    } on ApiException catch(e) { throw AuthException(e.message); }
  }
}
class AuthException implements Exception {
  const AuthException(this.message);
  final String message;
  @override String toString()=>message;
}
