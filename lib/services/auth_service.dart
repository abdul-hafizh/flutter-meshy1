import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

class AuthResult {
  final String token;
  final AppUser user;

  const AuthResult({required this.token, required this.user});
}

class AuthService {
  AuthService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Backend messages are in English; translate the known ones so the UI
  /// stays consistently Indonesian, and fall back to the raw message
  /// (still better than nothing) for anything not in the map.
  static const Map<String, String> _messageTranslations = {
    'email already registered': 'Email sudah terdaftar. Gunakan email lain atau langsung masuk.',
    'invalid email or password': 'Email atau password salah.',
  };

  static String _friendlyMessage(String raw) {
    return _messageTranslations[raw.trim().toLowerCase()] ?? raw;
  }

  static Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri(path),
            headers: const {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respon server tidak valid.');
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && decoded['success'] == true) {
      return decoded;
    }
    throw ApiException(_friendlyMessage(decoded['message']?.toString() ?? 'Terjadi kesalahan, coba lagi.'));
  }

  static Future<AuthResult> login({required String email, required String password}) async {
    final decoded = await _post('/auth/login', {
      'Email': email,
      'Password': password,
    });
    final data = decoded['data'] as Map<String, dynamic>;
    return AuthResult(
      token: data['token'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  static Future<AuthResult> loginWithGoogle(String idToken) async {
    final decoded = await _post('/auth/google', {'idToken': idToken});
    final data = decoded['data'] as Map<String, dynamic>;
    return AuthResult(
      token: data['token'] as String,
      user: AppUser.fromJson(data['user'] as Map<String, dynamic>),
    );
  }

  static Future<AppUser> register({
    required String fullName,
    required String email,
    required String password,
    required String phone,
    int roleId = 3, // Customer
  }) async {
    final decoded = await _post('/auth/register', {
      'FullName': fullName,
      'Email': email,
      'Password': password,
      'Phone': phone,
      'RoleId': roleId,
    });
    return AppUser.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  /// Re-fetches the current user (including their up-to-date AI credit
  /// balance) — the cached [AppUser] is only ever refreshed at login/
  /// register time otherwise, so callers should use this after anything
  /// that can change server-side state (a token purchase, a generation).
  static Future<AppUser> fetchMe(String token) async {
    http.Response res;
    try {
      res = await http.get(
        _uri('/auth/me'),
        headers: {'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respon server tidak valid.');
    }

    if (res.statusCode >= 200 && res.statusCode < 300 && decoded['success'] == true) {
      return AppUser.fromJson(decoded['data'] as Map<String, dynamic>);
    }
    throw ApiException(_friendlyMessage(decoded['message']?.toString() ?? 'Terjadi kesalahan, coba lagi.'));
  }
}
