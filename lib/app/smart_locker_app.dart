import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'auth_gate.dart';

class SmartLockerApp extends StatelessWidget {
  const SmartLockerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Smart Locker',
      theme: AppTheme.dark,
      home: const AuthGate(),
    );
  }
}
