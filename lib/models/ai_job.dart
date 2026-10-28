import 'package:flutter/material.dart';

import '../services/api_config.dart';
import 'operating_status.dart';

class AiJobStatus {
  static const pending = 'PENDING';
  static const inProgress = 'IN_PROGRESS';
  static const succeeded = 'SUCCEEDED';
  static const failed = 'FAILED';
}

extension AiJobStatusX on String {
  String get statusLabel => switch (toUpperCase()) {
        AiJobStatus.pending => 'Menunggu',
        AiJobStatus.inProgress => 'Diproses',
        AiJobStatus.succeeded => 'Selesai',
        AiJobStatus.failed => 'Gagal',
        _ => this,
      };

  IconData get statusIcon => switch (toUpperCase()) {
        AiJobStatus.succeeded => Icons.check_circle_outline_rounded,
        AiJobStatus.failed => Icons.error_outline_rounded,
        _ => Icons.view_in_ar_rounded,
      };

  Color get statusColor => switch (toUpperCase()) {
        AiJobStatus.succeeded => const Color(0xFF2FB380),
        AiJobStatus.failed => const Color(0xFFE0453A),
        _ => const Color(0xFFFF7A18),
      };

  bool get isJobFinished =>
      toUpperCase() == AiJobStatus.succeeded || toUpperCase() == AiJobStatus.failed;
}

double? _toDouble(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? ''}');

/// "± 12,5 gram" / "± 1,7 kg" — the backend's estimate (AIModel.Weight), null when unknown.
String? formatGramEstimate(double? grams) {
  if (grams == null || grams <= 0) return null;
  if (grams >= 1000) return '± ${_oneDecimal(grams / 1000)} kg';
  final rounded = grams >= 10 ? grams.round().toString() : _oneDecimal(grams);
  return '± $rounded gram';
}

/// 14.5 → "14,5", 20.0 → "20".
String _oneDecimal(double v) {
  final r = (v * 10).round() / 10;
  return r == r.roundToDouble() ? r.toInt().toString() : r.toStringAsFixed(1).replaceAll('.', ',');
}

/// "20 × 14,5 × 16,5 cm" (panjang × lebar × tinggi) from millimetres, null when unknown.
String? formatPrintSize(double? lengthMm, double? widthMm, double? heightMm) {
  final dims = [lengthMm, widthMm, heightMm];
  if (dims.any((d) => d == null || d <= 0)) return null;
  return '${dims.map((d) => _oneDecimal(d! / 10)).join(' × ')} cm';
}

class AiModelFile {
  final String id;
  final String fileType;
  final String filePath;

  const AiModelFile({required this.id, required this.fileType, required this.filePath});

  factory AiModelFile.fromJson(Map<String, dynamic> json) {
    return AiModelFile(
      id: json['Id']?.toString() ?? '',
      fileType: json['FileType']?.toString().toUpperCase() ?? '',
      filePath: json['FilePath']?.toString() ?? '',
    );
  }
}

/// A file type the customer may download for this design — the admin's
/// active list (dashboard › Aktivitas Meshy) that this model is available in.
class ModelDownloadFormat {
  final String code;
  final String label;
  final String? description;

  const ModelDownloadFormat({required this.code, required this.label, this.description});

  factory ModelDownloadFormat.fromJson(Map<String, dynamic> json) {
    final code = json['Code']?.toString().toUpperCase() ?? '';
    final label = json['Label']?.toString() ?? '';
    return ModelDownloadFormat(
      code: code,
      label: label.isEmpty ? code : label,
      description: json['Description']?.toString(),
    );
  }
}

class AiModelPreview {
  final String id;
  final String previewPath;

  const AiModelPreview({required this.id, required this.previewPath});

  factory AiModelPreview.fromJson(Map<String, dynamic> json) {
    return AiModelPreview(
      id: json['Id']?.toString() ?? '',
      previewPath: json['PreviewPath']?.toString() ?? '',
    );
  }
}

class AiModel {
  final String id;
  final String modelName;
  final List<AiModelFile> files;
  final List<AiModelPreview> previews;
  final double? weightGrams;
  final double? width;
  final double? height;
  final double? depth;

  const AiModel({
    required this.id,
    required this.modelName,
    required this.files,
    required this.previews,
    this.weightGrams,
    this.width,
    this.height,
    this.depth,
  });

  factory AiModel.fromJson(Map<String, dynamic> json) {
    return AiModel(
      id: json['Id']?.toString() ?? '',
      modelName: json['ModelName']?.toString() ?? '',
      files: (json['Files'] as List<dynamic>? ?? [])
          .map((e) => AiModelFile.fromJson(e as Map<String, dynamic>))
          .toList(),
      previews: (json['Previews'] as List<dynamic>? ?? [])
          .map((e) => AiModelPreview.fromJson(e as Map<String, dynamic>))
          .toList(),
      weightGrams: _toDouble(json['Weight']),
      width: _toDouble(json['Width']),
      height: _toDouble(json['Height']),
      depth: _toDouble(json['Depth']),
    );
  }

