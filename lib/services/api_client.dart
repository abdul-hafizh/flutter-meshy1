import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class ApiException implements Exception {
  final String message;
  ApiException(this.message);

  @override
  String toString() => message;
}

/// Global hook so the (static, context-free) HTTP services can react to an
/// expired or invalid JWT by kicking the user back to the login screen.
/// [AuthController] is the only thing that registers a listener, once, at
/// app startup — services never need a `BuildContext` to trigger it.
class SessionExpiry {
  SessionExpiry._();

  static VoidCallback? _onExpired;

  static void register(VoidCallback onExpired) => _onExpired = onExpired;

  static void notify() => _onExpired?.call();
}

/// Decodes the `{success, message, data}` envelope shared by every
/// api-meshy endpoint. A 401 response (missing/invalid/expired token) also
/// fires [SessionExpiry], so any authenticated call failing that way logs
/// the app out automatically instead of leaving the screen stuck.
Map<String, dynamic> decodeApiResponse(
  http.Response res, {
  String fallbackMessage = 'Terjadi kesalahan, coba lagi.',
}) {
  Map<String, dynamic> decoded;
  try {
    decoded = jsonDecode(res.body) as Map<String, dynamic>;
  } catch (_) {
    throw ApiException('Respon server tidak valid.');
  }

  if (res.statusCode >= 200 && res.statusCode < 300 && decoded['success'] == true) {
    return decoded;
  }

  if (res.statusCode == 401) {
    SessionExpiry.notify();
  }

  throw ApiException(decoded['message']?.toString() ?? fallbackMessage);
}
