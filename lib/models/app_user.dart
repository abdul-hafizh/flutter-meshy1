class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final int roleId;
  final String? role;
  final int credits;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.roleId,
    this.role,
    this.credits = 0,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['Id']?.toString() ?? '',
      fullName: json['FullName']?.toString() ?? '',
      email: json['Email']?.toString() ?? '',
      phone: json['Phone']?.toString() ?? '',
      roleId: json['RoleId'] is int
          ? json['RoleId'] as int
          : int.tryParse('${json['RoleId']}') ?? 0,
      role: json['Role'] is String ? json['Role'] as String : (json['Role'] as Map<String, dynamic>?)?['Name']?.toString(),
      credits: json['AICredits'] is int
          ? json['AICredits'] as int
          : int.tryParse('${json['AICredits']}') ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'FullName': fullName,
        'Email': email,
        'Phone': phone,
        'RoleId': roleId,
        'Role': role,
        'AICredits': credits,
      };
}
