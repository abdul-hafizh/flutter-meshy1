import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/shipping_catalog.dart';
import '../models/shipping_rate.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Result of a "cek ongkir" call: the courier options plus the package
/// weight they were quoted for (decided by the merchant, not the customer).
class ShippingQuote {
  final List<ShippingRateOption> rates;

  /// Grams used for the quote.
  final int? packageWeightGrams;

  /// "MERCHANT" (set on the order), "PRODUCT" (product weight × qty) or
  /// "DEFAULT" (merchant hasn't specified one — a standard estimate).
  final String? packageWeightSource;

  /// Instant couriers (Gojek/Grab) are only quoted when both the customer's
  /// and the merchant's address have map coordinates.
  final bool destinationHasCoordinates;
  final bool originHasCoordinates;

  const ShippingQuote({
    required this.rates,
    this.packageWeightGrams,
    this.packageWeightSource,
    this.destinationHasCoordinates = true,
    this.originHasCoordinates = true,
  });
}

/// Live "cek ongkir" quote from Biteship for a candidate destination
/// address, called at checkout before the customer commits to a courier.
class ShippingRateService {
  ShippingRateService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<ShippingQuote> checkRates({
    required String token,
    required String orderId,
    required String userAddressId,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/orders/$orderId/shipping-rates'),
            headers: _headers(token),
            body: jsonEncode({'UserAddressId': userAddressId}),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res, fallbackMessage: 'Gagal mengecek ongkos kirim, coba lagi.');
    final list = decoded['data'] as List<dynamic>? ?? [];
    final weight = decoded['packageWeight'] is Map<String, dynamic> ? decoded['packageWeight'] as Map<String, dynamic> : null;
    final instant =
        decoded['instantAvailability'] is Map<String, dynamic> ? decoded['instantAvailability'] as Map<String, dynamic> : null;
    return ShippingQuote(
      rates: list.map((e) => ShippingRateOption.fromJson(e as Map<String, dynamic>)).toList(),
      packageWeightGrams: weight?['grams'] is num ? (weight!['grams'] as num).round() : null,
      packageWeightSource: weight?['source']?.toString(),
      destinationHasCoordinates: instant?['destinationHasCoordinates'] != false,
      originHasCoordinates: instant?['originHasCoordinates'] != false,
    );
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
