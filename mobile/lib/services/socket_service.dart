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
    void Function(String status)? onStatus,
    void Function(String message)? onError,
  }) {
    disconnect();

    _socket = sio.io(
      env.socketUrl,
      sio.OptionBuilder()
          .setPath(env.socketPath)
          .setTransports(['websocket', 'polling'])
          .enableReconnection()
          .setReconnectionAttempts(0) // unlimited
          .setTimeout(8000)
          .setAuth({'token': token, 'roomCode': roomCode})
          .disableAutoConnect()
          .build(),
    );

    _socket?.on('connect', (_) {
      onStatus?.call('connected');
    });

    _socket?.on('reconnect_attempt', (_) {
      onStatus?.call('connecting');
    });

    _socket?.on('reconnect', (_) {
      onStatus?.call('connected');
    });

    _socket?.on('disconnect', (_) {
      onStatus?.call('disconnected');
    });

    _socket?.on('connect_error', (error) {
      onStatus?.call('error');
      onError?.call(error.toString());
    });

    _socket?.on('error', (error) {
      onStatus?.call('error');
      onError?.call(error.toString());
    });

    final events = [
      'room.created',
      'room.joined',
      'room.ready_updated',
      'room.left',
      'room.closed',
      'round.started',
      'round.phase',
      'round.question_turn',
      'round.question',
      'round.answer',
      'round.all_questions_answered',
      'round.ready_for_voting',
      'round.votes_updated',
      'round.imposter_guess',
      'round.imposter_skip',
      'round.results',
    ];

    for (final eventName in events) {
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
    _socket?.off('disconnect');
    _socket?.off('connect');
    _socket?.off('connect_error');
    for (final eventName in [
      'room.created',
      'room.joined',
      'room.ready_updated',
      'room.left',
      'room.closed',
      'round.started',
      'round.phase',
      'round.question_turn',
      'round.question',
      'round.answer',
      'round.all_questions_answered',
      'round.ready_for_voting',
      'round.votes_updated',
      'round.imposter_guess',
      'round.imposter_skip',
      'round.results',
    ]) {
      _socket?.off(eventName);
    }
    _socket?.disconnect();
    _socket?.close();
    _socket = null;
  }
}
