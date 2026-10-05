enum UserRole {
  surveyor,
  admin,
  unknown;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'surveyor': return UserRole.surveyor;
      case 'admin': return UserRole.admin;
      default: return UserRole.unknown;
    }
  }

  String toMapString() {
    switch (this) {
      case UserRole.surveyor: return 'surveyor';
      case UserRole.admin: return 'admin';
      case UserRole.unknown: return 'unknown';
    }
  }
}

class AppUser {
  final String uid;
  final String email;
  final UserRole role;
  final String name;
  final bool requiresPasswordChange;
  final bool isActive;

  AppUser({
    required this.uid,
    required this.email,
    required this.role,
    required this.name,
    this.requiresPasswordChange = true,
    this.isActive = true,
  });

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    if (!data.containsKey('email') || data['email'] == null) {
      throw FormatException('Data tidak lengkap: Email tidak ditemukan');
    }

    return AppUser(
      uid: uid,
      email: data['email'],
      role: UserRole.fromString(data['role'] ?? ''),
      name: data['name'] ?? 'Pengguna Tanpa Nama',
      requiresPasswordChange: data['requiresPasswordChange'] ?? false,
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'role': role.toMapString(),
      'name': name,
      'requiresPasswordChange': requiresPasswordChange,
      'isActive': isActive,
    };
  }

  AppUser copyWith({
    String? email,
    UserRole? role,
    String? name,
    bool? requiresPasswordChange,
    bool? isActive,
  }) {
    return AppUser(
      uid: uid,
      email: email ?? this.email,
      role: role ?? this.role,
      name: name ?? this.name,
      requiresPasswordChange: requiresPasswordChange ?? this.requiresPasswordChange,
      isActive: isActive ?? this.isActive,
    );
  }
}