/// Minimal Country/Province/City/District/Village refs — used both as dropdown options and
/// as the nested display objects returned inside a [UserAddress].
class CountryRef {
  final int id;
  final String name;

  const CountryRef({required this.id, required this.name});

  factory CountryRef.fromJson(Map<String, dynamic> json) {
    return CountryRef(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
    );
  }
}

class ProvinceRef {
  final int id;
  final String name;
  final int? countryId;

  const ProvinceRef({required this.id, required this.name, this.countryId});

  factory ProvinceRef.fromJson(Map<String, dynamic> json) {
    return ProvinceRef(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
      countryId: json['CountryId'] is int ? json['CountryId'] as int : int.tryParse('${json['CountryId']}'),
    );
  }
}

class CityRef {
  final int id;
  final String name;
  final int? provinceId;

  const CityRef({required this.id, required this.name, this.provinceId});

  factory CityRef.fromJson(Map<String, dynamic> json) {
    return CityRef(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
      provinceId: json['ProvinceId'] is int ? json['ProvinceId'] as int : int.tryParse('${json['ProvinceId']}'),
    );
  }
}

/// Kecamatan (Indonesia only).
class DistrictRef {
  final int id;
  final String name;

  const DistrictRef({required this.id, required this.name});

  factory DistrictRef.fromJson(Map<String, dynamic> json) {
    return DistrictRef(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
    );
  }
}

/// Kelurahan / desa (Indonesia only), with its kode pos.
class VillageRef {
  final int id;
  final String name;
  final String? postalCode;

  const VillageRef({required this.id, required this.name, this.postalCode});

  factory VillageRef.fromJson(Map<String, dynamic> json) {
    final postal = json['PostalCode']?.toString().trim();
    return VillageRef(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
      postalCode: postal == null || postal.isEmpty ? null : postal,
    );
  }
}
