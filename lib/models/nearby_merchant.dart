import 'merchant_queue_status.dart';
import 'operating_status.dart';

/// One row from `GET /merchants/nearby` — a merchant candidate the customer
/// can pick to make their 3D result, with enough location info ("kota,
/// alamat, negara") to tell where they actually are before committing.
class NearbyMerchant {
  final String id;
  final String fullName;
  final String? avatar;
  final String? address;
  final String? cityName;
  final String? provinceName;
  final String? countryName;
  final double? distanceKm;
  final double? rating;
  final int totalReviews;
  final bool hasPrintQueue;
  final int queueCount;
  final int queueInProgressCount;
  final int queueWaitingCount;

  /// Earliest a printer is free for a new job (null = free now).
  final DateTime? estimatedAvailableAt;
  final OperatingStatus? operatingStatus;

  /// Weight of everything the store sold in completed orders (products and
  /// printed AI designs), and how many such orders.
  final int soldGrams;
  final int soldOrders;

  const NearbyMerchant({
    required this.id,
    required this.fullName,
    this.avatar,
    this.address,
    this.cityName,
    this.provinceName,
    this.countryName,
    this.distanceKm,
    this.rating,
    this.totalReviews = 0,
    this.hasPrintQueue = true,
    this.queueCount = 0,
    this.queueInProgressCount = 0,
    this.queueWaitingCount = 0,
    this.estimatedAvailableAt,
    this.operatingStatus,
    this.soldGrams = 0,
    this.soldOrders = 0,
  });

  factory NearbyMerchant.fromJson(Map<String, dynamic> json) {
    final company = json['Company'];
    final city = company is Map<String, dynamic> ? company['City'] : null;
    final province = company is Map<String, dynamic> ? company['Province'] : null;
    final country = company is Map<String, dynamic> ? company['Country'] : null;
    return NearbyMerchant(
      id: json['Id']?.toString() ?? '',
      fullName: json['FullName']?.toString() ?? 'Merchant',
      avatar: json['Avatar']?.toString(),
      address: company is Map<String, dynamic> ? company['Address']?.toString() : null,
      cityName: city is Map<String, dynamic> ? city['Name']?.toString() : null,
      provinceName: province is Map<String, dynamic> ? province['Name']?.toString() : null,
      countryName: country is Map<String, dynamic> ? country['Name']?.toString() : null,
      distanceKm: json['DistanceKm'] is num ? (json['DistanceKm'] as num).toDouble() : null,
      rating: json['Rating'] is num ? (json['Rating'] as num).toDouble() : null,
      totalReviews: json['TotalReviews'] is int ? json['TotalReviews'] as int : int.tryParse('${json['TotalReviews']}') ?? 0,
      hasPrintQueue: json['HasPrintQueue'] != false,
      queueCount: json['QueueCount'] is int ? json['QueueCount'] as int : int.tryParse('${json['QueueCount']}') ?? 0,
      queueInProgressCount: int.tryParse('${json['QueueInProgressCount']}') ?? 0,
      queueWaitingCount: int.tryParse('${json['QueueWaitingCount']}') ?? 0,
      estimatedAvailableAt: MerchantQueueStatus.parseTime(json['EstimatedAvailableAt']),
      operatingStatus: OperatingStatus.tryParse(json['OperatingStatus']),
      soldGrams: int.tryParse('${json['SoldGrams'] ?? 0}') ?? (json['SoldGrams'] is num ? (json['SoldGrams'] as num).round() : 0),
      soldOrders: int.tryParse('${json['SoldOrders'] ?? 0}') ?? 0,
    );
  }

  /// "Kota, Provinsi, Negara" — falls back gracefully when some parts are
  /// missing (a merchant's Company profile may be incomplete).
  String get locationLine {
    final parts = [
      if (cityName != null && cityName!.isNotEmpty) cityName,
      if (provinceName != null && provinceName!.isNotEmpty) provinceName,
      if (countryName != null && countryName!.isNotEmpty) countryName,
    ];
    return parts.isEmpty ? (address ?? '-') : parts.join(', ');
  }

  String get distanceLabel => distanceKm != null ? '${distanceKm!.toStringAsFixed(1)} km' : '';

  bool get hasRating => rating != null && totalReviews > 0;

  /// "1,2 kg terjual" / "350 g terjual".
  String get soldLabel {
    if (soldGrams >= 1000) {
      final kg = (soldGrams / 1000).toStringAsFixed(soldGrams >= 10000 ? 0 : 1).replaceAll('.', ',');
      return '$kg kg terjual';
    }
    return '$soldGrams g terjual';
  }

  /// Print-queue busyness for the "pilih merchant" list (see MerchantQueueBadge).
  MerchantQueueStatus get queue => MerchantQueueStatus(
        hasPrintQueue: hasPrintQueue,
        queueCount: queueCount,
        inProgressCount: queueInProgressCount,
        waitingCount: queueWaitingCount,
        estimatedAvailableAt: estimatedAvailableAt,
      );
}
