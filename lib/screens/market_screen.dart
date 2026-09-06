import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/product.dart';
import '../providers/auth_controller.dart';
import '../services/auth_service.dart' show ApiException;
import '../services/product_service.dart';
import '../theme/app_theme.dart';
import '../widgets/category_tile.dart';
import '../widgets/product_card.dart';
import 'product_detail_screen.dart';

class MarketScreen extends StatefulWidget {
  const MarketScreen({super.key});

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  List<ProductCategoryOption> _categories = [];
  int? _selectedCategoryId;

  List<Product>? _products;
  bool _loading = true;
  String? _error;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_products == null) {
      _loadCategories();
      _loadProducts();
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  String? get _token => context.read<AuthController>().token;

  Future<void> _loadCategories() async {
    final token = _token;
    if (token == null) return;
    try {
      final categories = await ProductService.listCategories(token: token);
      if (!mounted) return;
      setState(() => _categories = categories);
    } on ApiException catch (_) {
      // Non-fatal — the "Semua" chip still works without categories.
    }
  }

  Future<void> _loadProducts() async {
    final token = _token;
    if (token == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await ProductService.listProducts(
        token: token,
        isPublished: true,
        search: _searchController.text,
        categoryId: _selectedCategoryId,
        limit: 50,
      );
      if (!mounted) return;
      setState(() {
        _products = products;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _onSearchChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), _loadProducts);
  }

  void _onCategorySelected(int? categoryId) {
    setState(() => _selectedCategoryId = categoryId);
    _loadProducts();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: RefreshIndicator(
        onRefresh: _loadProducts,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            const Text(
              'Marketplace',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Pilih produk siap cetak dari merchant, langsung checkout',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceMuted,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 20, color: AppColors.textFaint),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearchChanged,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: 14),
                        border: InputBorder.none,
                        hintText: 'Cari produk...',
                        hintStyle: TextStyle(fontSize: 14, color: AppColors.textFaint),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  SelectableCategoryChip(
                    label: 'Semua',
                    selected: _selectedCategoryId == null,
                    onTap: () => _onCategorySelected(null),
                  ),
                  for (final c in _categories) ...[
                    const SizedBox(width: 10),
                    SelectableCategoryChip(
                      label: c.name,
                      selected: _selectedCategoryId == c.id,
                      onTap: () => _onCategorySelected(c.id),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 34, color: AppColors.textFaint),
                      const SizedBox(height: 10),
                      Text(_error!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                      const SizedBox(height: 10),
                      OutlinedButton(onPressed: _loadProducts, child: const Text('Coba lagi')),
                    ],
                  ),
                ),
              )
            else if (_products == null || _products!.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text(
                    'Belum ada produk dari merchant.',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _products!.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 14,
                  crossAxisSpacing: 14,
                  childAspectRatio: 0.68,
                ),
                itemBuilder: (context, i) {
                  final product = _products![i];
                  return MarketProductCard(
                    product: product,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProductDetailScreen(product: product)),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
