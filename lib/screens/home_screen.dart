import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product.dart';
import '../providers/auth_controller.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/product_service.dart';
import '../services/promotion_service.dart';
import '../theme/app_theme.dart';
import '../widgets/cart_icon_button.dart';
import '../widgets/home/delivery_address_bar.dart';
import '../widgets/home/nearby_stores_section.dart';
import '../widgets/home/promo_popup.dart';
import '../widgets/home/start_options.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';
import '../widgets/token_balance_badge.dart';
import '../config/features.dart';
import 'buy_tokens_screen.dart';
import 'chat/chat_list_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onCreateTap;
  final VoidCallback onSeeAllTap;

  const HomeScreen({super.key, required this.onCreateTap, required this.onSeeAllTap});

  @override
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
  /// Called when the Home tab is opened again — refreshes "Produk Siap Checkout".
  Future<void> reload() => _loadProducts();

  List<Product>? _readyProducts;
  bool _loadingProducts = true;
  String? _loadError;

  /// The promo pop-up shows once per app launch (not on every return to Home).
  static bool _promoShown = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readyProducts == null) _loadProducts();
    if (!_promoShown) _showPromos();
  }

  Future<void> _showPromos() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    _promoShown = true;
    try {
      final promos = await PromotionService.active(token: token);
      if (!mounted || promos.isEmpty) return;
      await showPromoPopup(context, promos);
    } on ApiException {
      // No pop-up this time.
    }
  }

  Future<void> _loadProducts() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });
    try {
      final page = await ProductService.listProducts(token: token, isPublished: true, limit: 20);
      if (!mounted) return;
      setState(() {
        _readyProducts = page.items.where((p) => p.inStock).take(6).toList();
        _loadingProducts = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingProducts = false;
        _loadError = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final firstName = (user?.fullName.isNotEmpty ?? false) ? user!.fullName.split(' ').first : 'Creator';

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Selamat datang,',
                    style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
                  ),
                  Text(
                    firstName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  TokenBalanceBadge(
                    credits: user?.credits ?? 0,
                    onTap: kTokenPurchaseEnabled
                        ? () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const BuyTokensScreen()),
                            )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const ChatListScreen()),
                    ),
                    child: Container(
                      width: 42,
                      height: 42,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.chat_bubble_outline_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const CartIconButton(),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          const DeliveryAddressBar(),
          const SizedBox(height: 18),
          // Three ways to order: market, AI prompt, or a ready-to-print file via a store's chat.
          StartOptions(onReadyMade: widget.onSeeAllTap, onPrompt: widget.onCreateTap),
          const SizedBox(height: 26),
          const NearbyStoresSection(),
          const SizedBox(height: 26),
          SectionHeader(title: 'Produk Siap Checkout', actionLabel: 'Lihat Semua', onAction: widget.onSeeAllTap),
          const SizedBox(height: 12),
          if (_loadingProducts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_loadError != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Gagal memuat produk: $_loadError',
                      style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                    ),
                  ),
                  TextButton(onPressed: _loadProducts, child: const Text('Coba lagi')),
                ],
              ),
            )
          else if (_readyProducts == null || _readyProducts!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Belum ada produk siap checkout dari merchant.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            )
          else
            for (final p in _readyProducts!) ...[
              TrendingProductTile(
                product: p,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ProductDetailScreen(product: p)),
                ),
              ),
              if (p != _readyProducts!.last) const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

