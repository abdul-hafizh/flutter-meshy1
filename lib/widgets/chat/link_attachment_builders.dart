import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../../providers/auth_controller.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../screens/product_detail_screen.dart';
import '../../services/api_config.dart';
import '../../services/auth_service.dart' show ApiException;
import '../../services/product_service.dart';
import '../../theme/app_theme.dart';

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

/// Renders `PRODUCT_LINK` attachments (sent from [ProductDetailScreen]'s
/// chat button, or from a merchant sharing one of their products) as a
/// tappable card that opens [ProductDetailScreen] for that exact product.
class ProductLinkAttachmentBuilder extends StreamAttachmentWidgetBuilder {
  const ProductLinkAttachmentBuilder();

  @override
  bool canHandle(Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['PRODUCT_LINK'];
    return items != null && items.isNotEmpty;
  }

  @override
  Widget? build(BuildContext context, Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['PRODUCT_LINK']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [for (final a in items) _ProductLinkCard(attachment: a)],
    );
  }
}

class _ProductLinkCard extends StatefulWidget {
  final Attachment attachment;

  const _ProductLinkCard({required this.attachment});

  @override
  State<_ProductLinkCard> createState() => _ProductLinkCardState();
}

class _ProductLinkCardState extends State<_ProductLinkCard> {
  bool _loading = false;

  Future<void> _open() async {
    final productId = widget.attachment.extraData['productId']?.toString();
    if (productId == null || productId.isEmpty) return;
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _loading = true);
    try {
      final product = await ProductService.getById(token: token, productId: productId);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Produk tidak ditemukan.')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final extraData = widget.attachment.extraData;
    final name = extraData['productName']?.toString() ?? 'Produk';
    final thumbnailPath = extraData['thumbnailPath']?.toString();
    final price = extraData['price'];
    final priceLabel = price is num ? _rupiah(price.toInt()) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _loading ? null : _open,
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: thumbnailPath != null && thumbnailPath.isNotEmpty
                      ? Image.network(
                          ApiConfig.assetUrl(thumbnailPath),
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => const _ThumbFallback(),
                        )
                      : const _ThumbFallback(),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (priceLabel != null)
                      Text(
                        priceLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orangeDeep),
                      ),
                  ],
                ),
              ),
              _loading
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

/// Renders `ORDER_LINK` attachments as a tappable card that opens
/// [OrderDetailView] (wrapped in its own route) for that exact order —
/// authorization (customer owns it / merchant is assigned to it) is
/// enforced server-side by `GET /orders/:id`, surfaced as [OrderDetailView]'s
/// own error state if it doesn't apply to the viewer.
class OrderLinkAttachmentBuilder extends StreamAttachmentWidgetBuilder {
  const OrderLinkAttachmentBuilder();

  @override
  bool canHandle(Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['ORDER_LINK'];
    return items != null && items.isNotEmpty;
  }

  @override
  Widget? build(BuildContext context, Message message, Map<String, List<Attachment>> attachments) {
    final items = attachments['ORDER_LINK']!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [for (final a in items) _OrderLinkCard(attachment: a)],
    );
  }
}

class _OrderLinkCard extends StatelessWidget {
  final Attachment attachment;

  const _OrderLinkCard({required this.attachment});

  void _open(BuildContext context) {
    final orderId = attachment.extraData['orderId']?.toString();
    if (orderId == null || orderId.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: const Text('Detail Pesanan')),
          body: SafeArea(
            top: false,
            child: OrderDetailView(orderId: orderId, onBack: () => Navigator.of(context).pop()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final extraData = attachment.extraData;
    final orderNumber = extraData['orderNumber']?.toString() ?? 'Pesanan';
    final totalAmount = extraData['totalAmount'];
    final totalLabel = totalAmount is num ? _rupiah(totalAmount.toInt()) : null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Container(
          width: 230,
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.brandGradientSoft,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.receipt_long_rounded, color: AppColors.purple, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '#$orderNumber',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    if (totalLabel != null)
                      Text(
                        totalLabel,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.orangeDeep),
                      ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 18, color: AppColors.textFaint),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThumbFallback extends StatelessWidget {
  const _ThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradientSoft),
      child: const Icon(Icons.view_in_ar_rounded, size: 20, color: AppColors.purple),
    );
  }
}
