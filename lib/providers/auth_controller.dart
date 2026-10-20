import 'dart:async';

import 'package:flutter/widgets.dart';

import '../models/app_user.dart';
import '../services/api_client.dart';
import '../services/auth_service.dart';
import 'package:google_sign_in/google_sign_in.dart' show GoogleSignInException;

import '../services/google_auth_service.dart';
import '../services/session_store.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier with WidgetsBindingObserver {
  AuthController() {
    // Services have no BuildContext to reach this controller, so they
    // report an expired/invalid JWT (HTTP 401) through this global hook
    // instead — see ApiClient.decodeApiResponse.
    SessionExpiry.register(_handleSessionExpired);
    WidgetsBinding.instance.addObserver(this);
  }

  /// The login token lasts 90 days and is renewed whenever the app is
  /// opened or brought back to the foreground (at most every few hours),
  /// so users stay signed in as long as they use the app now and then.
  static const _renewEvery = Duration(hours: 6);
  DateTime? _lastRenewal;
  bool _renewing = false;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? token;
  bool isSubmitting = false;

  void _handleSessionExpired() {
    if (status != AuthStatus.authenticated) return;
    unawaited(logout());
  }

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
    if (status == AuthStatus.authenticated) unawaited(_renewSession(force: true));
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_renewSession());
  }

  /// Best-effort: offline or server hiccups keep the current token; only a
  /// 401 (token expired/revoked, account blocked) ends the session.
  Future<void> _renewSession({bool force = false}) async {
    final current = token;
    if (current == null || status != AuthStatus.authenticated || _renewing) return;
    final last = _lastRenewal;
    if (!force && last != null && DateTime.now().difference(last) < _renewEvery) return;
    _renewing = true;
    try {
      final fresh = await AuthService.refreshSession(current);
      // Logged out (or switched account) while the request was in flight.
      if (token != current || user == null) return;
      token = fresh;
      _lastRenewal = DateTime.now();
      await SessionStore.save(fresh, user!);
    } catch (_) {
      // Keep the current token; a real 401 already triggered logout.
    } finally {
      _renewing = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
      _lastRenewal = DateTime.now();
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
    } on GoogleSignInException catch (e) {
      return GoogleAuthService.describeError(e);
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
    _lastRenewal = DateTime.now();
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
  /// Updates the logged-in user's own profile and refreshes the cached
  /// [user]. Returns null on success, or an error message on failure.
  Future<String?> updateProfile({
    String? fullName,
    String? phone,
    String? whatsappNumber,
    String? gender,
    String? birthDate,
  }) async {
    final currentToken = token;
    if (currentToken == null) return 'Sesi berakhir, silakan masuk kembali.';
    isSubmitting = true;
    notifyListeners();
    try {
      final updated = await AuthService.updateProfile(
        token: currentToken,
        fullName: fullName,
        phone: phone,
        whatsappNumber: whatsappNumber,
        gender: gender,
        birthDate: birthDate,
      );
      user = updated;
      await SessionStore.save(currentToken, updated);
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

  /// Uploads a new profile photo. Returns null on success, or an error message.
  Future<String?> uploadAvatar(List<int> bytes, String filename) async {
    final currentToken = token;
    if (currentToken == null) return 'Sesi berakhir, silakan masuk kembali.';
    try {
      final updated = await AuthService.uploadAvatar(token: currentToken, bytes: bytes, filename: filename);
      user = updated;
      await SessionStore.save(currentToken, updated);
      notifyListeners();
      return null;
    } on ApiException catch (e) {
      return e.message;
    } catch (_) {
      return 'Gagal mengunggah foto profil.';
    }
  }

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
