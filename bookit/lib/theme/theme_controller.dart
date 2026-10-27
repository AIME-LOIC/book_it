import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();
  static final ValueNotifier<String> mode = ValueNotifier<String>('white');
  static SharedPreferences? _preferences;

  static Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences?.getString('bookit_theme');
    if (saved == 'dark' || saved == 'green' || saved == 'white') mode.value = saved!;
  }

  static Future<void> setMode(String value) async {
    if (value != 'dark' && value != 'green' && value != 'white') return;
    mode.value = value;
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString('bookit_theme', value);
  }
}
