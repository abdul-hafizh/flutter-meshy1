import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/google_auth_button.dart';
import '../../widgets/gradient_button.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final error = await auth.login(
      email: _emailController.text.trim(),
      password: _passwordController.text,
    );
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
    }
  }

  void _goToRegister() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const RegisterScreen()),
    );
  }

  void _googleComingSoon() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Masuk dengan Google akan segera hadir')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.watch<AuthController>().isSubmitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowFor(AppColors.purple),
                          blurRadius: 24,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.view_in_ar_rounded, color: Colors.white, size: 34),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'Selamat datang kembali',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Masuk untuk lanjut berkarya di Snapy AI 3D',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 28),
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  controller: _emailController,
                  label: 'Email',
                  hint: 'nama@email.com',
                  icon: Icons.mail_outline_rounded,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    final value = v?.trim() ?? '';
                    if (value.isEmpty) return 'Email wajib diisi';
                    if (!value.contains('@') || !value.contains('.')) return 'Format email tidak valid';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Masukkan password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Password wajib diisi';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: isSubmitting ? 'Memproses...' : 'Masuk',
                  icon: isSubmitting ? null : Icons.arrow_forward_rounded,
                  onPressed: isSubmitting ? null : _submit,
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.border)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('atau', style: TextStyle(fontSize: 12.5, color: AppColors.textFaint)),
                    ),
                    const Expanded(child: Divider(color: AppColors.border)),
                  ],
                ),
                const SizedBox(height: 16),
                GoogleAuthButton(label: 'Masuk dengan Google', onPressed: _googleComingSoon),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Belum punya akun?', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: isSubmitting ? null : _goToRegister,
                      child: const Text(
                        'Daftar',
                        style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.orange),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE0453A).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0453A).withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: Color(0xFFE0453A)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 13, color: Color(0xFFE0453A), fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
