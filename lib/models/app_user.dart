/// Discount tier progress detail, as returned nested under `TierDetails` in
/// `GET /auth/me` — mirrors the backend's `userTierHelper.calculateTier()`.
class TierDetails {
  final String level;
  final int discountPercent;
  final String? nextTier;
  final num? nextThreshold;
  final num remainingForNextTier;
  final int progressPercent;

  const TierDetails({
    required this.level,
    required this.discountPercent,
    this.nextTier,
    this.nextThreshold,
    this.remainingForNextTier = 0,
    this.progressPercent = 0,
  });

  factory TierDetails.fromJson(Map<String, dynamic> json) {
    return TierDetails(
      level: json['level']?.toString() ?? 'BRONZE',
      discountPercent: json['discountPercent'] is int
          ? json['discountPercent'] as int
          : int.tryParse('${json['discountPercent']}') ?? 0,
      nextTier: json['nextTier']?.toString(),
      nextThreshold: json['nextThreshold'] is num ? json['nextThreshold'] as num : null,
      remainingForNextTier: json['remainingForNextTier'] is num ? json['remainingForNextTier'] as num : 0,
      progressPercent: json['progressPercent'] is int
          ? json['progressPercent'] as int
          : int.tryParse('${json['progressPercent']}') ?? 0,
    );
  }
}

class AppUser {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final int roleId;
  final String? role;
  final int credits;
  final String userLevel;
  final num totalSpent;
  final int discountPercent;
  final TierDetails? tierDetails;

  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.roleId,
    this.role,
    this.credits = 0,
    this.userLevel = 'BRONZE',
    this.totalSpent = 0,
    this.discountPercent = 0,
    this.tierDetails,
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
      userLevel: json['UserLevel']?.toString() ?? 'BRONZE',
      totalSpent: json['TotalSpent'] is num ? json['TotalSpent'] as num : num.tryParse('${json['TotalSpent']}') ?? 0,
      discountPercent: json['DiscountPercent'] is int
          ? json['DiscountPercent'] as int
          : int.tryParse('${json['DiscountPercent']}') ?? 0,
      tierDetails: json['TierDetails'] is Map<String, dynamic>
          ? TierDetails.fromJson(json['TierDetails'] as Map<String, dynamic>)
          : null,
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
        'UserLevel': userLevel,
        'TotalSpent': totalSpent,
        'DiscountPercent': discountPercent,
      };
}
