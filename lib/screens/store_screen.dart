import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/nearby_merchant.dart';
import '../models/product.dart';
import '../providers/auth_controller.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/product_card.dart';
import '../widgets/store_picker.dart' show StoreSummaryTile;
import '../widgets/store_status.dart';
import 'chat/open_store_chat.dart';
import 'product_detail_screen.dart';

/// One store: its card (photo, city, rating, grams sold, hours), a chat
/// button and its published products — each opens the product page, where
/// it goes into the cart or straight to checkout.
class StoreScreen extends StatefulWidget {
  final NearbyMerchant store;

  const StoreScreen({super.key, required this.store});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  static const _pageSize = 20;

  final ScrollController _scroll = ScrollController();
  List<Product>? _products;
  String? _error;
  bool _loading = true;
  bool _loadingMore = false;
  bool _hasMore = false;
  int _page = 1;
  bool _openingChat = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_hasMore && !_loadingMore && _scroll.position.pixels > _scroll.position.maxScrollExtent - 300) _loadMore();
    });
    _load();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await ProductService.listProducts(
        token: token,
        sellerId: widget.store.id,
        isPublished: true,
        page: 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _products = page.items;
        _hasMore = page.hasMore;
        _page = 1;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Gagal memuat produk toko.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ProductService.listProducts(
        token: token,
        sellerId: widget.store.id,
        isPublished: true,
        page: _page + 1,
        limit: _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _products = [...?_products, ...page.items];
        _hasMore = page.hasMore;
        _page += 1;
      });
    } catch (_) {
      // Best-effort — scrolling retries.
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _chat() async {
    setState(() => _openingChat = true);
    await openStoreChat(context, widget.store.id);
    if (mounted) setState(() => _openingChat = false);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.store;
    final products = _products;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(s.fullName.isNotEmpty ? s.fullName : 'Toko', maxLines: 1, overflow: TextOverflow.ellipsis),
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        actions: const [CartIconButton(), SizedBox(width: 12)],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          controller: _scroll,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            StoreSummaryTile(store: s, trailing: const SizedBox.shrink()),
            if (s.address != null && s.address!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(s.address!, style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 6),
            StoreStatusLine(status: s.operatingStatus),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _openingChat ? null : _chat,
                icon: _openingChat
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.chat_bubble_outline_rounded),
                label: const Text('Chat Toko'),
              ),
            ),
            const SizedBox(height: 22),
            const Text(
              'Produk Toko',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 12),
            if (_loading && products == null)
              const Padding(padding: EdgeInsets.symmetric(vertical: 40), child: Center(child: CircularProgressIndicator()))
            else if (_error != null)
              Column(
                children: [
                  Text(_error!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  TextButton(onPressed: _load, child: const Text('Coba lagi')),
                ],
              )
            else if (products == null || products.isEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                decoration: BoxDecoration(color: AppColors.surfaceMuted, borderRadius: BorderRadius.circular(16)),
                child: const Column(
                  children: [
                    Icon(Icons.inventory_2_outlined, color: AppColors.textFaint, size: 30),
                    SizedBox(height: 6),
                    Text(
                      'Toko ini belum punya produk siap beli.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: products.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.63,
                ),
                itemBuilder: (context, i) => MarketProductCard(
                  product: products[i],
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => ProductDetailScreen(product: products[i])),
                  ),
                ),
              ),
            if (_loadingMore)
              const Padding(padding: EdgeInsets.symmetric(vertical: 20), child: Center(child: CircularProgressIndicator())),
          ],
        ),
      ),
    );
  }
}
