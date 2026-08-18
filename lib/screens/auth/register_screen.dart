import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_controller.dart';
import '../../services/google_auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/google_sign_in_entry.dart';
import '../../widgets/google_web_button.dart';
import '../../widgets/gradient_button.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String? _errorMessage;
  StreamSubscription<GoogleSignInAuthenticationEvent>? _googleEventsSub;

  @override
  void initState() {
    super.initState();
    // Web can't trigger Google sign-in from our own button, so the result
    // of Google's own rendered button arrives through this stream instead.
    if (kIsWeb) {
      _googleEventsSub = GoogleAuthService.authenticationEvents.listen(_handleWebGoogleEvent);
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _googleEventsSub?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorMessage = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final error = await auth.register(
      fullName: _fullNameController.text.trim(),
      email: _emailController.text.trim(),
      password: _passwordController.text,
      phone: _phoneController.text.trim(),
    );
    if (!mounted) return;

    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Registrasi berhasil! Silakan masuk.')),
    );
    Navigator.of(context).pop();
  }

  Future<void> _handleGoogle() async {
    final auth = context.read<AuthController>();
    if (auth.isSubmitting) return;
    setState(() => _errorMessage = null);
    final error = await auth.loginWithGoogle();
    _afterGoogleLogin(auth, error);
  }

  Future<void> _handleWebGoogleEvent(GoogleSignInAuthenticationEvent event) async {
    if (event is! GoogleSignInAuthenticationEventSignIn) return;
    final idToken = event.user.authentication.idToken;
    if (idToken == null) return;

    final auth = context.read<AuthController>();
    setState(() => _errorMessage = null);
    final error = await auth.loginWithGoogleIdToken(idToken);
    _afterGoogleLogin(auth, error);
  }

  void _afterGoogleLogin(AuthController auth, String? error) {
    if (!mounted) return;
    if (error != null) {
      setState(() => _errorMessage = error);
      return;
    }
    // Google sign-in (unlike email/password register) logs the user in
    // immediately, so pop back to let AuthGate swap in the main app.
    if (auth.status == AuthStatus.authenticated) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = context.watch<AuthController>().isSubmitting;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: const BackButton(color: AppColors.textPrimary),
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.shadowFor(AppColors.purple),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 30),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Buat akun baru',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Gabung dan mulai wujudkan idemu jadi 3D',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null) ...[
                  _ErrorBanner(message: _errorMessage!),
                  const SizedBox(height: 16),
                ],
                AppTextField(
                  controller: _fullNameController,
                  label: 'Nama Lengkap',
                  hint: 'Nama kamu',
                  icon: Icons.person_outline_rounded,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'Nama wajib diisi' : null,
                ),
                const SizedBox(height: 16),
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
                  controller: _phoneController,
                  label: 'No. Telepon',
                  hint: '08xxxxxxxxxx',
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                  validator: (v) => (v?.trim().isEmpty ?? true) ? 'No. telepon wajib diisi' : null,
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _passwordController,
                  label: 'Password',
                  hint: 'Minimal 6 karakter',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Password wajib diisi';
                    if ((v ?? '').length < 6) return 'Password minimal 6 karakter';
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                AppTextField(
                  controller: _confirmPasswordController,
                  label: 'Konfirmasi Password',
                  hint: 'Ulangi password',
                  icon: Icons.lock_outline_rounded,
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (v) {
                    if ((v ?? '').isEmpty) return 'Konfirmasi password wajib diisi';
                    if (v != _passwordController.text) return 'Password tidak sama';
                    return null;
                  },
                ),
                const SizedBox(height: 28),
                GradientButton(
                  label: isSubmitting ? 'Memproses...' : 'Daftar',
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
                GoogleSignInEntry(
                  label: 'Daftar dengan Google',
                  webText: GoogleWebButtonText.signUp,
                  onPressed: _handleGoogle,
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Sudah punya akun?', style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                    TextButton(
                      onPressed: isSubmitting ? null : () => Navigator.of(context).pop(),
                      child: const Text(
                        'Masuk',
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
