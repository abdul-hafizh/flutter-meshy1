import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/payment_method.dart';
import 'api_config.dart';
import 'auth_service.dart' show ApiException;

class PaymentMethodService {
  PaymentMethodService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Map<String, dynamic> _decode(http.Response res) {
    Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Respon server tidak valid.');
    }
    if (res.statusCode >= 200 && res.statusCode < 300 && decoded['success'] == true) {
      return decoded;
    }
    throw ApiException(decoded['message']?.toString() ?? 'Terjadi kesalahan, coba lagi.');
  }

  /// Only `Provider == 'Midtrans'` methods are returned — the "Manual
  /// Transfer" rows have no proof-of-payment/verification flow implemented
  /// anywhere in the backend, so surfacing them would be a dead end.
  static Future<List<PaymentMethodOption>> listMidtransMethods({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/payment-methods?limit=100'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = _decode(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => PaymentMethodOption.fromJson(e as Map<String, dynamic>))
        .where((m) => m.provider == 'Midtrans')
        .toList();
  }
}
