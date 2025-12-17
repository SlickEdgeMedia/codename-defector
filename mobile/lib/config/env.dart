import 'dart:io';
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

    // Platform-specific URL defaults
    // Android emulator uses 10.0.2.2 to access host machine
    // iOS simulator/device needs actual network IP (localhost doesn't work)
    // Use your machine's IP address for iOS (check with ifconfig)
    String defaultApiUrl;
    String defaultSocketUrl;

    if (Platform.isAndroid) {
      defaultApiUrl = 'http://10.0.2.2:8000/api';
      defaultSocketUrl = 'http://10.0.2.2:6001';
    } else if (Platform.isIOS) {
      // iOS simulator can use localhost (runs on same Mac)
      // Physical iOS devices need actual network IP (192.168.1.170)
      defaultApiUrl = 'http://localhost:8000/api';
      defaultSocketUrl = 'http://localhost:6001';
    } else {
      defaultApiUrl = 'http://localhost:8000/api';
      defaultSocketUrl = 'http://localhost:6001';
    }

    return AppEnv._(
      apiBaseUrl: api?.isNotEmpty == true ? api! : defaultApiUrl,
      socketUrl: socket?.isNotEmpty == true ? socket! : defaultSocketUrl,
      socketPath: path?.isNotEmpty == true ? path! : '/socket.io',
    );
  }
}
