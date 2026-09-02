import 'dart:async';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:provider/provider.dart';

import '../../models/physical_order.dart';
import '../../providers/auth_controller.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/order_service.dart';
import '../../services/shipment_tracking_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/gradient_button.dart';
import 'checkout_screen.dart';

/// Renders inline inside the "Pesanan Fisik" tab (not pushed as its own
/// route) — same convention as `JobDetailView` for AI jobs, so the bottom
/// navigation bar stays visible while viewing an order.
class OrderDetailView extends StatefulWidget {
  final String orderId;
  final VoidCallback onBack;

  const OrderDetailView({super.key, required this.orderId, required this.onBack});

  @override
  State<OrderDetailView> createState() => _OrderDetailViewState();
}

class _OrderDetailViewState extends State<OrderDetailView> {
  bool _loading = true;
  String? _error;
  PhysicalOrder? _order;

  int _selectedRating = 0;
  bool _submittingRating = false;

  // Polls while the order has no price yet, so the "menunggu konfirmasi
  // harga" banner clears on its own once the merchant quotes it. Kept
  // fairly infrequent — this hits the heavily-joined order-detail endpoint
  // (AIModel previews/files, shipments, payments, status history, ...), and
  // a customer may realistically leave this screen open for a while waiting
  // on a merchant, so a tight interval adds up to real backend load.
  Timer? _pollTimer;
  static const _pollInterval = Duration(seconds: 20);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  String? get _token => context.read<AuthController>().token;

  void _scheduleNextPoll() {
    _pollTimer?.cancel();
    final order = _order;
    if (order == null || order.isPriced) return;
    _pollTimer = Timer(_pollInterval, _pollTick);
  }

  Future<void> _pollTick() async {
    final token = _token;
    if (token == null) return;
    try {
      final order = await OrderService.getById(token: token, orderId: widget.orderId);
      if (mounted) setState(() => _order = order);
    } catch (_) {
      // Best-effort — try again next tick.
    }
    _scheduleNextPoll();
  }

  Future<void> _load() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final order = await OrderService.getById(token: token, orderId: widget.orderId);
      if (!mounted) return;
      setState(() => _order = order);
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

  Future<void> _openCheckout() async {
    final order = _order;
    if (order == null) return;
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => CheckoutScreen(order: order)),
    );
    if (done == true) _load();
  }

  Future<void> _submitRating() async {
    final token = _token;
    final order = _order;
    if (token == null || order == null || _selectedRating == 0) return;
    setState(() => _submittingRating = true);
    try {
      await OrderService.rate(token: token, orderId: order.id, rating: _selectedRating);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Gagal mengirim penilaian. Coba lagi.')));
    } finally {
      if (mounted) setState(() => _submittingRating = false);
    }
  }

  String _rupiah(int v) {
    final s = v.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }

  @override
  Widget build(BuildContext context) {
    final order = _order;
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
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ),
              IconButton(
                tooltip: 'Muat ulang',
                onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: AppColors.textPrimary),
              ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
                  ? _ErrorState(message: _error!, onRetry: _load)
                  : order == null
                      ? const SizedBox.shrink()
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    order.orderNumber ?? 'Pesanan',
                                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                                  ),
                                ),
                                if (order.status != null) _StatusPill(status: order.status!),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _ModelPreview(item: order.primaryItem),
                            if (order.merchant != null) ...[
                              const SizedBox(height: 14),
                              _MerchantCard(merchant: order.merchant!),
                            ],
                            const SizedBox(height: 18),
                            _ActionArea(
                              order: order,
                              onCheckout: _openCheckout,
                              selectedRating: _selectedRating,
                              onRatingChanged: (v) => setState(() => _selectedRating = v),
                              submittingRating: _submittingRating,
                              onSubmitRating: _submitRating,
                              rupiah: _rupiah,
                            ),
                            if (order.statusHistories.isNotEmpty) ...[
                              const SizedBox(height: 22),
                              const Text(
                                'Riwayat Status',
                                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 10),
                              for (final entry in order.statusHistories)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.circle, size: 8, color: AppColors.purple),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          entry.remarks?.isNotEmpty == true ? entry.remarks! : 'Status diperbarui',
                                          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                                        ),
                                      ),
                                    ],
                                  ),
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
  final PhysicalOrderItem? item;

  const _ModelPreview({required this.item});

  @override
  Widget build(BuildContext context) {
    final viewerSrc = item?.aiModel?.glbViewerSrc;
    if (viewerSrc != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 260,
          color: AppColors.surfaceMuted,
          child: ModelViewer(
            key: ValueKey(viewerSrc),
            src: viewerSrc,
            alt: 'Model 3D pesanan',
            autoRotate: true,
            cameraControls: true,
            backgroundColor: AppColors.surfaceMuted,
            exposure: 0.75,
          ),
        ),
      );
    }
    return Container(
      height: 160,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Icon(Icons.view_in_ar_rounded, size: 34, color: AppColors.textFaint),
    );
  }
}

class _MerchantCard extends StatelessWidget {
  final OrderMerchantInfo merchant;

