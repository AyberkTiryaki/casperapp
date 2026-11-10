enum UserRole {
  member,
  trainer,
  admin;

  /// Bilinmeyen/boş değerlerde güvenli şekilde `member` döner.
  static UserRole fromString(String? value) {
    switch (value) {
      case 'admin':
        return UserRole.admin;
      case 'trainer':
        return UserRole.trainer;
      default:
        return UserRole.member;
    }
  }

  String get label => switch (this) {
        UserRole.member => 'Üye',
        UserRole.trainer => 'Antrenör',
        UserRole.admin => 'Yönetici',
      };
}

class Profile {
  const Profile({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.birthDate,
    this.heightCm,
    this.weightKg,
  });

  final String id;
  final String fullName;
  final DateTime? birthDate;
  final int? heightCm;
  final double? weightKg;
  final UserRole role;
  final bool isActive;

  factory Profile.fromJson(Map<String, dynamic> json) {
    return Profile(
      id: json['id'] as String,
      fullName: (json['full_name'] as String?) ?? '',
      birthDate: json['birth_date'] == null
          ? null
          : DateTime.tryParse(json['birth_date'] as String),
      heightCm: (json['height_cm'] as num?)?.toInt(),
      weightKg: (json['weight_kg'] as num?)?.toDouble(),
      role: UserRole.fromString(json['role'] as String?),
      isActive: (json['is_active'] as bool?) ?? true,
    );
  }
}
