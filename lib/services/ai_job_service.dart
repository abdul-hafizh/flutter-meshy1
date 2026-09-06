import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';

import '../models/ai_job.dart';
import 'api_client.dart';
import 'api_config.dart';

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

class ImageUpload {
  final List<int> bytes;
  final String filename;
  final String? mimeType;

  const ImageUpload({required this.bytes, required this.filename, this.mimeType});
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

  static Future<CreateJobResult> createTextTo3D({
    required String token,
    required String prompt,
    String artStyle = 'realistic',
    String? negativePrompt,
    double? length,
    double? width,
    double? height,
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
              if (length != null) 'TargetLength': length,
              if (width != null) 'TargetWidth': width,
              if (height != null) 'TargetHeight': height,
            }),
          )
          .timeout(const Duration(seconds: 30));
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = decodeApiResponse(res);
    final data = decoded['data'] as Map<String, dynamic>;
    return CreateJobResult(
      jobId: data['jobId'].toString(),
      externalJobId: data['externalJobId']?.toString() ?? '',
      status: data['status']?.toString() ?? AiJobStatus.pending,
      remainingBalance: data['remainingBalance'] is num ? data['remainingBalance'] as num : null,
    );
  }

  /// Up to 4 reference photos of the same object from different angles —
  /// Meshy's Multi-Image to 3D endpoint accepts 1-4 images and produces a
  /// single, more complete model than a single photo can.
  static Future<CreateJobResult> createImageTo3D({
    required String token,
    required List<ImageUpload> images,
    String? prompt,
    String artStyle = 'realistic',
    String? negativePrompt,
    double? length,
    double? width,
    double? height,
  }) async {
    assert(images.isNotEmpty && images.length <= 4);
    http.Response res;
    try {
      final request = http.MultipartRequest('POST', _uri('/ai/jobs'))
        ..headers['Authorization'] = 'Bearer $token'
        ..fields['artStyle'] = artStyle;

      for (final image in images) {
        // multer's fileFilter checks the multipart part's Content-Type, so
        // without this it defaults to application/octet-stream and the
        // backend rejects it with "Hanya file gambar yang diizinkan!".
        final resolvedMimeType =
            image.mimeType ?? lookupMimeType(image.filename) ?? 'image/jpeg';
        request.files.add(http.MultipartFile.fromBytes(
          'images',
          image.bytes,
          filename: image.filename,
          contentType: MediaType.parse(resolvedMimeType),
        ));
      }

      if (prompt != null && prompt.trim().isNotEmpty) {
        request.fields['prompt'] = prompt.trim();
      }
      if (negativePrompt != null && negativePrompt.trim().isNotEmpty) {
        request.fields['negativePrompt'] = negativePrompt.trim();
      }
      if (length != null) request.fields['TargetLength'] = '$length';
      if (width != null) request.fields['TargetWidth'] = '$width';
      if (height != null) request.fields['TargetHeight'] = '$height';

      final streamed = await request.send().timeout(const Duration(seconds: 60));
      res = await http.Response.fromStream(streamed);
    } catch (_) {
      throw ApiException('Tidak dapat terhubung ke server. Periksa koneksi kamu.');
    }

    final decoded = decodeApiResponse(res);
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

    final decoded = decodeApiResponse(res);
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

    final decoded = decodeApiResponse(res);
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

    final decoded = decodeApiResponse(res);
    return AiJobDetail.fromJson(decoded['data'] as Map<String, dynamic>);
  }
}
