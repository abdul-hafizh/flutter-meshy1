import 'package:flutter/material.dart';
import '../data/dummy_data.dart';
import '../theme/app_theme.dart';
import '../widgets/product_card.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  String _activeTab = 'Semua';
  static const _tabs = ['Semua', 'Aktif', 'Selesai'];

  List<Order> get _filtered {
    switch (_activeTab) {
      case 'Aktif':
        return kOrders.where((o) => o.status != OrderStatus.done).toList();
      case 'Selesai':
        return kOrders.where((o) => o.status == OrderStatus.done).toList();
      default:
        return kOrders;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'Pesanan Saya',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Lacak status pesanan 3D printing kamu',
            style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              for (final t in _tabs) ...[
                _OrderTab(
                  label: t,
                  active: _activeTab == t,
                  onTap: () => setState(() => _activeTab = t),
                ),
                const SizedBox(width: 10),
              ],
            ],
          ),
          const SizedBox(height: 18),
          for (final o in _filtered) ...[
            _OrderCard(order: o),
            if (o != _filtered.last) const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}

class _OrderTab extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _OrderTab({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            gradient: active ? AppColors.brandGradient : null,
            color: active ? null : AppColors.surface,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: active ? Colors.transparent : AppColors.border),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: active ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  final Order order;

  const _OrderCard({required this.order});

  @override
  Widget build(BuildContext context) {
    final status = order.status;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                order.id,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textFaint,
                ),
              ),
              _StatusBadge(status: status),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const ProductThumb(size: 46),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      order.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      order.date,
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Text(
                order.priceLabel,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.orangeDeep,
                ),
              ),
            ],
          ),
          if (status != OrderStatus.done) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: order.progress,
                minHeight: 7,
                backgroundColor: AppColors.surfaceMuted,
                valueColor: AlwaysStoppedAnimation(status.color),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(order.progress * 100).round()}% selesai',
              style: const TextStyle(fontSize: 11.5, color: AppColors.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final OrderStatus status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(status.icon, size: 13, color: status.color),
          const SizedBox(width: 4),
          Text(
            status.label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: status.color),
          ),
        ],
      ),
    );
  }
}
