import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'api_client.dart';
import 'api_config.dart';

/// Ready-to-print files (STL/OBJ/3MF/STEP) a customer sends a store from the
/// chat. Uploaded to Petope's own server (`/print-files`), which also posts
/// the file card into the chat; the store then makes the order manually.
class PrintFileService {
  PrintFileService._();

  static const allowedExtensions = ['stl', 'obj', '3mf', 'step', 'stp'];
  static const maxBytes = 50 * 1024 * 1024;

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  /// Material names from the admin's price master (PLA, ABS, TPU, …).
  static Future<List<String>> materials({required String token}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/price-master/materials'), headers: {'Authorization': 'Bearer $token'})
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    return (decoded['data'] as List<dynamic>? ?? [])
        .map((e) => (e as Map<String, dynamic>)['Name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
  }

  static Future<String> send({
    required String token,
    required String merchantId,
    required Uint8List bytes,
    required String fileName,
    String? materialName,
    int quantity = 1,
    String? notes,
  }) async {
    http.Response res;
    try {
      final request = http.MultipartRequest('POST', _uri('/print-files'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['MerchantId'] = merchantId
        ..fields['Quantity'] = '$quantity'
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: fileName,
          contentType: MediaType('application', 'octet-stream'),
        ));
      if (materialName != null && materialName.isNotEmpty) request.fields['MaterialName'] = materialName;
      if (notes != null && notes.trim().isNotEmpty) request.fields['Notes'] = notes.trim();
      final streamed = await request.send().timeout(const Duration(minutes: 3));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('Gagal mengunggah file. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res, fallbackMessage: 'Gagal mengirim file cetak.');
    return decoded['message']?.toString() ?? 'File cetak terkirim ke toko';
  }

  static String sizeLabel(int bytes) {
    if (bytes >= 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1).replaceAll('.', ',')} MB';
    return '${(bytes / 1024).ceil()} KB';
  }
}
