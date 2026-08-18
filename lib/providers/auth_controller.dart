import 'package:flutter/foundation.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/google_auth_service.dart';
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

  /// Runs the Google sign-in flow and logs in against the backend.
  /// Android/iOS/desktop only — web can't call `signIn()` imperatively,
  /// see [loginWithGoogleIdToken].
  /// Returns null on success or if the user cancelled, or an error
  /// message on failure.
  Future<String?> loginWithGoogle() async {
    isSubmitting = true;
    notifyListeners();
    try {
      final idToken = await GoogleAuthService.signIn();
      if (idToken == null) return null;
      return await _completeGoogleLogin(idToken);
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Terjadi kesalahan tak terduga. Coba lagi.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  /// Completes login given an ID token obtained elsewhere — used on web,
  /// where the ID token arrives via [GoogleAuthService.authenticationEvents]
  /// after the user interacts with Google's own rendered button, rather
  /// than through an explicit call to [GoogleAuthService.signIn].
  /// Returns null on success, or an error message on failure.
  Future<String?> loginWithGoogleIdToken(String idToken) async {
    isSubmitting = true;
    notifyListeners();
    try {
      return await _completeGoogleLogin(idToken);
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Terjadi kesalahan tak terduga. Coba lagi.';
    } finally {
      isSubmitting = false;
      notifyListeners();
    }
  }

  Future<String?> _completeGoogleLogin(String idToken) async {
    final result = await AuthService.loginWithGoogle(idToken);
    token = result.token;
    user = result.user;
    await SessionStore.save(result.token, result.user);
    status = AuthStatus.authenticated;
    return null;
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

  /// Re-fetches the current user (picks up a fresh AI credit balance after a
  /// purchase or generation). Silently no-ops on failure — the cached user
  /// just stays as-is, this is a best-effort refresh, not a critical path.
  Future<void> refreshUser() async {
    final currentToken = token;
    if (currentToken == null) return;
    try {
      final freshUser = await AuthService.fetchMe(currentToken);
      user = freshUser;
      await SessionStore.save(currentToken, freshUser);
      notifyListeners();
    } catch (_) {
      // Best-effort — keep the previously cached user.
    }
  }

  Future<void> logout() async {
    await SessionStore.clear();
    try {
      await GoogleAuthService.signOut();
    } catch (_) {
      // Best-effort: the session is already cleared locally either way.
    }
    token = null;
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
