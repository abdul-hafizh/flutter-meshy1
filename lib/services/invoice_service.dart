import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';
import 'api_config.dart';

/// Opens an order's invoice PDF in the system browser, which handles the
/// download. The app's login token never goes into a URL: the backend hands
/// out a short-lived, invoice-only token (`POST /orders/:id/invoice-link`)
/// that is valid for that one order's PDF and nothing else.
///
/// Works for both physical orders and AI-token purchases (both are rows in
/// the backend's Orders table); the backend decides who may see which.
class InvoiceService {
  InvoiceService._();

  static Future<void> open({required String token, required String orderId}) async {
    http.Response res;
    try {
      res = await http
          .post(
            Uri.parse('${ApiConfig.baseUrl}/orders/$orderId/invoice-link'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
          )
          .timeout(const Duration(seconds: 15));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final data = decodeApiResponse(res, fallbackMessage: 'Gagal menyiapkan invoice.')['data'] as Map<String, dynamic>;
    final path = data['path']?.toString();
    final linkToken = data['token']?.toString();
    if (path == null || linkToken == null) {
      throw ApiException('Respon server tidak valid.');
    }

    final uri = Uri.parse('${ApiConfig.baseUrl}$path').replace(queryParameters: {'token': linkToken});
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched) {
      throw ApiException('Tidak dapat membuka invoice. Coba lagi.');
    }
  }
}
