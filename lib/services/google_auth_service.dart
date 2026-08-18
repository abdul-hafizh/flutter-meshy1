import 'package:google_sign_in/google_sign_in.dart';

/// Thin wrapper around `google_sign_in` that hands back the Google ID
/// token our backend verifies at `POST /auth/google`.
///
/// Android/iOS/desktop drive the flow imperatively via [signIn]. Web
/// doesn't support that — Google requires its own rendered button there
/// — so web screens render that button directly and listen to
/// [authenticationEvents] for the resulting account instead.
class GoogleAuthService {
  GoogleAuthService._();

  /// Web OAuth client from the backend's GOOGLE_CLIENT_ID — this is the
  /// audience the backend checks the ID token against, so it must match
  /// exactly (see e:\Proyek\api-meshy\.env).
  static const String _serverClientId =
      '256366208789-ljmm8hj3qlge449bvausg3ka1upak9oe.apps.googleusercontent.com';

  static final GoogleSignIn _instance = GoogleSignIn.instance;
  static Future<void>? _initFuture;

  /// Safe to call repeatedly/concurrently — initialization only runs once.
  static Future<void> ensureInitialized() {
    return _initFuture ??= _instance.initialize(serverClientId: _serverClientId);
  }

  /// Fires whenever the web-rendered button (or a lightweight-auth
  /// attempt) completes a sign-in/sign-out. Unused on Android/iOS.
  static Stream<GoogleSignInAuthenticationEvent> get authenticationEvents {
    return _instance.authenticationEvents;
  }

  /// Runs the sign-in flow and returns the Google ID token, or `null` if
  /// the user cancelled it. Throws [GoogleSignInException] for anything
  /// else (missing Play Services, misconfigured OAuth client, etc.).
  static Future<String?> signIn() async {
    await ensureInitialized();
    if (!_instance.supportsAuthenticate()) {
      throw StateError('Masuk dengan Google belum didukung di platform ini.');
    }
    try {
      final account = await _instance.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  static Future<void> signOut() async {
    await ensureInitialized();
    await _instance.signOut();
  }
}
