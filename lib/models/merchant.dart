class Merchant {
  final String id;
  final String fullName;
  final String? avatar;
  final String? address;

  const Merchant({required this.id, required this.fullName, this.avatar, this.address});

  factory Merchant.fromJson(Map<String, dynamic> json) {
    return Merchant(
      id: json['Id']?.toString() ?? '',
      fullName: json['FullName']?.toString() ?? '',
      avatar: json['Avatar']?.toString(),
      address: json['Address']?.toString(),
    );
  }
}
