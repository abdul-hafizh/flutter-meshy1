class PaymentMethodOption {
  final int id;
  final String name;
  final String? provider;
  final bool isActive;

  const PaymentMethodOption({required this.id, required this.name, this.provider, this.isActive = true});

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    final active = json['IsActive'];
    return PaymentMethodOption(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
      provider: json['Provider']?.toString(),
      isActive: active == null || active == true || active == 1 || '$active' == '1',
    );
  }
}
