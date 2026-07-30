import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/session_store.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? token;
  bool isSubmitting = false;

  Future<void> bootstrap() async {
    final storedToken = await SessionStore.readToken();
    final storedUser = await SessionStore.readUser();
    if (storedToken != null && storedUser != null) {
      token = storedToken;
      user = storedUser;
      status = AuthStatus.authenticated;
    } else {
      status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> login({required String email, required String password}) async {
    isSubmitting = true;
    notifyListeners();
    try {
      final result = await AuthService.login(email: email, password: password);
      token = result.token;
      user = result.user;
      await SessionStore.save(result.token, result.user);
      status = AuthStatus.authenticated;
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Terjadi kesalahan tak terduga. Coba lagi.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  /// Returns null on success, or an error message on failure.
  Future<String?> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
  }) async {
    isSubmitting = true;
    notifyListeners();
    try {
      await AuthService.register(
        fullName: fullName,
        email: email,
        password: password,
        phone: phone,
      );
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Terjadi kesalahan tak terduga. Coba lagi.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    await SessionStore.clear();
    token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
