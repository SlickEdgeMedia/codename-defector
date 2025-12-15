import 'package:dio/dio.dart';
import 'package:imposter_app/config/env.dart';

class ApiClient {
  ApiClient(this.env) {
    _dio = Dio(
      BaseOptions(
        baseUrl: env.apiBaseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        headers: {'Accept': 'application/json'},
      ),
    );
  }

  final AppEnv env;
  late final Dio _dio;

  void setAuthToken(String? token) {
    if (token == null || token.isEmpty) {
      _dio.options.headers.remove('Authorization');
    } else {
      _dio.options.headers['Authorization'] = 'Bearer $token';
    }
  }

  Future<Response<T>> get<T>(String path) {
    return _dio.get<T>(path);
  }

  Future<Response<T>> post<T>(String path, {Map<String, dynamic>? data}) {
    return _dio.post<T>(path, data: data);
  }
}