  String? get weightLabel => formatGramEstimate(weightGrams);

  /// Size after the backend's proportional autoscale (Depth = panjang).
  String? get sizeLabel => formatPrintSize(depth, width, height);

  String? get previewUrl => previews.isEmpty ? null : previews.first.previewPath;

  String? _fileUrl(String type) {
    for (final f in files) {
      if (f.fileType == type) return f.filePath;
    }
    return null;
  }

  String? get glbUrl => _fileUrl('GLB');
  String? get stlUrl => _fileUrl('STL');
  String? get objUrl => _fileUrl('OBJ');
  String? get fbxUrl => _fileUrl('FBX');
  String? get usdzUrl => _fileUrl('USDZ');

  /// Meshy's CDN doesn't send CORS headers, so the web `model-viewer`
  /// component can't fetch the GLB straight from assets.meshy.ai in a
  /// browser. Route it through our own API instead, which proxies the file
  /// with CORS allowed.
  String? get glbViewerSrc {
    for (final f in files) {
      if (f.fileType == 'GLB') return '${ApiConfig.baseUrl}/ai/jobs/files/${f.id}';
    }
    return null;
  }
}

class AiJobLog {
  final String id;
  final String logType;
  final String message;
  final DateTime? createdAt;

  const AiJobLog({required this.id, required this.logType, required this.message, this.createdAt});

  factory AiJobLog.fromJson(Map<String, dynamic> json) {
    return AiJobLog(
      id: json['Id']?.toString() ?? '',
      logType: json['LogType']?.toString() ?? '',
      message: json['Message']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? ''),
    );
  }
}

/// The merchant already picked for a job's model, if any — once set, the
/// customer can no longer pick a different merchant for this job (enforced
/// server-side in ChatService.ensureOrderForModel).
class AssignedMerchantInfo {
  final String id;
  final String fullName;
  final String? avatar;
  final String? cityName;
  final String? provinceName;
  final String? countryName;
  final double? rating;
  final int totalReviews;
  final OperatingStatus? operatingStatus;

  const AssignedMerchantInfo({
    required this.id,
    required this.fullName,
    this.avatar,
    this.cityName,
    this.provinceName,
    this.countryName,
    this.rating,
    this.totalReviews = 0,
    this.operatingStatus,
  });

  factory AssignedMerchantInfo.fromJson(Map<String, dynamic> json) {
    final company = json['Company'];
    final city = company is Map<String, dynamic> ? company['City'] : null;
    final province = company is Map<String, dynamic> ? company['Province'] : null;
    final country = company is Map<String, dynamic> ? company['Country'] : null;
    return AssignedMerchantInfo(
      id: json['Id']?.toString() ?? '',
      fullName: json['FullName']?.toString() ?? 'Merchant',
      avatar: ApiConfig.assetUrlOrNull(json['Avatar']?.toString()),
      cityName: city is Map<String, dynamic> ? city['Name']?.toString() : null,
      provinceName: province is Map<String, dynamic> ? province['Name']?.toString() : null,
      countryName: country is Map<String, dynamic> ? country['Name']?.toString() : null,
      rating: json['Rating'] is num ? (json['Rating'] as num).toDouble() : null,
      totalReviews: json['TotalReviews'] is int
          ? json['TotalReviews'] as int
          : int.tryParse('${json['TotalReviews']}') ?? 0,
      operatingStatus: OperatingStatus.tryParse(json['OperatingStatus']),
    );
  }

  /// "Kota, Provinsi, Negara" — falls back gracefully when the merchant's
  /// Company profile is incomplete.
  String get locationLine {
    final parts = [
      if (cityName != null && cityName!.isNotEmpty) cityName,
      if (provinceName != null && provinceName!.isNotEmpty) provinceName,
      if (countryName != null && countryName!.isNotEmpty) countryName,
    ];
    return parts.isEmpty ? '-' : parts.join(', ');
  }

  bool get hasRating => rating != null && totalReviews > 0;
}

/// Full job detail returned by GET /ai/jobs/:id.
class AiJobDetail {
  final String id;
  final String? prompt;
  final String? negativePrompt;
  final String status;
  final DateTime? createdAt;
  final DateTime? finishedAt;
  final List<AiModel> models;
  final List<AiJobLog> logs;
  final AssignedMerchantInfo? assignedMerchant;
  final String? assignedOrderId;

  /// Store chosen on the prompt screen (new flow) — the finished design is
  /// added to the cart for this store instead of picking a merchant here.
  final AssignedMerchantInfo? store;

  /// The design's cart line, when it's already in the cart.
  final String? cartItemId;

  /// File types offered under "Unduh Model".
  final List<ModelDownloadFormat> downloadFormats;

  /// Customer chose Multicolor (3MF) rather than Satu warna (STL).
  final bool isMulticolor;

