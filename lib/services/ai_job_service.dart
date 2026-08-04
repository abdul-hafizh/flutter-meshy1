import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/ai_job.dart';
import 'api_config.dart';
import 'auth_service.dart' show ApiException;

class CreateJobResult {
  final String jobId;
  final String externalJobId;
  final String status;
  final num? remainingBalance;

  const CreateJobResult({
    required this.jobId,
    required this.externalJobId,
    required this.status,
    this.remainingBalance,
  });
}

class JobSyncResult {
  final String jobId;
  final String status;
  final int? progress;

  const JobSyncResult({required this.jobId, required this.status, this.progress});
}

/// Talks to the Meshy-backed text-to-3D endpoints. Every call requires the
/// logged-in user's bearer token.
class AiJobService {
  AiJobService._();

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

  static Future<CreateJobResult> createTextTo3D({
    required String token,
    required String prompt,
    String artStyle = 'realistic',
    String? negativePrompt,
  }) async {
    http.Response res;
    try {
      res = await http
          .post(
            _uri('/ai/jobs'),
            headers: _headers(token),
            body: jsonEncode({
              'prompt': prompt,
              'artStyle': artStyle,
              if (negativePrompt != null && negativePrompt.trim().isNotEmpty)
                'negativePrompt': negativePrompt.trim(),
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = _decode(res);
    final data = decoded['data'] as Map<String, dynamic>;
    return CreateJobResult(
      jobId: data['jobId'].toString(),
      externalJobId: data['externalJobId']?.toString() ?? '',
      status: data['status']?.toString() ?? AiJobStatus.pending,
      remainingBalance: data['remainingBalance'] is num ? data['remainingBalance'] as num : null,
    );
  }

  static Future<JobSyncResult> syncJobStatus({required String token, required String jobId}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/ai/jobs/$jobId/sync'), headers: _headers(token)).timeout(
            const Duration(seconds: 30),
          );
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = _decode(res);
    final data = decoded['data'] as Map<String, dynamic>;
    final progress = data['progress'];
    return JobSyncResult(
      jobId: data['localId']?.toString() ?? jobId,
      status: data['status']?.toString() ?? AiJobStatus.pending,
      progress: progress is int ? progress : int.tryParse('$progress'),
    );
  }

  static Future<List<AiJobSummary>> listMyJobs({required String token}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/ai/jobs'), headers: _headers(token)).timeout(
            const Duration(seconds: 30),
          );
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = _decode(res);
    final list = decoded['data'] as List<dynamic>? ?? [];
    return list.map((e) => AiJobSummary.fromJson(e as Map<String, dynamic>)).toList();
  }

  static Future<AiJobDetail> getJobDetail({required String token, required String jobId}) async {
    http.Response res;
    try {
      res = await http.get(_uri('/ai/jobs/$jobId'), headers: _headers(token)).timeout(
            const Duration(seconds: 30),
          );
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = _decode(res);
    return AiJobDetail.fromJson(decoded['data'] as Map<String, dynamic>);
  }
}
