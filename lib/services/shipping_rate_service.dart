import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shipping_rate.dart';
import 'api_config.dart';
import 'auth_service.dart' show ApiException;

/// Live "cek ongkir" quote from Biteship for a candidate destination
/// address, called at checkout before the customer commits to a courier.
class ShippingRateService {
  ShippingRateService._();

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
    throw ApiException(decoded['message']?.toString() ?? 'Gagal mengecek ongkos kirim, coba lagi.');
  }

  static Future<List<ShippingRateOption>> checkRates({
    required String token,
    required String orderId,
    required String userAddressId,
    required int packageWeightGrams,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/orders/$orderId/shipping-rates'),
            headers: _headers(token),
            body: jsonEncode({
              'UserAddressId': userAddressId,
              'PackageWeight': packageWeightGrams,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = _decode(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => ShippingRateOption.fromJson(e as Map<String, dynamic>)).toList();
  }
}
