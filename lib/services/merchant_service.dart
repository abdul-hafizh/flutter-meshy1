import 'package:http/http.dart' as http;

import '../models/nearby_merchant.dart';
import 'api_client.dart';
import 'api_config.dart';

/// The real "nearest merchant" endpoint (`/api/merchants/nearby`) — distinct
/// from `ChatService.listMerchants`, which is just a flat, unordered list
/// with no location detail.
class MerchantService {
  MerchantService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// [cityId] should be the customer's default saved-address city, when
  /// they have one — the backend uses it to rank same-city merchants
  /// closer; omit it and every merchant still comes back, just unranked by
  /// real distance.
  static Future<List<NearbyMerchant>> listNearby({required String token, int? cityId}) async {
    final query = <String, String>{};
    if (cityId != null) query['userCityId'] = '$cityId';

    http.Response res;
    try {
      res = await http
          .get(_uri('/merchants/nearby').replace(queryParameters: query.isEmpty ? null : query), headers: _headers(token))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => NearbyMerchant.fromJson(e as Map<String, dynamic>)).toList();
  }
}
