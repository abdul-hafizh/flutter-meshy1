import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../../providers/auth_controller.dart';
import '../../providers/cart_controller.dart';
import '../../screens/cart/cart_screen.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/custom_quote_service.dart';
import '../../theme/app_theme.dart';
import '../checkout/shipping_widgets.dart' show rupiahLabel;

/// Renders `CUSTOM_QUOTE` attachments — a store's penawaran harga from
/// Pesanan Custom. The customer agrees (it goes into their cart; the order is
/// made at checkout) or declines (the store can send a new price).
class QuoteAttachmentBuilder extends StreamAttachmentWidgetBuilder {
  const QuoteAttachmentBuilder();

  @override
  bool canHandle(Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['CUSTOM_QUOTE'];
    return items != null && items.isNotEmpty;
  }

  @override
  Widget? build(BuildContext context, Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['CUSTOM_QUOTE']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [for (final a in items) _QuoteCard(data: a.extraData)],
    );
  }
}

class _QuoteCard extends StatefulWidget {
  final Map<String, Object?> data;

  const _QuoteCard({required this.data});

  @override
  State<_QuoteCard> createState() => _QuoteCardState();
}

class _QuoteCardState extends State<_QuoteCard> {
  CustomQuote? _live;
  bool _busy = false;

  String? get _quoteId => widget.data['quoteId']?.toString();
  int get _revision => (widget.data['revision'] as num?)?.toInt() ?? 1;
  int _int(String key) => (widget.data[key] as num?)?.round() ?? 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    final id = _quoteId;
    if (token == null || id == null) return;
    try {
      final q = await CustomQuoteService.get(token: token, quoteId: id);
      if (mounted) setState(() => _live = q);
    } catch (_) {
      // The card still shows what was offered.
    }
  }

  void _toast(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _accept() async {
    final token = context.read<AuthController>().token;
    final id = _quoteId;
    if (token == null || id == null) return;
    setState(() => _busy = true);
    try {
      final message = await CustomQuoteService.accept(token: token, quoteId: id, revision: _revision);
      if (!mounted) return;
      _toast(message);
      await context.read<CartController>().refresh(token);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  Future<void> _reject() async {
    final token = context.read<AuthController>().token;
    final id = _quoteId;
    if (token == null || id == null) return;
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Tolak penawaran?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Toko akan diberi tahu dan bisa mengirim penawaran baru dengan harga lain.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLength: 500,
              maxLines: 2,
              decoration: const InputDecoration(hintText: 'Alasan (opsional), mis. harga terlalu mahal'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Batal')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Tolak')),
        ],
      ),
    );
    final reason = reasonCtrl.text;
    reasonCtrl.dispose();
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      _toast(await CustomQuoteService.reject(token: token, quoteId: id, revision: _revision, reason: reason));
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
      await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final files = (d['fileNames'] as List<dynamic>? ?? []).map((e) => e.toString()).toList();
    final editFee = _int('editServiceFee');
    final live = _live;
    final outdated = live != null && live.revision != _revision;
    final status = outdated ? 'OUTDATED' : live?.status;

    return Container(
      width: 270,
      margin: const EdgeInsets.all(4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.request_quote_outlined, size: 18, color: AppColors.orangeDeep),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _revision > 1 ? 'PENAWARAN HARGA · REVISI $_revision' : 'PENAWARAN HARGA',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppColors.orangeDeep, letterSpacing: 0.4),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(d['quoteNumber']?.toString() ?? '', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
          if (files.isNotEmpty)
            Text(files.join(', '), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary)),
          Text(
            [
              if (d['materialName'] != null) 'Bahan ${d['materialName']}',
              d['colorType'] == 'MULTI' ? 'Multicolor' : 'Satu warna',
              '${_int('quantity')} pcs',
            ].join(' · '),
            style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          _row('Harga barang', rupiahLabel(_int('itemsAmount'))),
          if (editFee > 0) _row('Jasa edit', rupiahLabel(editFee)),
          if (_int('discountAmount') > 0) _row('Diskon membership', '-${rupiahLabel(_int('discountAmount'))}'),
          if (_int('taxAmount') > 0) _row('PPN', rupiahLabel(_int('taxAmount'))),
          if (_int('appFeeAmount') > 0) _row('Biaya jasa aplikasi', rupiahLabel(_int('appFeeAmount'))),
          const Divider(height: 14),
          _row('Total', rupiahLabel(_int('payableAmount')), bold: true),
          const Text('Belum termasuk ongkir — dipilih saat checkout.', style: TextStyle(fontSize: 10.5, color: AppColors.textFaint)),
          if (d['notes'] != null && d['notes'].toString().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text('“${d['notes']}”', style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic, color: AppColors.textSecondary)),
          ],
          const SizedBox(height: 10),
          ..._footer(status, live),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(
          children: [
            Expanded(child: Text(label, style: TextStyle(fontSize: 12, color: bold ? AppColors.textPrimary : AppColors.textSecondary, fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
            Text(value, style: TextStyle(fontSize: bold ? 14 : 12, fontWeight: bold ? FontWeight.w800 : FontWeight.w600, color: AppColors.textPrimary)),
          ],
        ),
      );

  Widget _note(String text, Color color) =>
      Text(text, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color));

  List<Widget> _footer(String? status, CustomQuote? live) {
    switch (status) {
      case null:
        return [const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))];
      case 'OUTDATED':
        return [_note('Penawaran ini sudah diganti. Lihat penawaran terbaru di bawah.', AppColors.textSecondary)];
      case 'SENT':
        return [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _busy ? null : _accept,
              icon: const Icon(Icons.add_shopping_cart_rounded, size: 18),
              label: const Text('Setuju & Masukkan Keranjang'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.purple, foregroundColor: Colors.white),
            ),
          ),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: _busy ? null : _reject,
              child: const Text('Tolak', style: TextStyle(color: Color(0xFFE0453A), fontWeight: FontWeight.w700)),
            ),
          ),
        ];
      case 'ACCEPTED':
        return [
          _note('✅ Sudah di keranjang — lanjutkan checkout untuk memesan.', AppColors.success),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CartScreen())),
              icon: const Icon(Icons.shopping_cart_outlined, size: 18),
              label: const Text('Buka Keranjang'),
            ),
          ),
        ];
      case 'REJECTED':
        return [_note('Kamu menolak penawaran ini. Toko bisa mengirim penawaran baru.', const Color(0xFFE0453A))];
      case 'ORDERED':
        return [_note('🧾 Sudah dipesan — lihat di menu Pesanan.', AppColors.success)];
      default:
        return [_note(live?.statusLabel ?? 'Penawaran dibatalkan toko.', AppColors.textSecondary)];
    }
  }
}
