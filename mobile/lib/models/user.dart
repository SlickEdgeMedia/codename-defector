class UserProfile {
  UserProfile({required this.id, required this.name, this.email});

  final int id;
  final String name;
  final String? email;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
      email: json['email'] as String?,
    );
  }
}
