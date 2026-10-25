import 'package:http/http.dart' as http;

import '../data/dummy_data.dart';
import 'api_client.dart';
import 'api_config.dart';

/// The admin's Master Tier (`GET /user-tiers`): label, minimum total spent
/// and discount of each loyalty tier, lowest first.
class TierService {
  TierService._();

  static Future<List<LoyaltyTier>> list({required String token}) async {
    http.Response res;
    try {
      res = await http.get(
        Uri.parse('${ApiConfig.baseUrl}/user-tiers'),
        headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      ).timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final rows = (decodeApiResponse(res)['data'] as List<dynamic>? ?? []).whereType<Map<String, dynamic>>().toList();
    num toNum(dynamic v) => v is num ? v : num.tryParse('$v') ?? 0;
    rows.sort((a, b) => toNum(a['MinSpent']).compareTo(toNum(b['MinSpent'])));
    return [
      for (var i = 0; i < rows.length; i++)
        LoyaltyTier.fromMaster(
          code: rows[i]['Code']?.toString() ?? '',
          label: rows[i]['Label']?.toString() ?? '',
          minSpent: toNum(rows[i]['MinSpent']),
          nextMinSpent: i + 1 < rows.length ? toNum(rows[i + 1]['MinSpent']) : null,
          discountPercent: toNum(rows[i]['DiscountPercent']),
        ),
    ];
  }
}
