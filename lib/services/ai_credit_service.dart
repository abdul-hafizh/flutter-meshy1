import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';

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

/// One entry of the token ledger: a purchase (+), a generation that spent
/// tokens (-), or a balance adjustment. Purchases carry [orderId] so the app
/// can offer that purchase's invoice.
class TokenTransaction {
  final String id;
  final String type; // PURCHASE | USAGE | ADJUSTMENT
  final int amount;
  final int balanceAfter;
  final String description;
  final String? orderId;
  final DateTime? createdAt;

  const TokenTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.balanceAfter,
    required this.description,
    this.orderId,
    this.createdAt,
  });

  bool get isPurchase => type == 'PURCHASE';
  bool get isUsage => type == 'USAGE';

  factory TokenTransaction.fromJson(Map<String, dynamic> json) {
    int asInt(dynamic v) => v is int ? v : int.tryParse('$v') ?? 0;
    return TokenTransaction(
      id: json['id']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      amount: asInt(json['amount']),
      balanceAfter: asInt(json['balanceAfter']),
      description: json['description']?.toString() ?? '',
      orderId: json['orderId']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? '')?.toLocal(),
    );
  }
}

class TokenHistoryPage {
  final int balance;
  final List<TokenTransaction> items;
  final bool hasMore;

  const TokenHistoryPage({required this.balance, required this.items, required this.hasMore});
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

    final decoded = decodeApiResponse(res);
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

  /// The user's token ledger, newest first, [limit] entries per page.
  static Future<TokenHistoryPage> listHistory({required String token, int page = 1, int limit = 20}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/ai-credits/history?page=$page&limit=$limit'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = decodeApiResponse(res);
    final data = decoded['data'] as Map<String, dynamic>;
    final pagination = decoded['pagination'] as Map<String, dynamic>?;
    final totalPages = pagination?['totalPages'] is int ? pagination!['totalPages'] as int : 1;
    return TokenHistoryPage(
      balance: data['balance'] is int ? data['balance'] as int : int.tryParse('${data['balance']}') ?? 0,
      items: (data['items'] as List<dynamic>? ?? [])
          .map((e) => TokenTransaction.fromJson(e as Map<String, dynamic>))
          .toList(),
      hasMore: page < totalPages,
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

    final decoded = decodeApiResponse(res);
    final data = decoded['data'] as Map<String, dynamic>;
    return PaymentStatusResult(
      localStatus: data['localStatus']?.toString(),
      transactionStatus: data['transaction_status']?.toString(),
    );
  }
}