  const _MerchantCard({required this.merchant});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceMuted,
            backgroundImage: merchant.avatar != null && merchant.avatar!.isNotEmpty ? NetworkImage(merchant.avatar!) : null,
            child: merchant.avatar == null || merchant.avatar!.isEmpty
                ? const Icon(Icons.storefront_rounded, size: 16, color: AppColors.purple)
                : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              merchant.fullName,
              style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Courier/service summary plus an on-demand "Lacak Paket" button that pulls
/// live tracking history from Biteship (only populated once payment is
/// confirmed — see PaymentController.applyPaymentStatusTransition on the
/// backend, which is what actually books the shipment).
class _ShipmentCard extends StatefulWidget {
  final ShipmentInfo? shipment;

  const _ShipmentCard({required this.shipment});

  @override
  State<_ShipmentCard> createState() => _ShipmentCardState();
}

class _ShipmentCardState extends State<_ShipmentCard> {
  bool _loading = false;
  String? _error;
  ShipmentTrackingResult? _result;

  Future<void> _track() async {
    final shipment = widget.shipment;
    final token = context.read<AuthController>().token;
    if (shipment == null || token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ShipmentTrackingService.track(token: token, shipmentId: shipment.id);
      if (!mounted) return;
      setState(() => _result = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memuat tracking. Coba lagi.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final shipment = widget.shipment;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Pengiriman', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          if (shipment == null)
            const Text('Belum ada info pengiriman.', style: TextStyle(fontSize: 12.5, color: AppColors.textSecondary))
          else ...[
            Text(
              [shipment.courierCompany?.toUpperCase(), shipment.courierServiceName]
                  .where((s) => s != null && s.isNotEmpty)
                  .join(' · '),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 4),
            Text('Status: ${_result?.status ?? shipment.status}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            if (shipment.trackingNumber != null && shipment.trackingNumber!.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('No. Resi: ${shipment.trackingNumber}', style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: _loading ? null : _track,
                icon: _loading
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.location_searching_rounded, size: 16),
                label: Text(_loading ? 'Memuat...' : 'Lacak Paket'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  side: const BorderSide(color: AppColors.purple),
                  foregroundColor: AppColors.purple,
                  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: const TextStyle(fontSize: 12, color: Color(0xFFE0453A))),
              ],
              if (_result != null && _result!.history.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: AppColors.border),
                const SizedBox(height: 10),
                for (final event in _result!.history.reversed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Icon(Icons.circle, size: 7, color: AppColors.purple),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(event.note, style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
                              if (event.updatedAt != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: Text(_formatTime(event.updatedAt), style: const TextStyle(fontSize: 11, color: AppColors.textFaint)),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ],
          ],
        ],
      ),
    );
  }
}

class _ActionArea extends StatelessWidget {
  final PhysicalOrder order;
  final VoidCallback onCheckout;
  final int selectedRating;
  final ValueChanged<int> onRatingChanged;
  final bool submittingRating;
  final VoidCallback onSubmitRating;
  final String Function(int) rupiah;

  const _ActionArea({
    required this.order,
    required this.onCheckout,
    required this.selectedRating,
    required this.onRatingChanged,
    required this.submittingRating,
    required this.onSubmitRating,
    required this.rupiah,
  });

  @override
  Widget build(BuildContext context) {
    if (!order.isPriced) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.hourglass_top_rounded, size: 20, color: AppColors.orange),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Menunggu konfirmasi harga dari penjual. Halaman ini akan otomatis diperbarui.',
                style: TextStyle(fontSize: 12.5, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
      );
    }

    if (!order.isPaid) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Total Pesanan', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                Text(
                  rupiah(order.totalAmount ?? 0),
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          GradientButton(label: 'Lengkapi Pesanan', icon: Icons.arrow_forward_rounded, onPressed: onCheckout),
        ],
      );
    }

    final shipment = order.primaryShipment;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _ShipmentCard(shipment: shipment),
        if (order.status?.isCompleted == true && order.rating == null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Beri Penilaian', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
                const SizedBox(height: 8),
                Row(
                  children: [
                    for (int i = 1; i <= 5; i++)
                      IconButton(
                        padding: EdgeInsets.zero,
                        onPressed: () => onRatingChanged(i),
                        icon: Icon(
                          i <= selectedRating ? Icons.star_rounded : Icons.star_outline_rounded,
                          color: AppColors.orange,
                          size: 26,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                GradientButton(
                  label: submittingRating ? 'Mengirim...' : 'Kirim Penilaian',
                  height: 46,
                  onPressed: (selectedRating > 0 && !submittingRating) ? onSubmitRating : null,
                ),
              ],
            ),
          ),
        ] else if (order.rating != null) ...[
          const SizedBox(height: 14),
          Row(
            children: [
              for (int i = 1; i <= 5; i++)
                Icon(i <= order.rating! ? Icons.star_rounded : Icons.star_outline_rounded, color: AppColors.orange, size: 20),
            ],
          ),
        ],
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  final OrderStatusInfo status;

  const _StatusPill({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(status.colorCode) ?? AppColors.info;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
      child: Text(status.name, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color)),
    );
  }

  Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final cleaned = hex.replaceFirst('#', '');
    final value = int.tryParse(cleaned, radix: 16);
    if (value == null) return null;
    return Color(0xFF000000 | value);
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
