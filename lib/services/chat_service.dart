import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/merchant.dart';
import 'api_client.dart';
import 'api_config.dart';

class StreamTokenResult {
  final String apiKey;
  final String token;
  final String userId;
  final String userType;
  final String? fullName;
  final String? avatar;

  const StreamTokenResult({
    required this.apiKey,
    required this.token,
    required this.userId,
    required this.userType,
    this.fullName,
    this.avatar,
  });

  factory StreamTokenResult.fromJson(Map<String, dynamic> json) {
    return StreamTokenResult(
      apiKey: json['apiKey']?.toString() ?? '',
      token: json['token']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      userType: json['userType']?.toString() ?? 'CUSTOMER',
      fullName: json['fullName']?.toString(),
      avatar: json['avatar']?.toString(),
    );
  }
}

class ChatChannelInfo {
  final String channelId;
  final String channelType;

  const ChatChannelInfo({required this.channelId, required this.channelType});

  factory ChatChannelInfo.fromJson(Map<String, dynamic> json) {
    return ChatChannelInfo(
      channelId: json['channelId']?.toString() ?? '',
      channelType: json['channelType']?.toString() ?? 'messaging',
    );
  }
}

/// Talks to the api-meshy GetStream chat endpoints. Every call requires the
/// logged-in user's bearer token.
class ChatService {
  ChatService._();

  static Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  static Map<String, String> _headers(String token) => {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      };

  static Future<StreamTokenResult> fetchToken({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/chat/token'), headers: _headers(token)).timeout(
            const Duration(seconds: 30),
          );
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = decodeApiResponse(res);
    return StreamTokenResult.fromJson(decoded['data'] as Map<String, dynamic>);
  }

  static Future<List<Merchant>> listMerchants({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/chat/merchants'), headers: _headers(token)).timeout(
            const Duration(seconds: 30),
          );
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = decodeApiResponse(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => Merchant.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<ChatChannelInfo> createOrGetChannel({
    required String token,
    required String merchantId,
    String? jobId,
    String? previewUrl,
    String? prompt,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/chat/channel'),
            headers: _headers(token),
            body: jsonEncode({
              'merchantId': merchantId,
              'jobId': jobId,
              'previewUrl': previewUrl,
              'prompt': prompt,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = decodeApiResponse(res);
    return ChatChannelInfo.fromJson(decoded['data'] as Map<String, dynamic>);
  }
}
