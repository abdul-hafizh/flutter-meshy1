import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/user_address.dart';
import 'api_config.dart';
import 'auth_service.dart' show ApiException;

/// CRUD for the logged-in user's saved addresses (`/api/user-addresses`).
/// Setting `IsDefault: true` on create/update auto-clears any other default
/// address server-side — no separate "set default" endpoint exists.
class UserAddressService {
  UserAddressService._();

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
    throw ApiException(decoded['message']?.toString() ?? 'Terjadi kesalahan, coba lagi.');
  }

  static Future<List<UserAddress>> listMine({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/user-addresses?limit=100'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = _decode(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => UserAddress.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Map<String, dynamic> _body({
    String? label,
    String? recipientName,
    String? phone,
    String? whatsappNumber,
    String? address,
    int? countryId,
    int? provinceId,
    int? cityId,
    String? postalCode,
    bool? isDefault,
  }) {
    return {
      if (label != null) 'Label': label,
      if (recipientName != null) 'RecipientName': recipientName,
      if (phone != null) 'Phone': phone,
      if (whatsappNumber != null) 'WhatsappNumber': whatsappNumber,
      if (address != null) 'Address': address,
      if (countryId != null) 'CountryId': countryId,
      if (provinceId != null) 'ProvinceId': provinceId,
      if (cityId != null) 'CityId': cityId,
      if (postalCode != null) 'PostalCode': postalCode,
      if (isDefault != null) 'IsDefault': isDefault,
    };
  }

  static Future<UserAddress> create({
    required String token,
    required String label,
    String? recipientName,
    String? phone,
    String? whatsappNumber,
    required String address,
    int? countryId,
    int? provinceId,
    int? cityId,
    String? postalCode,
    bool isDefault = false,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/user-addresses'),
            headers: _headers(token),
            body: jsonEncode(_body(
              label: label,
              recipientName: recipientName,
              phone: phone,
              whatsappNumber: whatsappNumber,
              address: address,
              countryId: countryId,
              provinceId: provinceId,
              cityId: cityId,
              postalCode: postalCode,
              isDefault: isDefault,
            )),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = _decode(res);
    return UserAddress.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  static Future<UserAddress> update({
    required String token,
    required String id,
    String? label,
    String? recipientName,
    String? phone,
    String? whatsappNumber,
    String? address,
    int? countryId,
    int? provinceId,
    int? cityId,
    String? postalCode,
    bool? isDefault,
  }) async {
    http.Response res;
    try {
      res = await http
          .put(
            _uri('/user-addresses/$id'),
            headers: _headers(token),
            body: jsonEncode(_body(
              label: label,
              recipientName: recipientName,
              phone: phone,
              whatsappNumber: whatsappNumber,
              address: address,
              countryId: countryId,
              provinceId: provinceId,
              cityId: cityId,
              postalCode: postalCode,
              isDefault: isDefault,
            )),
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = _decode(res);
    return UserAddress.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  static Future<void> setDefault({required String token, required String id}) async {
    await update(token: token, id: id, isDefault: true);
  }

  static Future<void> delete({required String token, required String id}) async {
    http.Response res;
    try {
      res = await http.delete(_uri('/user-addresses/$id'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    _decode(res);
  }
}
