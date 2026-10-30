import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController {
  ThemeController._();
  static final ValueNotifier<String> mode = ValueNotifier<String>('device');
  static SharedPreferences? _preferences;

  static Future<void> load() async {
    _preferences = await SharedPreferences.getInstance();
    final saved = _preferences?.getString('bookit_theme');
    if (saved == 'device' || saved == 'white' || saved == 'blue_dark' || saved == 'dark') {
      mode.value = saved == 'dark' ? 'blue_dark' : saved!;
    } else if (saved == 'green' || saved == 'green_dark') {
      // Temporarily map old saved green themes to the available blue palettes.
      mode.value = saved == 'green_dark' ? 'blue_dark' : 'white';
      await _preferences?.setString('bookit_theme', mode.value);
    }
  }

  static Future<void> setMode(String value) async {
    if (value != 'device' && value != 'white' && value != 'blue_dark') return;
    mode.value = value;
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString('bookit_theme', value);
  }
}
