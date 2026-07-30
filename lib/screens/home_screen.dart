import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/dummy_data.dart';
import '../providers/auth_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/category_tile.dart';
import '../widgets/product_card.dart';
import '../widgets/section_header.dart';

class HomeScreen extends StatelessWidget {
  final VoidCallback onCreateTap;

  const HomeScreen({super.key, required this.onCreateTap});

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
          const SizedBox(height: 22),
          _CreatePromptCard(onTap: onCreateTap),
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
          SectionHeader(title: 'Trending Creations', actionLabel: 'Lihat Semua', onAction: () {}),
          const SizedBox(height: 12),
          for (final p in kTrendingProducts) ...[
            TrendingProductTile(product: p),
            if (p != kTrendingProducts.last) const SizedBox(height: 10),
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
