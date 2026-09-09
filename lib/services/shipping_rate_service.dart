import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shipping_catalog.dart';
import '../models/shipping_rate.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Live "cek ongkir" quote from Biteship for a candidate destination
/// address, called at checkout before the customer commits to a courier.
class ShippingRateService {
  ShippingRateService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

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
    final decoded = decodeApiResponse(res, fallbackMessage: 'Gagal mengecek ongkos kirim, coba lagi.');
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => ShippingRateOption.fromJson(e as Map<String, dynamic>)).toList();
  }

  /// The shipping-category catalog (Instant/Regular/Cargo/International,
  /// each with its registered couriers) — used to group live rates by
  /// category in the checkout picker, independent of Biteship's pricing.
  static Future<List<ShippingMethodCategory>> listCatalog({required String token}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/shipping-methods').replace(queryParameters: {'limit': '100', 'isActive': 'true'}), headers: _headers(token))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => ShippingMethodCategory.fromJson(e as Map<String, dynamic>)).toList();
  }
}
