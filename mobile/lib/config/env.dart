import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppEnv {
  final String apiBaseUrl;
  final String socketUrl;
  final String socketPath;

  AppEnv._({
    required this.apiBaseUrl,
    required this.socketUrl,
    required this.socketPath,
  });

  factory AppEnv.load() {
    final api = dotenv.env['API_BASE_URL']?.trim();
    final socket = dotenv.env['SOCKET_URL']?.trim();
    final path = dotenv.env['SOCKET_PATH']?.trim();

    return AppEnv._(
      apiBaseUrl: api?.isNotEmpty == true ? api! : 'http://localhost:8000/api',
      socketUrl: socket?.isNotEmpty == true ? socket! : 'http://localhost:6001',
      socketPath: path?.isNotEmpty == true ? path! : '/socket.io',
    );
  }
}
