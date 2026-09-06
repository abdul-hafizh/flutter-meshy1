import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/physical_order.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Physical 3D-print orders (`/api/orders`) — distinct from AI-generation
/// jobs (`AiJobService`). The backend already scopes `GET /orders` to the
/// logged-in customer's own orders.
class OrderService {
  OrderService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<PhysicalOrder>> listMine({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/orders?limit=100'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => PhysicalOrder.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<PhysicalOrder> getById({required String token, required String orderId}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/orders/$orderId'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    return PhysicalOrder.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  /// Buys a ready-made product directly — skips the prompt/chat flow
  /// entirely, returning an order that's already priced and ready for
  /// [CheckoutScreen].
  static Future<PhysicalOrder> createFromProduct({
    required String token,
    required String productId,
    int quantity = 1,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/orders/from-product'),
            headers: _headers(token),
            body: jsonEncode({'ProductId': productId, 'Quantity': quantity}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    return PhysicalOrder.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  static Future<PhysicalOrder> checkout({
    required String token,
    required String orderId,
    required String userAddressId,
    required String courierCompany,
    required String courierType,
    String? courierServiceName,
    required int packageWeightGrams,
    required int shippingCost,
    String? notes,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/orders/$orderId/checkout'),
            headers: _headers(token),
            body: jsonEncode({
              'UserAddressId': userAddressId,
              'CourierCompany': courierCompany,
              'CourierType': courierType,
              if (courierServiceName != null) 'CourierServiceName': courierServiceName,
              'PackageWeight': packageWeightGrams,
              'ShippingCost': shippingCost,
              if (notes != null && notes.trim().isNotEmpty) 'Notes': notes.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final data = decoded['data'] as Map<String, dynamic>;
    return PhysicalOrder.fromJson(data['order'] as Map<String, dynamic>);
  }

  static Future<void> rate({
    required String token,
    required String orderId,
    required int rating,
    String? ratingNotes,
  }) async {
    http.Response res;
    try {
      res = await http
          .put(
            _uri('/orders/$orderId/rate'),
            headers: _headers(token),
            body: jsonEncode({
              'Rating': rating,
              if (ratingNotes != null && ratingNotes.trim().isNotEmpty) 'RatingNotes': ratingNotes.trim(),
            }),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    decodeApiResponse(res);
  }
}
