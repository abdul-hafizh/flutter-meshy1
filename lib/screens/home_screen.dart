import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/dummy_data.dart';
import '../models/product.dart';
import '../providers/auth_controller.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_tile.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';
import '../widgets/token_balance_badge.dart';
import 'buy_tokens_screen.dart';
import 'chat/chat_list_screen.dart';
import 'product_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onCreateTap;

  const HomeScreen({super.key, required this.onCreateTap});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Product>? _readyProducts;
  bool _loadingProducts = true;
  String? _loadError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_readyProducts == null) _loadProducts();
  }

  Future<void> _loadProducts() async {
    final token = context.read<AuthController>().token;
    if (token == null) return;
    setState(() {
      _loadingProducts = true;
      _loadError = null;
    });
    try {
      final products = await ProductService.listProducts(token: token, isPublished: true, limit: 20);
      if (!mounted) return;
      setState(() {
        _readyProducts = products.where((p) => p.inStock).take(6).toList();
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
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const BuyTokensScreen()),
                    ),
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
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      gradient: AppColors.brandGradient,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.notifications_none_rounded,
                      color: Colors.white,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 22),
          _CreatePromptCard(onTap: widget.onCreateTap),
          const SizedBox(height: 26),
          const Text(
            'Kategori',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final c in kCategories) ...[
                Expanded(child: CategoryTile(category: c)),
                if (c != kCategories.last) const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 26),
          SectionHeader(title: 'Produk Siap Checkout', actionLabel: 'Lihat Semua', onAction: () {}),
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

class _CreatePromptCard extends StatelessWidget {
  final VoidCallback onTap;

  const _CreatePromptCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.brandGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowFor(AppColors.purple),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Apa yang mau kamu ciptakan?',
            style: TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Ketik ide kamu, AI yang wujudkan jadi 3D',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Material(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 6, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Contoh: Miniatur mobil sport warna merah.',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textFaint,
                        ),
                      ),
                    ),
                    Container(
                      width: 38,
                      height: 38,
                      decoration: const BoxDecoration(
                        gradient: AppColors.brandGradient,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.arrow_forward_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
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
