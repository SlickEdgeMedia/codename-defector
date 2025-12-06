import 'package:imposter_app/models/user.dart';

class AuthResult {
  AuthResult({required this.token, required this.user});

  final String? token;
  final UserProfile? user;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String?,
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
    );
  }

  factory AuthResult.fromIntrospection(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token_id']?.toString(),
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
    );
  }
}
