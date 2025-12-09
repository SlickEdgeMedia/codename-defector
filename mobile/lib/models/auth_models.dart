import 'package:imposter_app/models/user.dart';

class AuthResult {
  AuthResult({
    required this.token,
    required this.user,
    this.guestNickname,
    this.type = 'user',
  });

  final String? token;
  final UserProfile? user;
  final String? guestNickname;
  final String type;

  factory AuthResult.fromJson(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String?,
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
      type: 'user',
    );
  }

  factory AuthResult.fromIntrospection(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token_id']?.toString(),
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
      guestNickname: json['guest']?['nickname'] as String?,
      type: json['type'] as String? ?? 'user',
    );
  }

  factory AuthResult.fromGuest(Map<String, dynamic> json) {
    return AuthResult(
      token: json['token'] as String?,
      user: null,
      guestNickname: json['guest']?['nickname'] as String?,
      type: 'guest',
    );
  }
}