  /// Filament pulled from the spool, incl. colour-change purge and prime tower.
  final double? totalFilamentGrams;

  /// Multicolour job that ended without Meshy's multi-colour 3MF — its 3MF is single-colour.
  final bool multiColorFallback;

  const AiJobDetail({
    required this.id,
    this.prompt,
    this.negativePrompt,
    required this.status,
    this.createdAt,
    this.finishedAt,
    required this.models,
    required this.logs,
    this.assignedMerchant,
    this.assignedOrderId,
    this.store,
    this.cartItemId,
    this.downloadFormats = const [],
    this.isMulticolor = false,
    this.totalFilamentGrams,
    this.multiColorFallback = false,
  });

  factory AiJobDetail.fromJson(Map<String, dynamic> json) {
    return AiJobDetail(
      id: json['Id']?.toString() ?? '',
      prompt: json['Prompt']?.toString(),
      negativePrompt: json['NegativePrompt']?.toString(),
      status: json['Status']?.toString() ?? AiJobStatus.pending,
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? ''),
      finishedAt: DateTime.tryParse(json['FinishedAt']?.toString() ?? ''),
      models: (json['Models'] as List<dynamic>? ?? [])
          .map((e) => AiModel.fromJson(e as Map<String, dynamic>))
          .toList(),
      logs: (json['Logs'] as List<dynamic>? ?? [])
          .map((e) => AiJobLog.fromJson(e as Map<String, dynamic>))
          .toList(),
      assignedMerchant: json['AssignedMerchant'] is Map<String, dynamic>
          ? AssignedMerchantInfo.fromJson(json['AssignedMerchant'] as Map<String, dynamic>)
          : null,
      assignedOrderId: json['AssignedOrderId']?.toString(),
      store: json['Store'] is Map<String, dynamic>
          ? AssignedMerchantInfo.fromJson(json['Store'] as Map<String, dynamic>)
          : null,
      cartItemId: json['CartItemId']?.toString(),
      downloadFormats: (json['DownloadFormats'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ModelDownloadFormat.fromJson)
          .where((f) => f.code.isNotEmpty)
          .toList(),
      isMulticolor: json['ColorPreference']?.toString().toUpperCase() == 'MULTI',
      totalFilamentGrams: _toDouble(json['TotalFilamentNeededGrams']),
      multiColorFallback: json['MultiColorFallback'] == true,
    );
  }

  /// New flow: a store was picked before generating, and no order was made
  /// the old way (merchant picked after generating) — so the design goes
  /// through the cart.
  bool get usesCart => store != null && assignedMerchant == null;

  bool get canAddToCart => usesCart && status == AiJobStatus.succeeded && primaryModel != null;

  AiModel? get primaryModel => models.isEmpty ? null : models.first;

  /// True when Stage 1 (mesh) finished but the automatic Stage 2 (color &
  /// texture refine) that normally follows it failed to even start — the
  /// job is done (`Status: SUCCEEDED`) but stuck as a colorless preview
  /// forever unless someone manually retries via `POST /ai/jobs/:id/refine`.
  ///
  /// There's no separate "stage 2 succeeded" flag from the backend — both a
  /// clean completion and a stuck one report the same overall `SUCCEEDED`
  /// status, so this looks at the most recent "Stage 2" log entry instead:
  /// if the latest one says the refine failed to start, nothing since has
  /// superseded it.
  bool get isStuckWithoutRefine {
    if (status != AiJobStatus.succeeded) return false;
    final stage2Logs = logs.where((l) => l.message.contains('Stage 2')).toList()
      ..sort((a, b) => (a.createdAt ?? DateTime(0)).compareTo(b.createdAt ?? DateTime(0)));
    if (stage2Logs.isEmpty) return false;
    return stage2Logs.last.message.contains('creation failed');
  }
}

/// One row from GET /ai/jobs — the authenticated user's job history.
class AiJobSummary {
  final String id;
  final String prompt;
  final DateTime createdAt;
  final String status;
  final int? progress;
  final String? previewUrl;
  final bool hasModel;
  final double? weightGrams;

  const AiJobSummary({
    required this.id,
    required this.prompt,
    required this.createdAt,
    required this.status,
    this.progress,
    this.previewUrl,
    this.hasModel = false,
    this.weightGrams,
  });

  String? get weightLabel => formatGramEstimate(weightGrams);

  factory AiJobSummary.fromJson(Map<String, dynamic> json) {
    final progress = json['Progress'];
    return AiJobSummary(
      id: json['Id']?.toString() ?? '',
      prompt: json['Prompt']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['CreatedAt']?.toString() ?? '') ?? DateTime.now(),
      status: json['Status']?.toString() ?? AiJobStatus.pending,
      progress: progress is int ? progress : int.tryParse('$progress'),
      previewUrl: json['PreviewUrl']?.toString(),
      hasModel: json['HasModel'] == true,
      weightGrams: _toDouble(json['Weight']),
    );
  }
}
