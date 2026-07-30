import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/auth_controller.dart';
import 'screens/auth/auth_gate.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SnapyApp());
}

class SnapyApp extends StatelessWidget {
  const SnapyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthController(),
      child: MaterialApp(
        title: 'Snapy AI 3D',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const AuthGate(),
      ),
    );
  }
}
