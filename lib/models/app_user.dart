class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final int roleId;
  final String? role;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.roleId,
    this.role,
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
      role: json['Role']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'Id': id,
        'FullName': fullName,
        'Email': email,
        'Phone': phone,
        'RoleId': roleId,
        'Role': role,
      };
}
