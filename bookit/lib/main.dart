import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme/theme_controller.dart';
import 'app_navigator.dart';

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
        navigatorKey: AppNavigator.key,
        title: 'BookIt',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.themeFor('white'),
        darkTheme: AppTheme.themeFor('blue_dark'),
        themeMode: mode == 'device' ? ThemeMode.system : (mode == 'blue_dark' ? ThemeMode.dark : ThemeMode.light),
        home: const LoadingScreen(),
        builder: (context, child) => AnnotatedRegion<SystemUiOverlayStyle>(
          value: AppTheme.statusBarOverlayStyle,
          child: child ?? const SizedBox.shrink(),
        ),
      ),
    );
  }
}
