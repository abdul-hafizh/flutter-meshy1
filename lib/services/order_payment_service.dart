import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';

class OrderPaymentResult {
  final String paymentId;
  final String paymentNumber;
  final String token;
  final String redirectUrl;
  final int amount;

  const OrderPaymentResult({
    required this.paymentId,
    required this.paymentNumber,
    required this.token,
    required this.redirectUrl,
    required this.amount,
  });
}

/// Generates the Midtrans Snap transaction for an already-checked-out
/// physical order. Status polling reuses `AiCreditService.checkStatus` —
/// `GET /payments/:id/midtrans-status` is generic to any [Payment], nothing
/// AI-credit-specific about it despite that class's name.
class OrderPaymentService {
  OrderPaymentService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<OrderPaymentResult> createSnapToken({
    required String token,
    required String orderId,
    int? paymentMethodId,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/payments/snap-token'),
            headers: _headers(token),
            body: jsonEncode({
              'OrderId': orderId,
              if (paymentMethodId != null) 'PaymentMethodId': paymentMethodId,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final data = decoded['data'] as Map<String, dynamic>;
    return OrderPaymentResult(
      paymentId: data['paymentId']?.toString() ?? '',
      paymentNumber: data['paymentNumber']?.toString() ?? '',
      token: data['token']?.toString() ?? '',
      redirectUrl: data['redirectUrl']?.toString() ?? '',
      amount: data['amount'] is int ? data['amount'] as int : int.tryParse('${data['amount']}') ?? 0,
    );
  }
}
