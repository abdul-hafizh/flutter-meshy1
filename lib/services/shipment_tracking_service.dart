import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/tracking_event.dart';
import 'api_config.dart';
import 'auth_service.dart' show ApiException;

class ShipmentTrackingResult {
  final String status;
  final List<TrackingEvent> history;

  const ShipmentTrackingResult({required this.status, required this.history});
}

/// Pulls live courier tracking from Biteship for an already-booked shipment
/// (`GET /shipments/:id/track`) — only populated once payment is confirmed.
class ShipmentTrackingService {
  ShipmentTrackingService._();

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
    throw ApiException(decoded['message']?.toString() ?? 'Gagal memuat tracking, coba lagi.');
  }

  static Future<ShipmentTrackingResult> track({required String token, required String shipmentId}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/shipments/$shipmentId/track'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = _decode(res);
    final data = decoded['data'] as Map<String, dynamic>;
    final history = (data['history'] as List<dynamic>? ?? []).map((e) => TrackingEvent.fromJson(e as Map<String, dynamic>)).toList();
    return ShipmentTrackingResult(status: data['status']?.toString() ?? 'PENDING', history: history);
  }
}
