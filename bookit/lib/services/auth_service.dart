import 'api_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
class AuthService {
  AuthService._();
  static bool isDriverSession = false;
  static Future<String> login({required String email,required String password}) async {
    try {
      final res=await ApiClient.post('auth/login',body:{'email':email.trim(),'password':password});
      if(res is! Map||res['user'] is! Map||res['token']==null) {
        throw const AuthException('The deployed API did not return a mobile access token. Redeploy the backend update and try again.');
      }
      await ApiClient.saveToken(res['token'].toString());
      isDriverSession = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bookit_driver_session', false);
      final user=Map<String,dynamic>.from(res['user'] as Map);
      return (user['name']??email.split('@').first).toString();
    } on ApiException catch(e) { throw AuthException(e.message); }
  }
  static Future<String?> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDriverSession = prefs.getBool('bookit_driver_session') ?? false;
      await ApiClient.loadToken();
      if (!ApiClient.hasToken) return null;
      final res = await ApiClient.get(isDriverSession ? 'drivers/me' : 'auth/me', auth: true);
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
  static Future<String> loginDriver({required String phone, required String password}) async {
    try {
      final res = await ApiClient.post('drivers/login', body: {'phone': phone.trim(), 'password': password});
      if (res is! Map || res['token'] == null || res['driver'] is! Map) {
        throw const AuthException('The driver service did not return a valid session.');
      }
      await ApiClient.saveToken(res['token'].toString());
      isDriverSession = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('bookit_driver_session', true);
      final driver = Map<String, dynamic>.from(res['driver'] as Map);
      return (driver['name'] ?? 'Driver').toString();
    } on ApiException catch (e) { throw AuthException(e.message); }
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
