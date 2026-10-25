import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';

/// A promo ad from the admin's Promosi menu, shown as a pop-up on the home screen.
class Promotion {
  final int id;
  final String title;
  final String imageUrl;
  final DateTime? endAt;

  const Promotion({required this.id, required this.title, required this.imageUrl, this.endAt});

  factory Promotion.fromJson(Map<String, dynamic> json) => Promotion(
        id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
        title: json['Title']?.toString() ?? '',
        imageUrl: ApiConfig.assetUrl(json['ImagePath']?.toString() ?? ''),
        endAt: DateTime.tryParse(json['EndAt']?.toString() ?? '')?.toLocal(),
      );
}

class PromotionService {
  PromotionService._();

  /// Promos running right now (`GET /promotions/active`), in display order.
  static Future<List<Promotion>> active({required String token}) async {
    http.Response res;
    try {
      res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/promotions/active'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final rows = decodeApiResponse(res)['data'] as List<dynamic>? ?? [];
    return rows
        .whereType<Map<String, dynamic>>()
        .map(Promotion.fromJson)
        .where((p) => p.imageUrl.isNotEmpty)
        .toList();
  }
}
