// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'utils/app_store.dart';
import 'utils/theme.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = AppStore();
  await store.load();
  runApp(
    ChangeNotifierProvider.value(
      value: store,
      child: const TailorApp(),
    ),
  );
}

class TailorApp extends StatelessWidget {
  const TailorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bhuvana Designers',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const HomeScreen(),
    );
  }
}
