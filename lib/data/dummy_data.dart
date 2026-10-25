import 'package:flutter/material.dart';

enum OrderStatus { printing, shipped, done }

extension OrderStatusX on OrderStatus {
  String get label => switch (this) {
    OrderStatus.printing => 'Sedang Cetak',
    OrderStatus.shipped => 'Dikirim',
    OrderStatus.done => 'Selesai',
  };

  IconData get icon => switch (this) {
    OrderStatus.printing => Icons.view_in_ar_rounded,
    OrderStatus.shipped => Icons.local_shipping_outlined,
    OrderStatus.done => Icons.check_circle_outline_rounded,
  };

  Color get color => switch (this) {
    OrderStatus.printing => const Color(0xFFFF7A18),
    OrderStatus.shipped => const Color(0xFF3B82F6),
    OrderStatus.done => const Color(0xFF2FB380),
  };
}

class Order {
  final String id;
  final String name;
  final String date;
  final int price;
  final OrderStatus status;
  final double progress;

  const Order({
    required this.id,
    required this.name,
    required this.date,
    required this.price,
    required this.status,
    required this.progress,
  });

  String get priceLabel {
    final s = price.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final posFromEnd = s.length - i;
      buf.write(s[i]);
      if (posFromEnd > 1 && posFromEnd % 3 == 1) buf.write('.');
    }
    return 'Rp $buf';
  }
}

const List<Order> kOrders = [
  Order(
    id: 'ORD-001',
    name: 'Miniatur Porsche 911',
    date: '28 Jun 2026',
    price: 125000,
    status: OrderStatus.printing,
    progress: 0.65,
  ),
  Order(
    id: 'ORD-002',
    name: 'Phone Stand Astronaut',
    date: '27 Jun 2026',
    price: 85000,
    status: OrderStatus.shipped,
    progress: 0.9,
  ),
  Order(
    id: 'ORD-003',
    name: 'Vas Bunga Geometris',
    date: '25 Jun 2026',
    price: 95000,
    status: OrderStatus.done,
    progress: 1,
  ),
  Order(
    id: 'ORD-004',
    name: 'Gantungan Kunci Custom',
    date: '24 Jun 2026',
    price: 35000,
    status: OrderStatus.done,
    progress: 1,
  ),
];

/// A loyalty tier as set in the admin's Master Tier (`GET /user-tiers`) —
/// [key] is the fixed code (matches the `UserLevel` the API returns); the
/// icon and colour come from that code. [kLoyaltyTiers] is the fallback when
/// the list can't be loaded.
class LoyaltyTier {
  final String key;
  final String name;
  final String range;
  final String discountLabel;
  final IconData icon;
  final Color color;

  const LoyaltyTier({
    required this.key,
    required this.name,
    required this.range,
    required this.discountLabel,
    required this.icon,
    required this.color,
  });

  factory LoyaltyTier.fromMaster({
    required String code,
    required String label,
    required num minSpent,
    required num? nextMinSpent,
    required num discountPercent,
  }) {
    final key = code.toUpperCase();
    final style = kLoyaltyTiers.firstWhere((t) => t.key == key, orElse: () => kLoyaltyTiers.first);
    final range = nextMinSpent != null
        ? '${shortRupiah(minSpent)} – < ${shortRupiah(nextMinSpent)}'
        : '≥ ${shortRupiah(minSpent)}';
    final pct = discountPercent % 1 == 0 ? discountPercent.toInt().toString() : discountPercent.toString().replaceAll('.', ',');
    return LoyaltyTier(
      key: key,
      name: label.isNotEmpty ? label : style.name,
      range: range,
      discountLabel: discountPercent > 0 ? '-$pct%' : 'Standard',
      icon: style.icon,
      color: style.color,
    );
  }
}

/// "Rp 500rb", "Rp 1jt", "Rp 2,5jt" — compact amounts for the tier list.
String shortRupiah(num v) {
  String trim(double x) {
    final s = x.toStringAsFixed(1);
    return (s.endsWith('.0') ? s.substring(0, s.length - 2) : s).replaceAll('.', ',');
  }

  if (v >= 1000000000) return 'Rp ${trim(v / 1000000000)}M';
  if (v >= 1000000) return 'Rp ${trim(v / 1000000)}jt';
  if (v >= 1000) return 'Rp ${trim(v / 1000)}rb';
  return 'Rp ${v.round()}';
}

const List<LoyaltyTier> kLoyaltyTiers = [
  LoyaltyTier(
    key: 'BRONZE',
    name: 'Bronze',
    range: 'Rp 0 – < Rp 500rb',
    discountLabel: 'Standard',
    icon: Icons.military_tech_rounded,
    color: Color(0xFFC77B4A),
  ),
  LoyaltyTier(
    key: 'SILVER',
    name: 'Silver',
    range: '≥ Rp 500rb',
    discountLabel: '-5%',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF9AA3AF),
  ),
  LoyaltyTier(
    key: 'GOLD',
    name: 'Gold',
    range: '≥ Rp 1jt',
    discountLabel: '-10%',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFE0AA23),
  ),
  LoyaltyTier(
    key: 'PLATINUM',
    name: 'Platinum',
    range: '≥ Rp 5jt',
    discountLabel: '-20%',
    icon: Icons.diamond_outlined,
    color: Color(0xFF4FA8E0),
  ),
  LoyaltyTier(
    key: 'SOLITAIRE',
    name: 'Solitaire',
    range: '≥ Rp 10jt',
    discountLabel: '-30%',
    icon: Icons.diamond_rounded,
    color: Color(0xFF9B2FCE),
  ),
];
