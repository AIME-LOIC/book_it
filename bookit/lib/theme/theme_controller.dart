import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();
  static final ValueNotifier<String> mode = ValueNotifier<String>('device');
  static SharedPreferences? _preferences;

  static Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences?.getString('bookit_theme');
    if (saved == 'device' || saved == 'dark' || saved == 'green' || saved == 'white' || saved == 'blue_dark' || saved == 'green_dark') mode.value = saved!;
  }

  static Future<void> setMode(String value) async {
    if (value != 'device' && value != 'dark' && value != 'green' && value != 'white' && value != 'blue_dark' && value != 'green_dark') return;
    mode.value = value;
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString('bookit_theme', value);
  }
}
