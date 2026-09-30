import 'shipping_rate.dart';

/// A shipping category ("Instant Shipment", "Regular Shipment", "Regular
/// Cargo Shipment", "International Shipment", ...) from `GET
/// /shipping-methods`, with the couriers registered under it. The live
/// price/ETA for a specific courier still comes from Biteship's real-time
/// rate check — this catalog only supplies the category grouping and the
/// clean courier labels the customer picks from, and (once picked) a
/// reference the merchant dashboard can display back.
class ShippingMethodCategory {
  final int id;
  final String name;
  final String? provider;
  final String shippingType;
  final List<ShippingServiceOption> services;

  const ShippingMethodCategory({
    required this.id,
    required this.name,
    this.provider,
    required this.shippingType,
    this.services = const [],
  });

  factory ShippingMethodCategory.fromJson(Map<String, dynamic> json) {
    final servicesJson = json['Services'] as List<dynamic>? ?? [];
    return ShippingMethodCategory(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '-',
      provider: json['Provider']?.toString(),
      shippingType: json['ShippingType']?.toString() ?? '',
      services: servicesJson
          .map((e) => ShippingServiceOption.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  String get categoryLabel => shippingCategoryLabel(shippingType);

  /// Loose match against a Biteship rate's raw courier code (e.g. "jne",
  /// "gojek", "grab") — punctuation/case-insensitive, either direction,
  /// since neither side's naming convention is guaranteed to line up
  /// exactly ("J&T" vs Biteship's "jnt", etc).
  bool matchesProvider(String courierCompany) {
    // "&" reads as "n" so our "J&T" lines up with Biteship's "jnt".
    String normalize(String s) => s.toLowerCase().replaceAll('&', 'n').replaceAll(RegExp(r'[^a-z0-9]'), '');
    final p = normalize(provider ?? name);
    final c = normalize(courierCompany);
    if (p.isEmpty || c.isEmpty) return false;
    return p.contains(c) || c.contains(p);
  }
}

class ShippingServiceOption {
  final int id;
  final int shippingMethodId;
  final String serviceName;
  final String serviceCategory;
  final String? serviceCode;
  final String? estimatedDelivery;

  const ShippingServiceOption({
    required this.id,
    required this.shippingMethodId,
    required this.serviceName,
    required this.serviceCategory,
    this.serviceCode,
    this.estimatedDelivery,
  });

  factory ShippingServiceOption.fromJson(Map<String, dynamic> json) {
    return ShippingServiceOption(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      shippingMethodId: json['ShippingMethodId'] is int
          ? json['ShippingMethodId'] as int
          : int.tryParse('${json['ShippingMethodId']}') ?? 0,
      serviceName: json['ServiceName']?.toString() ?? '-',
      serviceCategory: json['ServiceCategory']?.toString() ?? '',
      serviceCode: json['ServiceCode']?.toString(),
      estimatedDelivery: json['EstimatedDelivery']?.toString(),
    );
  }
}

/// Human-readable label for a `ShippingMethod.ShippingType` value — falls
/// back to "Lainnya" for a live rate whose courier isn't in our catalog yet,
/// rather than hiding it.
String shippingCategoryLabel(String shippingType) {
  switch (shippingType.toUpperCase()) {
    case 'INSTANT_SHIPMENT':
      return 'Instan';
    case 'REGULAR_SHIPMENT':
      return 'Reguler';
    case 'REGULAR_CARGO_SHIPMENT':
      return 'Kargo';
    case 'INTERNATIONAL_CARGO_SHIPMENT':
      return 'Internasional';
    case 'INTERNAL_SHIPMENT':
      return 'Internal';
    default:
      return 'Lainnya';
  }
}

class ShippingRateMatch {
  final ShippingMethodCategory method;
  final ShippingServiceOption? service;

  const ShippingRateMatch({required this.method, this.service});
}

/// Finds which catalog category (and, best-effort, which specific service
/// under it) a live Biteship rate belongs to — `null` when no catalog entry
/// matches, which the picker groups under "Lainnya" instead of dropping it.
///
/// One courier can sit in several categories (JNE: "JNE" = Reguler and
/// "JNE Trucking" = Kargo), so the rate's service code decides: an exact
/// code match wins, then a loose one; with no code match at all it goes to
/// the courier's non-cargo category rather than whichever came first.
ShippingRateMatch? matchRateToCatalog(ShippingRateOption rate, List<ShippingMethodCategory> catalog) {
  final candidates = catalog.where((m) => m.matchesProvider(rate.courierCompany)).toList();
  if (candidates.isEmpty) return null;

  // Punctuation-insensitive: Biteship's "same_day" == our "SAMEDAY".
  String norm(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
  final type = norm(rate.courierType);
  ShippingRateMatch? loose;
  for (final method in candidates) {
    for (final service in method.services) {
      final code = norm(service.serviceCode ?? '');
      if (code.isEmpty || type.isEmpty) continue;
      if (code == type) return ShippingRateMatch(method: method, service: service);
      if (loose == null && (type.contains(code) || code.contains(type))) {
        loose = ShippingRateMatch(method: method, service: service);
      }
    }
  }
  if (loose != null) return loose;

  const preferred = ['REGULAR_SHIPMENT', 'INSTANT_SHIPMENT'];
  final method = candidates.firstWhere(
    (m) => preferred.contains(m.shippingType.toUpperCase()),
    orElse: () => candidates.first,
  );
  return ShippingRateMatch(method: method, service: method.services.isNotEmpty ? method.services.first : null);
}
