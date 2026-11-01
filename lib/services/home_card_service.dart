import 'package:http/http.dart' as http;

import 'api_client.dart';
import 'api_config.dart';

/// One "Mau pesan apa hari ini?" card, set by the admin in Master Kategori Produk.
class HomeCard {
  /// MARKET (Produk Jadi), PROMPT (halaman prompt) or PRINT_FILE (kirim file ke toko).
  final String action;
  final String title;
  final String description;

  /// Preset icon key (see StartOptions), or null.
  final String? icon;

  /// Uploaded icon image (asset path), used instead of [icon] when set.
  final String? iconImage;
  final String? colorStart;
  final String? colorEnd;

  const HomeCard({
    required this.action,
    required this.title,
    required this.description,
    this.icon,
    this.iconImage,
    this.colorStart,
    this.colorEnd,
  });

  factory HomeCard.fromJson(Map<String, dynamic> json) {
    String? opt(String key) {
      final v = json[key]?.toString().trim();
      return v == null || v.isEmpty ? null : v;
    }

    return HomeCard(
      action: json['Action']?.toString().toUpperCase() ?? '',
      title: json['Title']?.toString() ?? '',
      description: json['Description']?.toString() ?? '',
      icon: opt('Icon'),
      iconImage: opt('IconImage'),
      colorStart: opt('ColorStart'),
      colorEnd: opt('ColorEnd'),
    );
  }
}

class HomeCardService {
  HomeCardService._();

  static Future<List<HomeCard>> list({required String token}) async {
    final res = await http
        .get(Uri.parse('${ApiConfig.baseUrl}/product-categories/home'), headers: {'Authorization': 'Bearer $token'})
        .timeout(const Duration(seconds: 15));
    final data = decodeApiResponse(res)['data'] as List<dynamic>? ?? [];
    return data.whereType<Map<String, dynamic>>().map(HomeCard.fromJson).toList();
  }
}
