import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/dummy_data.dart';
import '../providers/auth_controller.dart';
import '../providers/chat_controller.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  static const int _currentTierIndex = 1; // Silver
  static const int _totalCetak = 23;
  static const int _poin = 2450;
  static const int _diskonPersen = 5;
  static const int _cetakUntukNaik = 28;
  static const int _totalBelanja = 2450000;

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar akun?',
          style: TextStyle(fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        content: const Text(
          'Kamu perlu masuk kembali untuk melanjutkan.',
          style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal', style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w700)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFE0453A),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Keluar', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await context.read<ChatController>().disconnect();
      if (!context.mounted) return;
      await context.read<AuthController>().logout();
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
    final currentTier = kLoyaltyTiers[_currentTierIndex];
    final nextTier = _currentTierIndex + 1 < kLoyaltyTiers.length
        ? kLoyaltyTiers[_currentTierIndex + 1]
        : null;
    final user = context.watch<AuthController>().user;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Profil',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
              ),
              GestureDetector(
                onTap: () => _confirmLogout(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE0453A).withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFFE0453A).withValues(alpha: 0.2)),
                  ),
                  child: const Icon(Icons.logout_rounded, color: Color(0xFFE0453A), size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: Column(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 84,
                      height: 84,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceMuted,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.border, width: 2),
                      ),
                      child: const Icon(Icons.person_rounded, size: 42, color: AppColors.textFaint),
                    ),
                    Positioned(
                      bottom: -2,
                      right: -2,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: AppColors.brandGradient,
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.surface, width: 3),
                        ),
                        child: Icon(currentTier.icon, size: 14, color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  user?.fullName ?? 'Creator',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.email ?? 'creator@snapy.co.id',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: currentTier.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${currentTier.name} Member',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: currentTier.color),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowFor(AppColors.purple),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Loyalty Program',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _LoyaltyStat(value: '$_totalCetak', label: 'Total Cetak'),
                    _LoyaltyStat(value: '$_poin', label: 'Poin'),
                    _LoyaltyStat(value: '$_diskonPersen%', label: 'Diskon'),
                  ],
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: 0.45,
                    minHeight: 8,
                    backgroundColor: Colors.white.withValues(alpha: 0.25),
                    valueColor: const AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(currentTier.name, style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                    Text(nextTier?.name ?? '', style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85), fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                Center(
                  child: Text(
                    '$_cetakUntukNaik cetak lagi untuk naik tier',
                    style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tier & Diskon',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 12),
                for (int i = 0; i < kLoyaltyTiers.length; i++) ...[
                  _TierRow(tier: kLoyaltyTiers[i], isCurrent: i == _currentTierIndex),
                  if (i != kLoyaltyTiers.length - 1) const Divider(height: 22, color: AppColors.border),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistik',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: _StatBlock(value: '$_totalCetak', label: 'Produk Dibuat'),
                    ),
                    Container(width: 1, height: 36, color: AppColors.border),
                    Expanded(
                      child: _StatBlock(value: _rupiah(_totalBelanja), label: 'Total Belanja'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoyaltyStat extends StatelessWidget {
  final String value;
  final String label;

  const _LoyaltyStat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: Colors.white),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, color: Colors.white.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final LoyaltyTier tier;
  final bool isCurrent;

  const _TierRow({required this.tier, required this.isCurrent});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: tier.color.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(tier.icon, size: 17, color: tier.color),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            children: [
              Text(
                tier.name,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
              ),
              if (isCurrent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'KAMU',
                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.orange),
                  ),
                ),
              ],
            ],
          ),
        ),
        Text(
          tier.discountLabel,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: tier.discountLabel == 'Standard' ? AppColors.textSecondary : AppColors.success,
          ),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  final String value;
  final String label;

  const _StatBlock({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
