import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/ai_job.dart';
import '../providers/auth_controller.dart';
import '../services/ai_job_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../theme/app_theme.dart';

/// Renders inline inside the Pesanan tab (not pushed as its own route) so
/// the app's bottom navigation bar stays visible while viewing a job.
class JobDetailView extends StatefulWidget {
  final String jobId;
  final String? promptFallback;
  final VoidCallback onBack;

  const JobDetailView({
    super.key,
    required this.jobId,
    required this.onBack,
    this.promptFallback,
  });

  @override
  State<JobDetailView> createState() => _JobDetailViewState();
}

class _JobDetailViewState extends State<JobDetailView> {
  bool _loading = true;
  bool _syncing = false;
  String? _error;
  AiJobDetail? _detail;

  @override
  void initState() {
    super.initState();
    _load();
  }

  String? get _token => context.read<AuthController>().token;

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final detail = await AiJobService.getJobDetail(token: token, jobId: widget.jobId);
      if (!mounted) return;
      setState(() => _detail = detail);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat detail pesanan.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sync() async {
    final token = _token;
    if (token == null) return;
    setState(() => _syncing = true);
    try {
      await AiJobService.syncJobStatus(token: token, jobId: widget.jobId);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memperbarui status. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _openFile(String? url) async {
    if (url == null) return;
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 12, 4),
          child: Row(
            children: [
              IconButton(
                onPressed: widget.onBack,
                icon: const Icon(Icons.arrow_back_rounded, color: AppColors.textPrimary),
              ),
              const Expanded(
                child: Text(
                  'Detail Pesanan',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Cek status',
                onPressed: _syncing ? null : _sync,
                icon: _syncing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : detail == null
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    detail.prompt?.isNotEmpty == true
                                        ? detail.prompt!
                                        : widget.promptFallback ?? 'Tanpa deskripsi',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                _StatusPill(status: detail.status),
                              ],
                            ),
                            if (detail.negativePrompt?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Dihindari: ${detail.negativePrompt}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ],
                            const SizedBox(height: 20),
                            _ModelPreview(status: detail.status, model: detail.primaryModel),
                            if (detail.primaryModel != null) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Unduh Model',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  for (final entry in {
                                    'GLB': detail.primaryModel!.glbUrl,
                                    'STL': detail.primaryModel!.stlUrl,
                                    'OBJ': detail.primaryModel!.objUrl,
                                    'FBX': detail.primaryModel!.fbxUrl,
                                    'USDZ': detail.primaryModel!.usdzUrl,
                                  }.entries)
                                    if (entry.value != null)
                                      _FileChip(label: entry.key, onTap: () => _openFile(entry.value)),
                                ],
                              ),
                            ],
                          ],
                        ),
        ),
      ],
    );
  }
}

class _ModelPreview extends StatelessWidget {
  final String status;
  final AiModel? model;

  const _ModelPreview({required this.status, required this.model});

  @override
  Widget build(BuildContext context) {
    final finished = status.isJobFinished;
    final succeeded = status.toUpperCase() == AiJobStatus.succeeded;
    final viewerSrc = model?.glbViewerSrc;

    if (succeeded && viewerSrc != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 320,
          color: AppColors.surfaceMuted,
          child: ModelViewer(
            key: ValueKey(viewerSrc),
            src: viewerSrc,
            alt: 'Hasil model 3D',
            autoRotate: true,
            cameraControls: true,
            backgroundColor: AppColors.surfaceMuted,
            exposure: 0.75,
            shadowIntensity: 1,
            shadowSoftness: 1,
          ),
        ),
      );
    }

    return Container(
      height: 220,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            status.toUpperCase() == AiJobStatus.failed
                ? Icons.error_outline_rounded
                : Icons.hourglass_top_rounded,
            size: 34,
            color: status.statusColor,
          ),
          const SizedBox(height: 10),
          Text(
            finished ? 'Model gagal dibuat' : 'AI sedang membuat model 3D-mu...',
            style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final String status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = status.statusColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.statusIcon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(status.statusLabel, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }
}

class _FileChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _FileChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.download_rounded, size: 16, color: AppColors.purple),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textFaint),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            OutlinedButton(onPressed: onRetry, child: const Text('Coba lagi')),
          ],
        ),
      ),
    );
  }
}
