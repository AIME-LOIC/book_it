import 'package:flutter/material.dart';

import 'screens/loading_screen.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BookItApp());
}

class BookItApp extends StatelessWidget {
  const BookItApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BookIt',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const LoadingScreen(),
    );
  }
}
