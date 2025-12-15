import 'package:imposter_app/data/api_client.dart';
import 'package:imposter_app/models/auth_models.dart';

class AuthRepository {
  AuthRepository(this._api);

  final ApiClient _api;

  void setAuthToken(String? token) {
    _api.setAuthToken(token);
  }

  Future<AuthResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/register',
      data: {
        'name': name,
        'email': email,
        'password': password,
        'password_confirmation': password,
      },
    );

    return AuthResult.fromJson(response.data ?? {});
  }

  Future<AuthResult> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/login',
      data: {'email': email, 'password': password},
    );

    return AuthResult.fromJson(response.data ?? {});
  }

  Future<AuthResult> introspect() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/introspect');
    return AuthResult.fromIntrospection(response.data ?? {});
  }

  Future<AuthResult> guest({required String nickname}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/guest',
      data: {'nickname': nickname},
    );

    return AuthResult.fromGuest(response.data ?? {});
  }
}
