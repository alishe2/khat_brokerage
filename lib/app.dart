import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/presentation/login_screen.dart';

class KhatBrokerageApp extends StatelessWidget {
  const KhatBrokerageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Khat Brokerage',
      theme: AppTheme.lightTheme,
      home: const LoginScreen(),
    );
  }
}