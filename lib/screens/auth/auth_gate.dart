import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../main_shell.dart';
import 'login_screen.dart';

/// Decides which screen to show based on the current auth session:
/// a brand splash while the stored session is being restored, the
/// login screen when there's no valid session, or the app itself.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AuthController>().bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthController>().status;
    switch (status) {
      case AuthStatus.unknown:
        return const _SplashView();
      case AuthStatus.authenticated:
        return const MainShell();
      case AuthStatus.unauthenticated:
        return const LoginScreen();
    }
  }
}

class _SplashView extends StatelessWidget {
  const _SplashView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.brandGradient),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 42),
            ),
            const SizedBox(height: 18),
            const Text(
              'Snapy AI 3D',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 26,
              height: 26,
              child: CircularProgressIndicator(strokeWidth: 2.6, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
