import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/api_config.dart';

class ApiClient {
  ApiClient._();
  static String? _token;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  /// Test-only hook: widget tests can stub POST responses without network.
  /// Production code leaves this null, in which case `post` behaves normally.
  static Future<dynamic> Function(String path, {Map<String,dynamic>? body, bool auth})? postOverride;
  static Future<dynamic> Function(String path, {Map<String,String>? query, bool auth})? getOverride;

  static bool get hasToken => _token != null && _token!.isNotEmpty;
  static String? get currentToken => _token;
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

  /// Per-account token vault (keyed by identifier) so the profiles page can
  /// switch between recently used accounts without re-entering passwords.
  static Future<void> saveTokenFor(String key, String token) =>
      _secureStorage.write(key: key, value: token);
  static Future<String?> loadTokenFor(String key) => _secureStorage.read(key: key);
  static Future<void> deleteTokenFor(String key) => _secureStorage.delete(key: key);
  static Map<String,String> _headers(bool auth) => {
    'Accept':'application/json','Content-Type':'application/json',
    if(auth && _token != null) 'Authorization':'Bearer $_token',
  };
  static Future<dynamic> get(String path,{Map<String,String>? query,bool auth=false}) {
    if (getOverride != null) return getOverride!(path, query: query, auth: auth);
    return _send('GET',path,query:query,auth:auth);
  }
  static Future<dynamic> post(String path,{Map<String,dynamic>? body,bool auth=false}) {
    if (postOverride != null) return postOverride!(path, body: body, auth: auth);
    return _send('POST',path,body:body,auth:auth);
  }
  static Future<dynamic> patch(String path,{Map<String,dynamic>? body,bool auth=false}) => _send('PATCH',path,body:body,auth:auth);
  static Future<dynamic> delete(String path,{Map<String,dynamic>? body,bool auth=false}) => _send('DELETE',path,body:body,auth:auth);

  static Future<dynamic> _send(String method,String path,{Map<String,String>? query,Map<String,dynamic>? body,bool auth=false}) async {
    var uri=Uri.parse(ApiConfig.endpoint(path));
    if(query!=null) uri=uri.replace(queryParameters:query);
    try {
      final h=_headers(auth);
      late http.Response res;
      if(method=='GET') { res=await http.get(uri,headers:h).timeout(const Duration(seconds:20)); }
      else if(method=='POST') { res=await http.post(uri,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:25)); }
      else if(method=='DELETE') { res=await http.delete(uri,headers:h,body:body==null?null:jsonEncode(body)).timeout(const Duration(seconds:20)); }
      else { res=await http.patch(uri,headers:h,body:jsonEncode(body??{})).timeout(const Duration(seconds:25)); }

      dynamic data;
      try { data=res.body.isEmpty?<String,dynamic>{}:jsonDecode(res.body); } catch (_) { data=null; }
      if(res.statusCode<200||res.statusCode>=300) {
        final serverMessage = data is Map
            ? (data['message'] ?? data['error'] ?? data['detail'])?.toString().trim()
            : null;
        throw ApiException(
          serverMessage == null || serverMessage.isEmpty
              ? ApiException.forStatus(res.statusCode).message
              : serverMessage,
          statusCode: res.statusCode,
        );
      }
      if (data == null && res.body.isNotEmpty) {
        throw const ApiException('BookIt received an unexpected response. Please try again.');
      }
      return data ?? <String,dynamic>{};
    } on ApiException { rethrow; }
    on TimeoutException {
      throw const ApiException('BookIt is taking too long to respond. Please try again.');
    } catch (_) {
      throw const ApiException('Could not connect to BookIt. Check your internet connection and try again.');
    }
  }
}

class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  factory ApiException.forStatus(int statusCode) {
    final message = switch (statusCode) {
      400 => 'Some information is missing or invalid. Check your details and try again.',
      401 => 'Your session has expired. Please sign in again.',
      403 => 'You do not have permission to do that.',
      404 => 'We could not find what you are looking for.',
      409 => 'This request conflicts with a recent change. Refresh and try again.',
      422 => 'Please check the information you entered and try again.',
      429 => 'Too many attempts. Please wait a moment before trying again.',
      500 => 'BookIt ran into a problem. Please try again shortly.',
      502 => 'BookIt is temporarily unavailable. Please try again shortly.',
      503 => 'BookIt is undergoing maintenance. Please try again later.',
      _ when statusCode >= 500 => 'BookIt is temporarily unavailable. Please try again later.',
      _ => 'We could not complete that request. Please try again.',
    };
    return ApiException(message, statusCode: statusCode);
  }

  @override String toString()=>message;
}
