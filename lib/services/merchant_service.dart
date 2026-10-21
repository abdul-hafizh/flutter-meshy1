import 'package:http/http.dart' as http;

import '../models/merchant_queue_status.dart';
import '../models/nearby_merchant.dart';
import '../models/user_address.dart';
import 'api_client.dart';
import 'api_config.dart';
import 'user_address_service.dart';

/// The real "nearest merchant" endpoint (`/api/merchants/nearby`) — distinct
/// from `ChatService.listMerchants`, which is just a flat, unordered list
/// with no location detail.
class NearbyStoresResult {
  final List<NearbyMerchant> stores;

  /// The "toko terdekat" radius the backend applied (null = none).
  final double? radiusKm;

  const NearbyStoresResult({required this.stores, this.radiusKm});
}

class MerchantService {
  MerchantService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  /// Stores sorted by real distance from [latitude]/[longitude] (the
  /// customer's delivery address pin), same city next. With [nearbyOnly]
  /// only stores within the admin's radius come back — empty means there's
  /// no store near that address.
  static Future<List<NearbyMerchant>> listNearby({
    required String token,
    int? cityId,
    double? latitude,
    double? longitude,
    bool nearbyOnly = false,
  }) async {
    return (await listNearbyResult(
      token: token,
      cityId: cityId,
      latitude: latitude,
      longitude: longitude,
      nearbyOnly: nearbyOnly,
    ))
        .stores;
  }

  static Future<NearbyStoresResult> listNearbyResult({
    required String token,
    int? cityId,
    double? latitude,
    double? longitude,
    bool nearbyOnly = false,
  }) async {
    final query = <String, String>{};
    if (cityId != null) query['userCityId'] = '$cityId';
    if (latitude != null && longitude != null) {
      query['latitude'] = '$latitude';
      query['longitude'] = '$longitude';
    }
    if (nearbyOnly) query['nearbyOnly'] = '1';

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
    final meta = decoded['meta'] is Map<String, dynamic> ? decoded['meta'] as Map<String, dynamic> : const {};
    return NearbyStoresResult(
      stores: list.map((e) => NearbyMerchant.fromJson(e as Map<String, dynamic>)).toList(),
      radiusKm: meta['radiusKm'] is num ? (meta['radiusKm'] as num).toDouble() : null,
    );
  }

  /// Every store, closest to [address] (the active delivery address) first;
  /// without one, the customer's default saved address is used.
  static Future<List<NearbyMerchant>> listNearbyForMe({required String token, UserAddress? address}) async {
    var a = address;
    if (a == null) {
      try {
        final addresses = await UserAddressService.listMine(token: token);
        if (addresses.isNotEmpty) a = addresses.firstWhere((x) => x.isDefault, orElse: () => addresses.first);
      } catch (_) {
        // No saved address yet — every store still comes back, just unranked.
      }
    }
    return listNearby(token: token, cityId: a?.cityId, latitude: a?.latitude, longitude: a?.longitude);
  }

  /// One store as the store list shows it (photo, city, rating, grams sold).
  static Future<NearbyMerchant> summary({required String token, required String merchantId}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/merchants/$merchantId/summary'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    return NearbyMerchant.fromJson(decoded['data'] as Map<String, dynamic>? ?? const {});
  }

  /// How busy one merchant's print queue is — shown before ordering from
  /// them (e.g. on a product page). Counts only, never who is queued.
  static Future<MerchantQueueStatus> queueStatus({required String token, required String merchantId}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/merchants/$merchantId/queue-status'), headers: _headers(token))
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    return MerchantQueueStatus.fromJson(decoded['data'] as Map<String, dynamic>? ?? const {});
  }
}
