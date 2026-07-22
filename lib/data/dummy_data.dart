import 'package:flutter/material.dart';

class ProductCategory {
  final String label;
  final IconData icon;

  const ProductCategory({required this.label, required this.icon});
}

const List<ProductCategory> kCategories = [
  ProductCategory(label: 'Figurine', icon: Icons.person_outline_rounded),
  ProductCategory(label: 'Aksesoris', icon: Icons.star_border_rounded),
  ProductCategory(label: 'Dekorasi', icon: Icons.favorite_border_rounded),
  ProductCategory(label: 'Gadget Case', icon: Icons.bolt_rounded),
];

class Product {
  final String name;
  final String category;
  final int price;
  final String? creator;
  final double? rating;
  final int? sold;

  const Product({
    required this.name,
    required this.category,
    required this.price,
    this.creator,
    this.rating,
    this.sold,
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

const List<Product> kTrendingProducts = [
  Product(name: 'Miniatur Porsche 911', category: 'Figurine', price: 125000),
  Product(name: 'Phone Stand Astronaut', category: 'Aksesoris', price: 85000),
  Product(name: 'Vas Bunga Geometris', category: 'Dekorasi', price: 95000),
  Product(name: 'Gantungan Kunci Custom', category: 'Custom', price: 35000),
];

const List<Product> kMarketProducts = [
  Product(
    name: 'Miniatur Porsche 911',
    category: 'Figurine',
    price: 125000,
    creator: 'Andi R.',
    rating: 4.8,
    sold: 234,
  ),
  Product(
    name: 'Phone Stand Astronaut',
    category: 'Aksesoris',
    price: 85000,
    creator: 'Sari M.',
    rating: 4.9,
    sold: 567,
  ),
  Product(
    name: 'Vas Bunga Geometris',
    category: 'Dekorasi',
    price: 95000,
    creator: 'Budi K.',
    rating: 4.7,
    sold: 189,
  ),
  Product(
    name: 'Gantungan Kunci Logo',
    category: 'Custom',
    price: 35000,
    creator: 'Dina P.',
    rating: 4.6,
    sold: 1023,
  ),
  Product(
    name: 'Lampu Hias Kristal',
    category: 'Dekorasi',
    price: 145000,
    creator: 'Rian T.',
    rating: 4.9,
    sold: 87,
  ),
  Product(
    name: 'Case Gaming Custom',
    category: 'Gadget Case',
    price: 65000,
    creator: 'Nadia F.',
    rating: 4.5,
    sold: 312,
  ),
];

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

class LoyaltyTier {
  final String name;
  final String range;
  final String discountLabel;
  final IconData icon;
  final Color color;

  const LoyaltyTier({
    required this.name,
    required this.range,
    required this.discountLabel,
    required this.icon,
    required this.color,
  });
}

const List<LoyaltyTier> kLoyaltyTiers = [
  LoyaltyTier(
    name: 'Bronze',
    range: '0-10 cetak',
    discountLabel: 'Standard',
    icon: Icons.military_tech_rounded,
    color: Color(0xFFC77B4A),
  ),
  LoyaltyTier(
    name: 'Silver',
    range: '11-50 cetak',
    discountLabel: '-5%',
    icon: Icons.military_tech_rounded,
    color: Color(0xFF9AA3AF),
  ),
  LoyaltyTier(
    name: 'Gold',
    range: '51-199 cetak',
    discountLabel: '-10%',
    icon: Icons.emoji_events_rounded,
    color: Color(0xFFE0AA23),
  ),
  LoyaltyTier(
    name: 'Sultan',
    range: '200+ cetak',
    discountLabel: '-20%',
    icon: Icons.diamond_rounded,
    color: Color(0xFF9B2FCE),
  ),
];
