import 'package:flutter/material.dart';

import '../services/api_config.dart';

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

  const AiModel({
    required this.id,
    required this.modelName,
    required this.files,
    required this.previews,
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
    );
  }

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

  const AiJobDetail({
    required this.id,
    this.prompt,
    this.negativePrompt,
    required this.status,
    this.createdAt,
    this.finishedAt,
    required this.models,
    required this.logs,
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
    );
  }

  AiModel? get primaryModel => models.isEmpty ? null : models.first;
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

  const AiJobSummary({
    required this.id,
    required this.prompt,
    required this.createdAt,
    required this.status,
    this.progress,
    this.previewUrl,
    this.hasModel = false,
  });

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
    );
  }
}
