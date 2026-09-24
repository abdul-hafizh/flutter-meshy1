import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/physical_order.dart';
import 'api_client.dart';
import 'api_config.dart';

/// One page of [OrderService.listMinePaged] — [hasMore] tells the caller
/// whether another page is worth fetching (page-based, driven by the
/// backend's own `pagination.totalPages`, not an item-count guess).
class PhysicalOrderPage {
  final List<PhysicalOrder> items;
  final bool hasMore;

  const PhysicalOrderPage({required this.items, required this.hasMore});
}

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

  /// Single-shot fetch of up to 100 orders, unfiltered — used where a bounded
  /// "just give me everything" list is fine (e.g. the order-sharing picker in
  /// chat). For the paginated Pesanan Saya list, use [listMinePaged] instead.
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

  /// Paginated orders, optionally scoped to one of the Pesanan Saya tabs
  /// ('unpaid' | 'packing' | 'shipped' | 'review' | 'history' — matches
  /// [OrderTab.name]). The backend computes tab membership itself (payment,
  /// shipment and rating state), so pagination stays correct instead of
  /// client-side filtering a fixed-size fetched list.
  static Future<PhysicalOrderPage> listMinePaged({
    required String token,
    String? tab,
    int page = 1,
    int limit = 10,
  }) async {
    final query = {'page': '$page', 'limit': '$limit', if (tab != null) 'tab': tab};
    http.Response res;
    try {
      res = await http
          .get(_uri('/orders').replace(queryParameters: query), headers: _headers(token))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    final pagination = decoded['pagination'] as Map<String, dynamic>?;
    final totalPages = pagination?['totalPages'] is int ? pagination!['totalPages'] as int : 1;
    return PhysicalOrderPage(
      items: list.map((e) => PhysicalOrder.fromJson(e as Map<String, dynamic>)).toList(),
      hasMore: page < totalPages,
    );
  }

  /// Per-tab badge counts (unpaid/packing/shipped/review/history), computed
  /// server-side so they stay correct beyond the first page of orders.
  static Future<Map<OrderTab, int>> counts({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/orders/counts'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final data = decodeApiResponse(res)['data'] as Map<String, dynamic>? ?? {};
    int n(String k) => data[k] is int ? data[k] as int : int.tryParse('${data[k]}') ?? 0;
    return {
      OrderTab.unpaid: n('unpaid'),
      OrderTab.packing: n('packing'),
      OrderTab.shipped: n('shipped'),
      OrderTab.review: n('review'),
      OrderTab.history: n('history'),
    };
  }

  /// Cancels an unpaid order (the backend refuses once it's been paid).
  static Future<void> cancel({required String token, required String orderId, String? reason}) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/orders/$orderId/cancel'),
            headers: _headers(token),
            body: jsonEncode({if (reason != null && reason.trim().isNotEmpty) 'Reason': reason.trim()}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    decodeApiResponse(res);
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
    int? shippingMethodId,
    int? shippingServiceId,
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
              if (shippingMethodId != null) 'ShippingMethodId': shippingMethodId,
              if (shippingServiceId != null) 'ShippingServiceId': shippingServiceId,
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

  /// Pick Up checkout — customer collects the order at the merchant's store.
  /// No address, no courier, no shipping cost; skips Biteship entirely (see
  /// checkoutOrder's IsPickup branch on the backend).
  static Future<PhysicalOrder> checkoutPickup({
    required String token,
    required String orderId,
    String? notes,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/orders/$orderId/checkout'),
            headers: _headers(token),
            body: jsonEncode({
              'IsPickup': true,
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

  /// Customer-initiated "Pesanan Diterima" — marks the order Completed and
  /// stamps the shipment's DeliveredAt, unlocking the rating form. Distinct
  /// from the merchant/system-driven status transitions elsewhere in the
  /// order lifecycle (checkout, payment, tracking).
  static Future<PhysicalOrder> confirmReceipt({
    required String token,
    required String orderId,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(_uri('/orders/$orderId/confirm-receipt'), headers: _headers(token))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    return PhysicalOrder.fromJson(decoded['data'] as Map<String, dynamic>);
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
