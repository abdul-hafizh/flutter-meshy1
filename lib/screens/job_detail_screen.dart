import 'dart:async';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart' show Channel;
import 'package:url_launcher/url_launcher.dart';

import '../models/ai_job.dart';
import '../models/nearby_merchant.dart';
import '../providers/active_address_controller.dart';
import '../providers/auth_controller.dart';
import '../providers/chat_controller.dart';
import '../services/ai_job_service.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/chat_service.dart';
import '../services/merchant_service.dart';
import '../services/order_link_service.dart';
import '../services/order_service.dart';
import '../services/location_gate.dart';
import '../theme/app_theme.dart';
import '../widgets/design_cart_sheet.dart';
import '../widgets/gradient_button.dart';
import '../widgets/store_status.dart';
import '../widgets/merchant_queue_badge.dart';
import 'chat/chat_screen.dart';

/// Caps a title at [maxLength] characters, appending "..." when it's longer
/// — long AI prompts otherwise push the status pill off the header row.
String _truncateTitle(String text, [int maxLength = 30]) {
  if (text.length <= maxLength) return text;
  return '${text.substring(0, maxLength)}...';
}

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
  bool _refining = false;
  String? _error;
  AiJobDetail? _detail;

  bool _merchantsLoading = true;
  List<NearbyMerchant> _merchants = [];
  String? _openingChatMerchantId;

  // Polls Meshy for progress while the job is still running so the preview
  // and progress state update on their own — no more manually tapping the
  // refresh icon. Stops itself once the job reaches a final status.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 5);

  @override
  void initState() {
    super.initState();
    _load();
    _loadMerchants();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String? get _token => context.read<AuthController>().token;

  Future<void> _openCartSheet() async {
    final model = _detail?.primaryModel;
    if (model == null) return;
    final added = await showDesignCartSheet(context, aiModelId: model.id);
    if (added && mounted) unawaited(_load());
  }

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    final status = _detail?.status;
    if (status == null || status.isJobFinished) return;
    _pollTimer = Timer(_pollInterval, _pollTick);
  }

  Future<void> _pollTick() async {
    final token = _token;
    if (token == null) return;
    try {
      await AiJobService.syncJobStatus(token: token, jobId: widget.jobId);
      final detail = await AiJobService.getJobDetail(token: token, jobId: widget.jobId);
      if (mounted) setState(() => _detail = detail);
    } catch (_) {
      // Best-effort — try again next tick.
    }
    _scheduleNextPoll();
  }

  Future<void> _loadMerchants() async {
    final token = _token;
    if (token == null) return;
    try {
      // Closest to the delivery address chosen on the home screen.
      final merchants = await MerchantService.listNearbyForMe(
        token: token,
        address: context.read<ActiveAddressController>().address,
      );
      if (!mounted) return;
      setState(() => _merchants = merchants);
    } catch (_) {
      // Best-effort — the rest of the order detail still works without it.
    } finally {
      if (mounted) setState(() => _merchantsLoading = false);
    }
  }

  Future<void> _openChatWith(String merchantId) async {
    final token = _token;
    if (token == null) return;
    if (!mounted) return;
    setState(() => _openingChatMerchantId = merchantId);
    try {
      final client = await context.read<ChatController>().ensureConnected(token);
      final info = await ChatService.createOrGetChannel(
        token: token,
        merchantId: merchantId,
        jobId: widget.jobId,
        previewUrl: _detail?.primaryModel?.previewUrl,
        prompt: _detail?.prompt,
      );
      final channel = client.channel(info.channelType, id: info.channelId);
      final orderId = info.orderId;
      if (orderId != null) await _shareOrderLink(channel, token, orderId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(client: client, channel: channel)),
      );
      if (!mounted) return;
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka chat. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _openingChatMerchantId = null);
    }
  }

  /// Posts this design's order into the merchant chat, so the merchant sees
  /// right away which order the customer means instead of searching for it.
  /// Only once per order (reopening the chat via "Chat" doesn't repeat it).
  /// Best-effort — if it fails, the chat still opens.
  Future<void> _shareOrderLink(Channel channel, String token, String orderId) async {
    final customerUserId = context.read<AuthController>().user?.id;
    try {
      if (channel.state == null) await channel.watch();
      if (OrderLinkService.alreadyShared(channel, orderId)) return;
      final order = await OrderService.getById(token: token, orderId: orderId);
      await OrderLinkService.send(channel, order, customerUserId: customerUserId, skipIfAlreadyShared: true);
    } catch (_) {
      // The customer can still send it manually from the chat's order button.
    }
  }

  /// First-time merchant pick — confirms since it locks the design to that
  /// merchant (server-side, see ChatService.ensureOrderForModel).
  Future<void> _pickMerchant(NearbyMerchant merchant) async {
    if (!await LocationGate.ensureEnabled(context) || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Konfirmasi'),
        content: Text(
          'Pilih ${merchant.fullName.isNotEmpty ? merchant.fullName : 'penjual ini'} untuk membuatkan desain ini? '
          'Setelah dipilih, kamu tidak bisa memilih merchant lain untuk desain ini.'
          '${merchant.operatingStatus?.isClosed == true ? '\n\n${merchant.operatingStatus!.closedOrderNotice}' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Ya, Pilih'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _openChatWith(merchant.id);
  }

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
      _scheduleNextPoll();
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

  Future<void> _retryRefine() async {
    final token = _token;
    if (token == null) return;
    setState(() => _refining = true);
    try {
      await AiJobService.refineJob(token: token, jobId: widget.jobId);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Proses warna & tekstur dimulai ulang.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal memulai ulang. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _refining = false);
    }
  }

  String? _downloading;

  Future<void> _download(ModelDownloadFormat format) async {
    final token = _token;
    if (token == null || _downloading != null) return;
    setState(() => _downloading = format.code);
    try {
      final uri = await AiJobService.modelDownloadUri(token: token, jobId: widget.jobId, format: format.code);
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) throw ApiException('Tidak dapat membuka unduhan. Coba lagi.');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal mengunduh file ${format.label}. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _downloading = null);
    }
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
                                    _truncateTitle(
                                      detail.prompt?.isNotEmpty == true
                                          ? detail.prompt!
                                          : widget.promptFallback ?? 'Tanpa deskripsi',
                                    ),
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
                            if (detail.primaryModel?.weightLabel != null) ...[
                              const SizedBox(height: 12),
                              _PrintEstimateCard(
                                // The autoscaled size is only final once the job is done.
                                size: detail.status == AiJobStatus.succeeded ? detail.primaryModel!.sizeLabel : null,
                                weight: detail.primaryModel!.weightLabel!,
                                totalFilament: detail.isMulticolor && detail.status == AiJobStatus.succeeded
                                    ? formatGramEstimate(detail.totalFilamentGrams)
                                    : null,
                                // The refine banner below already covers a failed Stage 2.
                                singleColorFallback: detail.multiColorFallback && !detail.isStuckWithoutRefine,
                              ),
                            ],
                            if (detail.negativePrompt?.isNotEmpty == true) ...[
                              const SizedBox(height: 8),
                              Text(
                                'Dihindari: ${detail.negativePrompt}',
                                style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                              ),
                            ],
                            if (detail.isStuckWithoutRefine) ...[
                              const SizedBox(height: 12),
                              _RefineRetryBanner(loading: _refining, onRetry: _retryRefine),
                            ],
                            const SizedBox(height: 20),
                            _ModelPreview(status: detail.status, model: detail.primaryModel),
                            if (detail.usesCart) ...[
                              const SizedBox(height: 18),
                              const Text(
                                'Toko Pembuat',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 10),
                              _AssignedMerchantCard(
                                merchant: detail.store!,
                                loading: _openingChatMerchantId == detail.store!.id,
                                onChat: _openingChatMerchantId == null ? () => _openChatWith(detail.store!.id) : null,
                              ),
                              const SizedBox(height: 14),
                              if (detail.canAddToCart) ...[
                                if (detail.cartItemId != null)
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8),
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle_rounded, size: 16, color: AppColors.success),
                                        SizedBox(width: 6),
                                        Text(
                                          'Desain ini sudah ada di keranjang',
                                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.success),
                                        ),
                                      ],
                                    ),
                                  ),
                                GradientButton(
                                  label: detail.cartItemId != null ? 'Ubah Material / Jumlah' : 'Masukkan ke Keranjang',
                                  icon: Icons.add_shopping_cart_rounded,
                                  onPressed: _openCartSheet,
                                ),
                              ] else if (!detail.status.isJobFinished)
                                const Text(
                                  'Setelah desain selesai dibuat, kamu bisa memilih material dan memasukkannya ke keranjang.',
                                  style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                ),
                            ],
                            if (detail.primaryModel != null) ...[
                              if (detail.downloadFormats.isNotEmpty) ...[
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
                                  for (final format in detail.downloadFormats)
                                    _FileChip(
                                      label: format.label,
                                      loading: _downloading == format.code,
                                      onTap: () => _download(format),
                                    ),
                                ],
                              ),
                              ],
                              const SizedBox(height: 22),
                              if (detail.usesCart)
                                const SizedBox.shrink()
                              else if (detail.assignedMerchant != null) ...[
                                const Text(
                                  'Merchant Kamu',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Desain ini sudah dipilih untuk merchant berikut — kamu tidak bisa memilih merchant lain lagi.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                _AssignedMerchantCard(
                                  merchant: detail.assignedMerchant!,
                                  loading: _openingChatMerchantId == detail.assignedMerchant!.id,
                                  onChat: _openingChatMerchantId == null
                                      ? () => _openChatWith(detail.assignedMerchant!.id)
                                      : null,
                                ),
                              ] else ...[
                                const Text(
                                  'Pilih Merchant Terdekat',
                                  style: TextStyle(
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Sekali memilih merchant, desain ini akan dibuatkan oleh merchant tersebut dan tidak bisa dipindah lagi.',
                                  style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                                const SizedBox(height: 10),
                                if (_merchantsLoading)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 12),
                                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                  )
                                else if (_merchants.isEmpty)
                                  const Text(
                                    'Belum ada merchant yang tersedia.',
                                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                                  )
                                else
                                  Column(
                                    children: [
                                      for (final merchant in _merchants)
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 10),
                                          child: _NearbyMerchantTile(
                                            merchant: merchant,
                                            loading: _openingChatMerchantId == merchant.id,
                                            onTap: _openingChatMerchantId == null
                                                ? () => _pickMerchant(merchant)
                                                : null,
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ],
                          ],
                        ),
        ),
      ],
    );
  }
}

