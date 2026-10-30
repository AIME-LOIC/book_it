import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  ApiClient._();
  static String? _token;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  static bool get hasToken => _token != null && _token!.isNotEmpty;
  static void setToken(String? token) => _token = token;
  static Future<void> saveToken(String token) async {
    _token = token;
    await _secureStorage.write(key: 'bookit_access_token', value: token);
  }
  static Future<void> loadToken() async {
    _token = await _secureStorage.read(key: 'bookit_access_token');
  }
  static Future<void> clearToken() async {
    _token = null;
    await _secureStorage.delete(key: 'bookit_access_token');
  }
  static Map<String,String> _headers(bool auth) => {
    'Accept':'application/json','Content-Type':'application/json',
    if(auth && _token != null) 'Authorization':'Bearer $_token',
  };
  static Future<dynamic> get(String path,{Map<String,String>? query,bool auth=false}) => _send('GET',path,query:query,auth:auth);
  static Future<dynamic> post(String path,{Map<String,dynamic>? body,bool auth=false}) => _send('POST',path,body:body,auth:auth);
  static Future<dynamic> patch(String path,{Map<String,dynamic>? body,bool auth=false}) => _send('PATCH',path,body:body,auth:auth);
  static Future<dynamic> _send(String method,String path,{Map<String,String>? query,Map<String,dynamic>? body,bool auth=false}) async {
    var uri=Uri.parse(ApiConfig.endpoint(path));
    if(query!=null) uri=uri.replace(queryParameters:query);
    try {
      final h=_headers(auth);
      late http.Response res;
      if(method=='GET') { res=await http.get(uri,headers:h).timeout(const Duration(seconds:20)); }
      else if(method=='POST') { res=await http.post(uri,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:25)); }
      else { res=await http.patch(uri,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:25)); }
      dynamic data;
      try { data=res.body.isEmpty?<String,dynamic>{}:jsonDecode(res.body); } catch (_) { data={'message':res.body}; }
      if(res.statusCode<200||res.statusCode>=300) {
        final msg=data is Map?(data['message']??data['error']):null;
        final detail=data is Map?(data['details']??data['detail']??data['errors']??data['code']):null;
        final message=msg?.toString()??'Request failed';
        final diagnostic=detail==null?'':' Details: ${detail is String?detail:jsonEncode(detail)}';
        throw ApiException('$message (HTTP ${res.statusCode}).$diagnostic');
      }
      return data;
    } on ApiException { rethrow; }
    catch (_) { throw const ApiException('Could not connect to BookIt. Check your internet connection and try again.'); }
  }
}
class ApiException implements Exception {
  const ApiException(this.message);
  final String message;
  @override String toString()=>message;
}
