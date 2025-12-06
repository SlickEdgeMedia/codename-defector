import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:imposter_app/config/env.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

class SocketService {
  SocketService(this.env);

  final AppEnv env;
  sio.Socket? _socket;

  void connect({
    required String token,
    required String roomCode,
    required void Function(Map<String, dynamic> event) onEvent,
  }) {
    disconnect();

    _socket = sio.io(
      env.socketUrl,
      sio.OptionBuilder()
          .setPath(env.socketPath)
          .setTransports(['websocket'])
          .setAuth({'token': token, 'roomCode': roomCode})
          .disableAutoConnect()
          .build(),
    );

    _socket?.on('connect', (_) => debugPrint('Socket connected'));
    _socket?.on(
      'connect_error',
      (error) => debugPrint('Socket connect_error: $error'),
    );

    for (final eventName in [
      'room.created',
      'room.joined',
      'room.ready_updated',
      'room.left',
      'room.closed',
    ]) {
      _socket?.on(eventName, (data) {
        if (data is Map<String, dynamic>) {
          onEvent(data);
        } else if (data is Map) {
          onEvent(Map<String, dynamic>.from(data));
        }
      });
    }

    _socket?.connect();
  }

  void disconnect() {
    _socket?.off();
    _socket?.disconnect();
    _socket?.close();
    _socket = null;
  }
}
