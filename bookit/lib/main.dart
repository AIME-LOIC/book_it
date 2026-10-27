import 'package:flutter/material.dart';
import 'theme/theme_controller.dart';

import 'screens/loading_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await ThemeController.load();
  runApp(const BookItApp());
}

class BookItApp extends StatelessWidget {
  const BookItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: ThemeController.mode,
      builder: (context, mode, _) => MaterialApp(
        title: 'BookIt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeFor('white'),
        darkTheme: AppTheme.themeFor('blue_dark'),
        themeMode: mode == 'device' ? ThemeMode.system : (mode == 'blue_dark' ? ThemeMode.dark : ThemeMode.light),
        home: const LoadingScreen(),
      ),
    );
  }
}
