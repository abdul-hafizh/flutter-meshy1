import 'region.dart';

/// One of the logged-in user's saved shipping addresses (`UserAddress` on
/// the backend). A user can have many; exactly one may have [isDefault].
class UserAddress {
  final String id;
  final String label;
  final String? recipientName;
  final String? phone;
  final String? whatsappNumber;
  final String? address;
  final int? countryId;
  final int? provinceId;
  final int? cityId;
  final CountryRef? country;
  final ProvinceRef? province;
  final CityRef? city;
  final String? postalCode;
  final bool isDefault;

  const UserAddress({
    required this.id,
    required this.label,
    this.recipientName,
    this.phone,
    this.whatsappNumber,
    this.address,
    this.countryId,
    this.provinceId,
    this.cityId,
    this.country,
    this.province,
    this.city,
    this.postalCode,
    this.isDefault = false,
  });

  factory UserAddress.fromJson(Map<String, dynamic> json) {
    return UserAddress(
      id: json['Id']?.toString() ?? '',
      label: json['Label']?.toString() ?? 'Alamat',
      recipientName: json['RecipientName']?.toString(),
      phone: json['Phone']?.toString(),
      whatsappNumber: json['WhatsappNumber']?.toString(),
      address: json['Address']?.toString(),
      countryId: json['CountryId'] is int ? json['CountryId'] as int : int.tryParse('${json['CountryId']}'),
      provinceId: json['ProvinceId'] is int ? json['ProvinceId'] as int : int.tryParse('${json['ProvinceId']}'),
      cityId: json['CityId'] is int ? json['CityId'] as int : int.tryParse('${json['CityId']}'),
      country: json['Country'] is Map<String, dynamic> ? CountryRef.fromJson(json['Country'] as Map<String, dynamic>) : null,
      province: json['Province'] is Map<String, dynamic> ? ProvinceRef.fromJson(json['Province'] as Map<String, dynamic>) : null,
      city: json['City'] is Map<String, dynamic> ? CityRef.fromJson(json['City'] as Map<String, dynamic>) : null,
      postalCode: json['PostalCode']?.toString(),
      isDefault: json['IsDefault'] == true || json['IsDefault'] == 1,
    );
  }

  /// One-line summary for compact display (order summary, checkout header).
  String get summaryLine {
    final parts = [
      if (address != null && address!.isNotEmpty) address,
      if (city != null) city!.name,
      if (province != null) province!.name,
      if (postalCode != null && postalCode!.isNotEmpty) postalCode,
    ];
    return parts.join(', ');
  }
}
