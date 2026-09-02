/// One courier/service price option returned by Biteship's live rate check
/// (`POST /orders/:id/shipping-rates`). Parsed defensively with fallback key
/// names — the exact response shape wasn't live-verifiable while the
/// backend's Biteship account had insufficient balance for the metered
/// Rates API, so this reads multiple possible field names per value.
class ShippingRateOption {
  final String courierCompany;
  final String courierType;
  final String courierServiceName;
  final String? description;
  final int price;
  final String? duration;

  const ShippingRateOption({
    required this.courierCompany,
    required this.courierType,
    required this.courierServiceName,
    this.description,
    required this.price,
    this.duration,
  });

  factory ShippingRateOption.fromJson(Map<String, dynamic> json) {
    String? str(List<String> keys) {
      for (final k in keys) {
        final v = json[k];
        if (v != null && v.toString().isNotEmpty) return v.toString();
      }
      return null;
    }

    final priceRaw = json['price'] ?? json['Price'];
    final durationRange = str(['shipment_duration_range', 'duration_range']);
    final durationUnit = str(['shipment_duration_unit', 'duration_unit']);
    final duration = str(['duration']) ?? (durationRange != null ? '$durationRange ${durationUnit ?? ''}'.trim() : null);

    return ShippingRateOption(
      courierCompany: str(['courier_code', 'company', 'courier_company']) ?? '',
      courierType: str(['courier_service_code', 'type', 'courier_type']) ?? '',
      courierServiceName: str(['courier_service_name', 'service_name', 'service']) ?? 'Kurir',
      description: str(['description']),
      price: priceRaw is int ? priceRaw : int.tryParse('$priceRaw') ?? 0,
      duration: duration,
    );
  }

  String get courierDisplayName {
    final parts = [courierCompany.toUpperCase(), courierServiceName].where((p) => p.isNotEmpty);
    return parts.join(' · ');
  }
}
