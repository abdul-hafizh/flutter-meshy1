import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

import '../models/product.dart';
import '../providers/auth_controller.dart';
import '../providers/chat_controller.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/api_config.dart';
import '../services/chat_service.dart';
import '../services/order_service.dart';
import '../theme/app_theme.dart';
import '../widgets/gradient_button.dart';
import 'chat/chat_screen.dart';
import 'orders/checkout_screen.dart';

/// Product photo, seller, price, description and a quantity stepper — "Beli
/// Sekarang" creates an already-priced order via [OrderService.createFromProduct]
/// and hands off straight to the existing [CheckoutScreen], skipping the
/// prompt/chat flow entirely.
class ProductDetailScreen extends StatefulWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  int _quantity = 1;
  bool _buying = false;
  bool _openingChat = false;

  Future<void> _chatWithSeller() async {
    final sellerId = widget.product.sellerId;
    if (sellerId == null || sellerId.isEmpty) return;
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _openingChat = true);
    try {
      final client = await context.read<ChatController>().ensureConnected(token);
      final info = await ChatService.createOrGetChannel(token: token, merchantId: sellerId);
      final channel = client.channel(info.channelType, id: info.channelId);
      if (channel.state == null) await channel.watch();
      final product = widget.product;
      // Avoid re-spamming the same product link every time the customer
      // reopens this chat (e.g. just to check for a reply).
      final alreadyShared = (channel.state?.messages ?? const []).any(
        (m) => m.attachments.any((a) => a.type == 'PRODUCT_LINK' && a.extraData['productId'] == product.id),
      );
      if (!alreadyShared) {
        await channel.sendMessage(
          Message(
            text: '🔗 Produk: ${product.productName}',
            attachments: [
              Attachment(
                type: 'PRODUCT_LINK',
                uploadState: const UploadState.success(),
                extraData: {
                  'productId': product.id,
                  'productName': product.productName,
                  'thumbnailPath': product.thumbnailPath,
                  'price': product.price,
                },
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ChatScreen(client: client, channel: channel)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Gagal membuka chat. Coba lagi.')),
      );
    } finally {
      if (mounted) setState(() => _openingChat = false);
    }
  }

  Future<void> _buyNow() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _buying = true);
    try {
      final order = await OrderService.createFromProduct(
        token: token,
        productId: widget.product.id,
        quantity: _quantity,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => CheckoutScreen(order: order)),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _buying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final product = widget.product;
    final hasSeller = product.sellerId != null && product.sellerId!.isNotEmpty;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Detail Produk'),
        actions: [
          if (hasSeller)
            IconButton(
              onPressed: _openingChat ? null : _chatWithSeller,
              icon: _openingChat
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline_rounded),
              tooltip: 'Chat Penjual',
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          children: [
            AspectRatio(
              aspectRatio: 1,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                child: product.thumbnailPath != null && product.thumbnailPath!.isNotEmpty
                    ? Image.network(
                        ApiConfig.assetUrl(product.thumbnailPath!),
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => const _DetailThumbFallback(),
                      )
                    : const _DetailThumbFallback(),
              ),
            ),
            const SizedBox(height: 18),
            Text(
              product.productName,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.surfaceMuted,
                  backgroundImage: product.sellerAvatar != null && product.sellerAvatar!.isNotEmpty
                      ? NetworkImage(product.sellerAvatar!)
                      : null,
                  child: product.sellerAvatar == null || product.sellerAvatar!.isEmpty
                      ? const Icon(Icons.storefront_rounded, size: 13, color: AppColors.purple)
                      : null,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    product.sellerName ?? 'Merchant',
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              product.priceLabel,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.orangeDeep),
            ),
            const SizedBox(height: 4),
            Text(
              product.inStock ? 'Stok tersedia: ${product.stock}' : 'Stok habis',
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: product.inStock ? AppColors.success : Colors.redAccent,
              ),
            ),
            if (product.description != null && product.description!.trim().isNotEmpty) ...[
              const SizedBox(height: 18),
              const Text(
                'Deskripsi',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                product.description!,
                style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary, height: 1.5),
              ),
            ],
            const SizedBox(height: 22),
            if (product.inStock) ...[
              Row(
                children: [
                  const Text(
                    'Jumlah',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const Spacer(),
                  _QuantityStepper(
                    quantity: _quantity,
                    max: product.stock,
                    onChanged: (v) => setState(() => _quantity = v),
                  ),
                ],
              ),
              const SizedBox(height: 18),
            ],
            GradientButton(
              label: _buying
                  ? 'Memproses...'
                  : (product.inStock ? 'Beli Sekarang' : 'Stok Habis'),
              icon: Icons.shopping_bag_outlined,
              onPressed: product.inStock && !_buying ? _buyNow : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailThumbFallback extends StatelessWidget {
  const _DetailThumbFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: AppColors.brandGradientSoft),
      child: Center(
        child: ShaderMask(
          shaderCallback: (rect) => AppColors.brandGradient.createShader(rect),
          child: const Icon(Icons.view_in_ar_rounded, size: 64, color: Colors.white),
        ),
      ),
    );
  }
}

class _QuantityStepper extends StatelessWidget {
  final int quantity;
  final int max;
  final ValueChanged<int> onChanged;

  const _QuantityStepper({required this.quantity, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMuted,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.remove_rounded, size: 18),
            color: AppColors.textSecondary,
            onPressed: quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          Text(
            '$quantity',
            style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
          ),
          IconButton(
            icon: const Icon(Icons.add_rounded, size: 18),
            color: AppColors.textSecondary,
            onPressed: quantity < max ? () => onChanged(quantity + 1) : null,
          ),
        ],
      ),
    );
  }
}
