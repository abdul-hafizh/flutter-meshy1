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
  final int queueCount;
  final DateTime? estimatedAvailableAt;

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
    this.queueCount = 0,
    this.estimatedAvailableAt,
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
      queueCount: json['QueueCount'] is int ? json['QueueCount'] as int : int.tryParse('${json['QueueCount']}') ?? 0,
      estimatedAvailableAt: json['EstimatedAvailableAt'] != null
          ? DateTime.tryParse(json['EstimatedAvailableAt'].toString())
          : null,
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

  bool get hasActiveQueue => queueCount > 0;

  /// "Tidak ada antrian" when idle, otherwise "N antrian · longgar ~waktu" —
  /// gives the customer a rough sense of when this merchant's printer(s)
  /// would actually get to a new job, based on the merchant dashboard's own
  /// print-queue estimate (same WAITING/IN_PROGRESS chain, EstimatedFinishAt).
  String get queueLabel {
    if (!hasActiveQueue) return 'Tidak ada antrian';
    final eta = estimatedAvailableAt;
    final suffix = eta != null ? ' · longgar ${_relativeEta(eta)}' : '';
    return '$queueCount antrian$suffix';
  }

  static String _relativeEta(DateTime target) {
    final diff = target.difference(DateTime.now());
    if (diff.isNegative || diff.inMinutes < 1) return 'sebentar lagi';
    if (diff.inMinutes < 60) return '~${diff.inMinutes} menit lagi';
    if (diff.inHours < 24) return '~${diff.inHours} jam lagi';
    return '~${diff.inDays} hari lagi';
  }
}
