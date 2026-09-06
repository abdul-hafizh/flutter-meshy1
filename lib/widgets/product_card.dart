import 'package:flutter/material.dart';
import '../models/product.dart';
import '../theme/app_theme.dart';

/// Gradient-tinted square placeholder standing in for a product photo —
/// shown whenever a product has no thumbnail, or its image fails to load.
class ProductThumb extends StatelessWidget {
  final double size;
  final double radius;

  const ProductThumb({super.key, required this.size, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: AppColors.brandGradientSoft,
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Center(
        child: ShaderMask(
          shaderCallback: (rect) => AppColors.brandGradient.createShader(rect),
          child: Icon(
            Icons.view_in_ar_rounded,
            size: size * 0.42,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// Product photo if available, falling back to [ProductThumb] on a missing
/// URL or a failed load — the one place that decides between the two so
/// every card stays consistent.
class _ProductImage extends StatelessWidget {
  final Product product;
  final double size;
  final double radius;

  const _ProductImage({required this.product, required this.size, this.radius = 16});

  @override
  Widget build(BuildContext context) {
    final url = product.thumbnailPath;
    if (url == null || url.isEmpty) {
      return ProductThumb(size: size, radius: radius);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => ProductThumb(size: size, radius: radius),
      ),
    );
  }
}

/// Small "Habis" tag overlaid on an out-of-stock product's image.
class _OutOfStockBadge extends StatelessWidget {
  const _OutOfStockBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Text(
        'Habis',
        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: Colors.white),
      ),
    );
  }
}

/// Horizontal row-style card used in the Beranda "Produk Siap Checkout" list.
class TrendingProductTile extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const TrendingProductTile({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              _ProductImage(product: product, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      product.productName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      product.sellerName ?? product.categoryName ?? '-',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                product.priceLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orangeDeep,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Vertical grid card used on the Marketplace screen.
class MarketProductCard extends StatelessWidget {
  final Product product;
  final VoidCallback? onTap;

  const MarketProductCard({super.key, required this.product, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Opacity(
          opacity: product.inStock ? 1 : 0.6,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      _ProductImage(product: product, size: double.infinity, radius: 14),
                      if (!product.inStock)
                        const Positioned(bottom: 8, left: 8, child: _OutOfStockBadge()),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  product.productName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'oleh ${product.sellerName ?? '-'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  product.priceLabel,
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.orangeDeep,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
