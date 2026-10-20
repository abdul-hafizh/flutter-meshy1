import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/cart.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'shipping_rate_service.dart';

/// Result of adding a product to the cart.
class CartAddResult {
  final String message;
  final int count;

  /// The cart line that was added/updated.
  final String? itemId;

  const CartAddResult({required this.message, required this.count, this.itemId});
}

/// The shopping cart for marketplace products and AI designs (`/cart` on api-meshy). Items
/// from several merchants check out together: one order per merchant, each
/// with its own delivery (courier or pick up), all paid on one DOKU page.
class CartService {
  CartService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    required String token,
    Object? body,
    String fallbackMessage = 'Terjadi kesalahan, coba lagi.',
    Duration timeout = const Duration(seconds: 30),
  }) async {
    http.Response res;
    try {
      final request = http.Request(method, _uri(path))..headers.addAll(_headers(token));
      if (body != null) request.body = jsonEncode(body);
      res = await http.Response.fromStream(await request.send().timeout(timeout));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    return decodeApiResponse(res, fallbackMessage: fallbackMessage);
  }

  static int _asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;

  static Future<List<CartGroup>> getCart({required String token}) async {
    final decoded = await _send('GET', '/cart', token: token, fallbackMessage: 'Gagal memuat keranjang.');
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    return (data['Groups'] as List<dynamic>? ?? [])
        .map((e) => CartGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<int> count({required String token}) async {
    final decoded = await _send('GET', '/cart/count', token: token);
    return _asInt((decoded['data'] as Map<String, dynamic>?)?['count']);
  }

  /// Adds a product to the cart. [replace] sets the line to exactly
  /// [quantity] instead of adding to what's already there ("Beli Sekarang").
  static Future<CartAddResult> add({
    required String token,
    required String productId,
    int quantity = 1,
    bool replace = false,
  }) async {
    final decoded = await _send(
      'POST',
      '/cart/items',
      token: token,
      body: {'ProductId': productId, 'Quantity': quantity, if (replace) 'Replace': true},
      fallbackMessage: 'Gagal menambahkan ke keranjang.',
    );
    final data = decoded['data'] as Map<String, dynamic>?;
    return CartAddResult(
      message: decoded['message']?.toString() ?? 'Ditambahkan ke keranjang',
      count: _asInt(data?['count']),
      itemId: data?['Id']?.toString(),
    );
  }

  /// Materials of the design's store with the design's price in each.
  static Future<DesignCartOptions> designOptions({required String token, required String aiModelId}) async {
    final decoded = await _send(
      'GET',
      '/cart/designs/options?AIModelId=${Uri.encodeQueryComponent(aiModelId)}',
      token: token,
      fallbackMessage: 'Gagal memuat pilihan material.',
    );
    return DesignCartOptions.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  /// Puts a finished design in the cart (or updates its material/quantity).
  static Future<CartAddResult> addDesign({
    required String token,
    required String aiModelId,
    required int materialId,
    int quantity = 1,
  }) async {
    final decoded = await _send(
      'POST',
      '/cart/designs',
      token: token,
      body: {'AIModelId': aiModelId, 'MaterialId': materialId, 'Quantity': quantity},
      fallbackMessage: 'Gagal memasukkan desain ke keranjang.',
    );
    return CartAddResult(
      message: decoded['message']?.toString() ?? 'Desain dimasukkan ke keranjang',
      count: _asInt((decoded['data'] as Map<String, dynamic>?)?['count']),
    );
  }

  static Future<void> updateQuantity({required String token, required String itemId, required int quantity}) async {
    await _send('PUT', '/cart/items/$itemId', token: token, body: {'Quantity': quantity});
  }

  static Future<void> remove({required String token, required String itemId}) async {
    await _send('DELETE', '/cart/items/$itemId', token: token);
  }

  /// Per-merchant price breakdown of the selected lines.
  static Future<List<CartCheckoutGroup>> preview({required String token, required List<String> cartItemIds}) async {
    final decoded = await _send(
      'POST',
      '/cart/preview',
      token: token,
      body: {'CartItemIds': cartItemIds},
      fallbackMessage: 'Gagal menyiapkan checkout.',
    );
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    return (data['Groups'] as List<dynamic>? ?? [])
        .map((e) => CartCheckoutGroup.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Live courier rates for one merchant's part of the selection.
  static Future<ShippingQuote> shippingRates({
    required String token,
    required List<String> cartItemIds,
    required String merchantId,
    required String userAddressId,
  }) async {
    final decoded = await _send(
      'POST',
      '/cart/shipping-rates',
      token: token,
      body: {'CartItemIds': cartItemIds, 'MerchantId': merchantId, 'UserAddressId': userAddressId},
      fallbackMessage: 'Gagal mengecek ongkos kirim, coba lagi.',
    );
    return ShippingRateService.parseQuote(decoded);
  }

  /// [shipping]: merchantId -> {IsPickup, CourierCompany, CourierType, ...}.
  static Future<CartCheckoutResult> checkout({
    required String token,
    required List<String> cartItemIds,
    required Map<String, Map<String, dynamic>> shipping,
    Map<String, String> notes = const {},
    String? userAddressId,
    int? paymentMethodId,
  }) async {
    final decoded = await _send(
      'POST',
      '/cart/checkout',
      token: token,
      body: {
        'CartItemIds': cartItemIds,
        'Shipping': shipping,
        'Notes': notes,
        'UserAddressId': ?userAddressId,
        'PaymentMethodId': ?paymentMethodId,
      },
      fallbackMessage: 'Gagal memproses checkout.',
      timeout: const Duration(seconds: 60),
    );
    final data = decoded['data'] as Map<String, dynamic>? ?? const {};
    final payment = data['Payment'] as Map<String, dynamic>?;
    return CartCheckoutResult(
      orderIds: (data['Orders'] as List<dynamic>? ?? [])
          .map((e) => (e as Map<String, dynamic>)['Id']?.toString() ?? '')
          .where((id) => id.isNotEmpty)
          .toList(),
      paymentId: payment?['paymentId']?.toString(),
      redirectUrl: payment?['redirectUrl']?.toString(),
      amount: payment == null ? null : _asInt(payment['amount']),
      paymentError: data['PaymentError']?.toString(),
    );
  }
}
