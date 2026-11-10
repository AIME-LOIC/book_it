import 'api_client.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class AuthService {
  AuthService._();
  static bool isDriverSession = false;
  static String _promptKey(String identifier) => 'bookit_profile_prompted_${identifier.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_')}';
  static Future<bool> shouldAskToSaveProfile(String identifier) async { final prefs=await SharedPreferences.getInstance(); return !(prefs.getBool(_promptKey(identifier)) ?? false); }
  static Future<void> markSaveProfilePrompted(String identifier) async { final prefs=await SharedPreferences.getInstance(); await prefs.setBool(_promptKey(identifier), true); }
  static Future<void> saveCurrentAccount({required String name, required String identifier, required String type}) async { final token=await ApiClient.loadTokenFor('bookit_access_token'); final activeToken=token ?? await _readActiveToken(); if(activeToken==null||activeToken.isEmpty)return; await _recordAccount(name:name,identifier:identifier,type:type,token:activeToken); }
  static Future<String?> _readActiveToken() async { await ApiClient.loadToken(); return ApiClient.currentToken; }
  static Future<void> updateSavedProfileName(String name) async { final prefs=await SharedPreferences.getInstance(); final identifier=prefs.getString('bookit_saved_profile_identifier'); final type=prefs.getString('bookit_saved_profile_type')??'customer'; if(identifier==null||identifier.isEmpty)return; final accounts=await savedAccounts(); final index=accounts.indexWhere((a)=>a['identifier']==identifier); if(index<0)return; accounts[index]['name']=name; accounts[index]['at']=DateTime.now().millisecondsSinceEpoch.toString(); await prefs.setString(_accountsKey,jsonEncode(accounts)); await prefs.setString('bookit_saved_profile_name',name); }

  /// Saved accounts for the post-splash profiles page: most recently used
  /// first, capped so the list stays readable. Tokens live outside this list
  /// (per-account, in secure storage) and are never persisted in prefs.
  static const String _accountsKey = 'bookit_saved_accounts';
  static const int _maxAccounts = 5;
  static String accountTokenKey(String identifier) {
    final slug = identifier.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    return 'bookit_token_$slug';
  }

  static Future<List<Map<String, String>>> savedAccounts() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_accountsKey);
      if (raw == null) return [];
      final list = jsonDecode(raw) as List;
      return list
          .whereType<Map>()
          .map((m) => {
                'name': m['name']?.toString() ?? '',
                'identifier': m['identifier']?.toString() ?? '',
                'type': m['type']?.toString() ?? 'customer',
                'at': m['at']?.toString() ?? '0',
              })
          .where((a) => a['identifier']!.trim().isNotEmpty)
          .toList();
    } catch (_) { return []; }
  }

  static Future<void> removeAccount(String identifier) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await savedAccounts();
      accounts.removeWhere((a) => a['identifier'] == identifier);
      await prefs.setString(_accountsKey, jsonEncode(accounts));
      final stale = prefs.getString('bookit_saved_profile_identifier') == identifier;
      await prefs.remove('bookit_saved_profile_name');
      await prefs.remove('bookit_saved_profile_identifier');
      await prefs.remove('bookit_saved_profile_type');
      await prefs.remove('bookit_saved_profile_at');
      if (stale) {} // single-profile prefs cleared for cleanliness.
      await ApiClient.deleteTokenFor(accountTokenKey(identifier));
    } catch (_) {}
  }

  static Future<void> _recordAccount({required String name, required String identifier, required String type, required String token}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final accounts = await savedAccounts();
      accounts.removeWhere((a) => a['identifier'] == identifier);
      accounts.insert(0, {
        'name': name,
        'identifier': identifier,
        'type': type,
        'at': DateTime.now().millisecondsSinceEpoch.toString(),
      });
      while (accounts.length > _maxAccounts) {
        accounts.removeLast();
      }
      await prefs.setString(_accountsKey, jsonEncode(accounts));
      await ApiClient.saveTokenFor(accountTokenKey(identifier), token);
    } catch (_) {}
  }

  /// Activates a saved account: loads its token, validates it with the API
  /// (401/403 invalidates and removes the account; network errors keep the
  /// session, matching [restoreSession]'s resilience), updates the active
  /// prefs, and returns the display name — or null if the account is unusable.
  static Future<String?> activateAccount(String identifier) async {
    final prefs = await SharedPreferences.getInstance();
    final accounts = await savedAccounts();
    final account = accounts.where((a) => a['identifier'] == identifier).firstOrNull;
    if (account == null) return null;
    final isDriver = account['type'] == 'driver';
    final token = await ApiClient.loadTokenFor(accountTokenKey(identifier));
    if (token == null || token.isEmpty) return null;
    ApiClient.setToken(token);
    try {
      await ApiClient.get(isDriver ? 'drivers/me' : 'auth/me', auth: true);
    } on ApiException catch (e) {
      if (e.statusCode == 401 || e.statusCode == 403) {
        await removeAccount(identifier);
        return null;
      }
      // Server or connectivity hiccup: use the stored profile anyway.
    } catch (_) {}
    isDriverSession = isDriver;
    await prefs.setBool('bookit_driver_session', isDriver);
    await prefs.setString('bookit_saved_profile_name', account['name']!);
    await prefs.setString('bookit_saved_profile_identifier', identifier);
    await prefs.setString('bookit_saved_profile_type', account['type']!);
    await prefs.setInt('bookit_saved_profile_at', int.tryParse(account['at'] ?? '') ?? DateTime.now().millisecondsSinceEpoch);
    return account['name'];
  }

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
      final name = (user['name'] ?? email.split('@').first).toString();
      await prefs.setString('bookit_saved_profile_name', name);
      await prefs.setString('bookit_saved_profile_identifier', email.trim());
      await prefs.setString('bookit_saved_profile_type', 'customer');
      await prefs.setInt('bookit_saved_profile_at', DateTime.now().millisecondsSinceEpoch);
      // Account persistence is now opt-in after the first successful login.
      return name;
    } on ApiException catch(e) { throw AuthException(e.message); }
  }
  static Future<String?> restoreSession() async {
    final prefs = await SharedPreferences.getInstance();
    isDriverSession = prefs.getBool('bookit_driver_session') ?? false;
    final savedName = prefs.getString('bookit_saved_profile_name');
    try {
      await ApiClient.loadToken();
      if (!ApiClient.hasToken) return null;
      final res = await ApiClient.get(
        isDriverSession ? 'drivers/me' : 'auth/me',
        auth: true,
      );
      final rawUser = res is Map && res['user'] is Map ? res['user'] : res;
      if (rawUser is Map) {
        final user = Map<String, dynamic>.from(rawUser);
        final name = (user['name'] ?? user['full_name'] ??
            user['email'] ?? savedName ?? 'BookIt user').toString();
        await prefs.setString('bookit_saved_profile_name', name);
        return name;
      }
      return savedName ?? 'BookIt user';
    } on ApiException catch (e) {
      // A network/server error must not force a user to sign in again.
      // Only discard a saved token when the API explicitly rejects it.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await ApiClient.clearToken();
        await prefs.remove('bookit_saved_profile_name');
        await prefs.remove('bookit_saved_profile_identifier');
        await prefs.remove('bookit_saved_profile_type');
        return null;
      }
      if (await _hasSavedToken()) return savedName ?? 'Saved BookIt profile';
      return null;
    } catch (_) {
      if (await _hasSavedToken()) return savedName ?? 'Saved BookIt profile';
      return null;
    }
  }

  static Future<bool> _hasSavedToken() async {
    await ApiClient.loadToken();
    return ApiClient.hasToken;
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
      final name = (driver['name'] ?? 'Driver').toString();
      await prefs.setString('bookit_saved_profile_name', name);
      await prefs.setString('bookit_saved_profile_identifier', phone.trim());
      await prefs.setString('bookit_saved_profile_type', 'driver');
      await prefs.setInt('bookit_saved_profile_at', DateTime.now().millisecondsSinceEpoch);
      // Driver account persistence is also opt-in after the first login.
      return name;
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
