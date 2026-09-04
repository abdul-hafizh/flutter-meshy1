import 'package:http/http.dart' as http;

import '../models/region.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Country/Province/City lookups for cascading address dropdowns.
class LocationService {
  LocationService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<CountryRef>> listCountries({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/countries?limit=250'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => CountryRef.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<ProvinceRef>> listProvinces({required String token, int? countryId}) async {
    http.Response res;
    try {
      final query = countryId != null ? '?countryId=$countryId&limit=250' : '?limit=250';
      res = await http.get(_uri('/provinces$query'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => ProvinceRef.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<List<CityRef>> listCities({required String token, int? provinceId}) async {
    http.Response res;
    try {
      final query = provinceId != null ? '?provinceId=$provinceId&limit=500' : '?limit=500';
      res = await http.get(_uri('/cities$query'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => CityRef.fromJson(e as Map<String, dynamic>)).toList();
  }
}
