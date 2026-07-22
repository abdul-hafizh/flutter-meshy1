import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class _NavItemData {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _NavItemData(this.icon, this.activeIcon, this.label);
}

const List<_NavItemData> _items = [
  _NavItemData(Icons.home_outlined, Icons.home_rounded, 'Beranda'),
  _NavItemData(Icons.add_circle_outline_rounded, Icons.add_circle_rounded, 'Buat'),
  _NavItemData(Icons.storefront_outlined, Icons.storefront_rounded, 'Market'),
  _NavItemData(Icons.receipt_long_outlined, Icons.receipt_long_rounded, 'Pesanan'),
  _NavItemData(Icons.person_outline_rounded, Icons.person_rounded, 'Profil'),
];

class AppBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;

  const AppBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Container(
          height: 74,
          padding: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: List.generate(_items.length, (i) {
              final centerButton = i == 1;
              final active = currentIndex == i;
              final item = _items[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onTap(i),
                  child: centerButton
                      ? _CenterCreateButton(active: active)
                      : _NavItem(item: item, active: active),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final _NavItemData item;
  final bool active;

  const _NavItem({required this.item, required this.active});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 150),
      child: Column(
        key: ValueKey(active),
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            active ? item.activeIcon : item.icon,
            size: 24,
            color: active ? AppColors.orange : AppColors.textFaint,
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.orange : AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}

class _CenterCreateButton extends StatelessWidget {
  final bool active;

  const _CenterCreateButton({required this.active});

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: AppColors.brandGradient,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.surface, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowFor(AppColors.orange),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 2),
          Text(
            'Buat',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              color: active ? AppColors.orange : AppColors.textFaint,
            ),
          ),
        ],
      ),
    );
  }
}