/// The print as the backend autoscaled it: final size, item weight (AIModel.Weight)
/// and, for multicolour, the filament used including colour-change waste.
class _PrintEstimateCard extends StatelessWidget {
  final String? size;
  final String weight;
  final String? totalFilament;
  final bool singleColorFallback;

  const _PrintEstimateCard({required this.size, required this.weight, this.totalFilament, this.singleColorFallback = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (size != null) ...[
            _EstimateRow(icon: Icons.straighten_rounded, label: 'Ukuran hasil cetak', value: size!),
            const Padding(
              padding: EdgeInsets.only(left: 26, top: 2, bottom: 8),
              child: Text(
                'Panjang × lebar × tinggi. Proporsi model dijaga, jadi sisi terpanjang mengikuti ukuranmu.',
                style: TextStyle(fontSize: 11.5, height: 1.3, color: AppColors.textSecondary),
              ),
            ),
          ],
          _EstimateRow(icon: Icons.scale_outlined, label: 'Estimasi berat barang', value: weight),
          if (totalFilament != null) ...[
            const SizedBox(height: 8),
            _EstimateRow(icon: Icons.palette_outlined, label: 'Total filamen terpakai', value: totalFilament!),
            const Padding(
              padding: EdgeInsets.only(left: 26, top: 2),
              child: Text(
                'Multicolor: termasuk filamen terbuang saat ganti warna.',
                style: TextStyle(fontSize: 11.5, height: 1.3, color: AppColors.textSecondary),
              ),
            ),
          ],
          if (singleColorFallback) ...[
            const SizedBox(height: 10),
            const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: AppColors.orangeDeep),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Pewarnaan multi-filamen tidak berhasil diproses, jadi file 3MF dibuat satu warna. Toko tetap bisa mencetak dengan warna sesuai arahanmu.',
                    style: TextStyle(fontSize: 11.5, height: 1.35, color: AppColors.orangeDeep, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _EstimateRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _EstimateRow({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.purple),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
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

/// Shown when Stage 2 (color & texture) failed to auto-start after the mesh
/// preview finished — the model exists but stays colorless until someone
/// retries it (see AiJobDetail.isStuckWithoutRefine).
class _RefineRetryBanner extends StatelessWidget {
  final bool loading;
  final VoidCallback onRetry;

  const _RefineRetryBanner({required this.loading, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.orangeDeep.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orangeDeep.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.palette_outlined, size: 20, color: AppColors.orangeDeep),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Pewarnaan & tekstur model gagal diproses otomatis.',
              style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: loading ? null : onRetry,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                child: loading
                    ? const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text(
                        'Coba Lagi',
                        style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.orangeDeep),
                      ),
              ),
            ),
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
  final bool loading;
  final VoidCallback onTap;

  const _FileChip({required this.label, required this.onTap, this.loading = false});

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
              loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.purple),
                    )
                  : const Icon(Icons.download_rounded, size: 16, color: AppColors.purple),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NearbyMerchantTile extends StatelessWidget {
  final NearbyMerchant merchant;
  final bool loading;
  final VoidCallback? onTap;

  const _NearbyMerchantTile({required this.merchant, required this.loading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppColors.surfaceMuted,
                backgroundImage:
                    merchant.avatar != null && merchant.avatar!.isNotEmpty
                        ? NetworkImage(merchant.avatar!)
                        : null,
                child: merchant.avatar == null || merchant.avatar!.isEmpty
                    ? const Icon(Icons.storefront_rounded, size: 18, color: AppColors.purple)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            merchant.fullName.isNotEmpty ? merchant.fullName : 'Penjual',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        if (merchant.operatingStatus?.isClosed == true) ...[
                          const SizedBox(width: 6),
                          StoreStatusBadge(status: merchant.operatingStatus),
                        ],
                        if (merchant.distanceLabel.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          Text(
                            '~${merchant.distanceLabel}',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.orangeDeep),
                          ),
                        ],
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Row(
                        children: [
                          const Icon(Icons.place_outlined, size: 13, color: AppColors.textFaint),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              merchant.locationLine,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: merchant.hasRating
                          ? Row(
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: Color(0xFFF5A623)),
                                const SizedBox(width: 2),
                                Text(
                                  '${merchant.rating} · ${merchant.totalReviews} ulasan',
                                  style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                                ),
                              ],
                            )
                          : const Text(
                              'Belum ada rating',
                              style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                            ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: MerchantQueueBadge(status: merchant.queue),
                    ),
                  ],
                ),
              ),
              if (loading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                const Icon(Icons.chevron_right_rounded, size: 22, color: AppColors.purple),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignedMerchantCard extends StatelessWidget {
  final AssignedMerchantInfo merchant;
  final bool loading;
  final VoidCallback? onChat;

  const _AssignedMerchantCard({required this.merchant, required this.loading, required this.onChat});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.surface,
            backgroundImage: merchant.avatar != null && merchant.avatar!.isNotEmpty
                ? NetworkImage(merchant.avatar!)
                : null,
            child: merchant.avatar == null || merchant.avatar!.isEmpty
                ? const Icon(Icons.storefront_rounded, size: 18, color: AppColors.purple)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  merchant.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
                StoreStatusLine(status: merchant.operatingStatus),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(Icons.place_outlined, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 3),
                    Expanded(
                      child: Text(
                        merchant.locationLine,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (merchant.hasRating) ...[
                      const Icon(Icons.star_rounded, size: 13, color: Color(0xFFF5A623)),
                      const SizedBox(width: 2),
                      Text(
                        '${merchant.rating} · ${merchant.totalReviews} ulasan',
                        style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
                      ),
                    ] else
                      const Text(
                        'Belum ada rating',
                        style: TextStyle(fontSize: 11.5, color: AppColors.textFaint),
                      ),
                    const SizedBox(width: 8),
                    const Icon(Icons.lock_outline_rounded, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    const Text('Terpilih', style: TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            child: InkWell(
              borderRadius: BorderRadius.circular(30),
              onTap: onChat,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: loading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chat_bubble_outline_rounded, size: 16, color: AppColors.purple),
                          SizedBox(width: 6),
                          Text('Chat', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.purple)),
                        ],
                      ),
              ),
            ),
          ),
        ],
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
