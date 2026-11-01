import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_client.dart';
import 'api_config.dart';

/// What the "Ajukan Pengembalian" form offers (from the backend).
class ReturnOptions {
  final List<String> reasons;

  /// The reason that needs no photo ("Barang tidak diterima").
  final String? noPhotoReason;
  final int maxPhotos;
  final int windowDays;

  const ReturnOptions({required this.reasons, this.noPhotoReason, this.maxPhotos = 5, this.windowDays = 7});
}

/// A photo picked for a return request.
class ReturnPhoto {
  final Uint8List bytes;
  final String fileName;

  const ReturnPhoto({required this.bytes, required this.fileName});
}

/// Pengembalian (retur): the customer asks from the order detail; the store
/// approves or rejects it and Petope refunds (see api-meshy OrderReturnController).
class OrderReturnService {
  OrderReturnService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// The return's photo (needs the Bearer token).
  static String imageUrl(String returnId, String imageId) => '${ApiConfig.baseUrl}/order-returns/$returnId/images/$imageId';

  static Future<ReturnOptions> options({required String token}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/order-returns/reasons'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final data = decodeApiResponse(res)['data'] as Map<String, dynamic>? ?? {};
    return ReturnOptions(
      reasons: (data['Reasons'] as List<dynamic>? ?? []).map((e) => e.toString()).toList(),
      noPhotoReason: data['NoPhotoReason']?.toString(),
      maxPhotos: data['MaxPhotos'] is int ? data['MaxPhotos'] as int : 5,
      windowDays: data['WindowDays'] is int ? data['WindowDays'] as int : 7,
    );
  }

  static Future<String> submit({
    required String token,
    required String orderId,
    required String reason,
    required String description,
    List<ReturnPhoto> photos = const [],
  }) async {
    http.Response res;
    try {
      final request = http.MultipartRequest('POST', _uri('/orders/$orderId/return'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['Reason'] = reason
        ..fields['Description'] = description.trim();
      for (final p in photos) {
        final ext = p.fileName.toLowerCase().split('.').last;
        final subtype = ext == 'png' ? 'png' : (ext == 'webp' ? 'webp' : 'jpeg');
        request.files.add(http.MultipartFile.fromBytes('photos', p.bytes, filename: p.fileName, contentType: MediaType('image', subtype)));
      }
      final streamed = await request.send().timeout(const Duration(minutes: 2));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('Gagal mengirim pengajuan. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res, fallbackMessage: 'Gagal mengirim pengajuan pengembalian.');
    return decoded['message']?.toString() ?? 'Pengajuan pengembalian dikirim';
  }
}
