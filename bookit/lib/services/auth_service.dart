import 'api_client.dart';
class AuthService {
  AuthService._();
  static Future<String> login({required String email,required String password}) async {
    try {
      final res=await ApiClient.post('auth/login',body:{'email':email.trim(),'password':password});
      if(res is! Map||res['user'] is! Map||res['token']==null) {
        throw const AuthException('The deployed API did not return a mobile access token. Redeploy the backend update and try again.');
      }
      ApiClient.setToken(res['token'].toString());
      final user=Map<String,dynamic>.from(res['user'] as Map);
      return (user['name']??email.split('@').first).toString();
    } on ApiException catch(e) { throw AuthException(e.message); }
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
