class PaymentMethodOption {
  final int id;
  final String name;
  final String? provider;

  const PaymentMethodOption({required this.id, required this.name, this.provider});

  factory PaymentMethodOption.fromJson(Map<String, dynamic> json) {
    return PaymentMethodOption(
      id: json['Id'] is int ? json['Id'] as int : int.tryParse('${json['Id']}') ?? 0,
      name: json['Name']?.toString() ?? '',
      provider: json['Provider']?.toString(),
    );
  }
}
