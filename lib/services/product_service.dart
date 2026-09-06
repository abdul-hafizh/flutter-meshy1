import 'package:http/http.dart' as http;

import '../models/product.dart';
import 'api_client.dart';
import 'api_config.dart';

/// Ready-made merchant products (`/api/products`, `/api/product-categories`)
/// — the "pick and checkout" catalog, distinct from `AiJobService`'s custom
/// prompt-to-3D flow.
class ProductService {
  ProductService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<List<Product>> listProducts({
    required String token,
    String? search,
    int? categoryId,
    bool? isPublished,
    int limit = 50,
  }) async {
    final query = <String, String>{'limit': '$limit'};
    if (search != null && search.trim().isNotEmpty) query['search'] = search.trim();
    if (categoryId != null) query['categoryId'] = '$categoryId';
    if (isPublished != null) query['isPublished'] = isPublished.toString();

    http.Response res;
    try {
      res = await http
          .get(_uri('/products').replace(queryParameters: query), headers: _headers(token))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => Product.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<Product> getById({required String token, required String productId}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/products/$productId'), headers: _headers(token)).timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    return Product.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  static Future<List<ProductCategoryOption>> listCategories({required String token}) async {
    http.Response res;
    try {
      res = await http
          .get(_uri('/product-categories').replace(queryParameters: {'limit': '100'}), headers: _headers(token))
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }
    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => ProductCategoryOption.fromJson(e as Map<String, dynamic>)).toList();
  }
}
