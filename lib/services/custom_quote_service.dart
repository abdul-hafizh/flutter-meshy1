import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';

/// A store's penawaran harga (Pesanan Custom), live from the server.
/// [status]: SENT (waiting for the customer) · ACCEPTED (in the cart) ·
/// REJECTED · ORDERED · CANCELLED. [revision] grows each time the store
/// changes and re-sends it.
class CustomQuote {
  final String id;
  final String quoteNumber;
  final String status;
  final String statusLabel;
  final int revision;
  final String? rejectReason;
  final String? orderId;
  final int payableAmount;

  const CustomQuote({
    required this.id,
    required this.quoteNumber,
    required this.status,
    required this.statusLabel,
    required this.revision,
    this.rejectReason,
    this.orderId,
    this.payableAmount = 0,
  });

  factory CustomQuote.fromJson(Map<String, dynamic> json) {
    final pricing = json['Pricing'] is Map<String, dynamic> ? json['Pricing'] as Map<String, dynamic> : const {};
    int asInt(dynamic v) => v is int ? v : (v is num ? v.round() : int.tryParse('$v') ?? 0);
    return CustomQuote(
      id: json['Id']?.toString() ?? '',
      quoteNumber: json['QuoteNumber']?.toString() ?? '',
      status: json['Status']?.toString().toUpperCase() ?? 'SENT',
      statusLabel: json['StatusLabel']?.toString() ?? '',
      revision: asInt(json['Revision']),
      rejectReason: json['RejectReason']?.toString(),
      orderId: json['OrderId']?.toString(),
      payableAmount: asInt(pricing['PayableAmount']),
    );
  }
}

class CustomQuoteService {
  CustomQuoteService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');
  static Map<String, String> _headers(String token) => {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'};

  static Future<CustomQuote> get({required String token, required String quoteId}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/custom-quotes/$quoteId'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    return CustomQuote.fromJson(decodeApiResponse(res)['data'] as Map<String, dynamic>);
  }

  /// Agrees to the [revision] shown → the penawaran goes into the cart.
  static Future<String> accept({required String token, required String quoteId, required int revision}) =>
      _answer(token, quoteId, 'accept', {'Revision': revision});

  static Future<String> reject({required String token, required String quoteId, required int revision, String? reason}) =>
      _answer(token, quoteId, 'reject', {'Revision': revision, if (reason != null && reason.trim().isNotEmpty) 'Reason': reason.trim()});

  static Future<String> _answer(String token, String quoteId, String action, Map<String, dynamic> body) async {
    http.Response res;
    try {
      res = await http
          .post(_uri('/custom-quotes/$quoteId/$action'), headers: _headers(token), body: jsonEncode(body))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    return decodeApiResponse(res)['message']?.toString() ?? 'Berhasil';
  }
}
