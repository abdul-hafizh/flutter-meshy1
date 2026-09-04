import 'package:http/http.dart' as http;

import '../models/tracking_event.dart';
import 'api_client.dart';
import 'api_config.dart';

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

  static Future<ShipmentTrackingResult> track({required String token, required String shipmentId}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/shipments/$shipmentId/track'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res, fallbackMessage: 'Gagal memuat tracking, coba lagi.');
    final data = decoded['data'] as Map<String, dynamic>;
    final history = (data['history'] as List<dynamic>? ?? []).map((e) => TrackingEvent.fromJson(e as Map<String, dynamic>)).toList();
    return ShipmentTrackingResult(status: data['status']?.toString() ?? 'PENDING', history: history);
  }
}
