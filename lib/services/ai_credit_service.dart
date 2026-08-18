import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_service.dart' show ApiException;

class TokenPurchaseResult {
  final String orderId;
  final String paymentId;
  final String paymentNumber;
  final String redirectUrl;
  final int amount;
  final int quantity;

  const TokenPurchaseResult({
    required this.orderId,
    required this.paymentId,
    required this.paymentNumber,
    required this.redirectUrl,
    required this.amount,
    required this.quantity,
  });
}

class PaymentStatusResult {
  final String? localStatus;
  final String? transactionStatus;

  const PaymentStatusResult({this.localStatus, this.transactionStatus});

  bool get isPaid => localStatus == 'PAID';
  bool get isFailed => const {'CANCELLED', 'EXPIRED', 'FAILED'}.contains(localStatus);
}

/// AI-credit ("token") purchases via Midtrans. Every call requires the
/// logged-in user's bearer token — same explicit-token pattern as
/// [AiJobService].
class AiCreditService {
  AiCreditService._();

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

  static Future<TokenPurchaseResult> purchase({
    required String token,
    required int quantity,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/ai-credits/purchase'),
            headers: _headers(token),
            body: jsonEncode({'Quantity': quantity}),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = _decode(res);
    final data = decoded['data'] as Map<String, dynamic>;
    return TokenPurchaseResult(
      orderId: data['orderId']?.toString() ?? '',
      paymentId: data['paymentId']?.toString() ?? '',
      paymentNumber: data['paymentNumber']?.toString() ?? '',
      redirectUrl: data['redirectUrl']?.toString() ?? '',
      amount: data['amount'] is int ? data['amount'] as int : int.tryParse('${data['amount']}') ?? 0,
      quantity: data['quantity'] is int ? data['quantity'] as int : int.tryParse('${data['quantity']}') ?? quantity,
    );
  }

  /// Polling this also drives crediting on the backend (see
  /// `GET /payments/:id/midtrans-status`) — calling it is what makes the
  /// balance update even without a public webhook reachable from Midtrans.
  static Future<PaymentStatusResult> checkStatus({
    required String token,
    required String paymentId,
  }) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/payments/$paymentId/midtrans-status'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = _decode(res);
    final data = decoded['data'] as Map<String, dynamic>;
    return PaymentStatusResult(
      localStatus: data['localStatus']?.toString(),
      transactionStatus: data['transaction_status']?.toString(),
    );
  }
}
