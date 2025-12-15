import 'package:flutter/material.dart';
import 'package:imposter_app/constants/game_constants.dart';
import 'package:imposter_app/constants/palette.dart';

/// Badge widget displaying WebSocket connection status.
///
/// Shows a colored dot and status text (connected, connecting, offline, error).
class SocketStatusBadge extends StatelessWidget {
  const SocketStatusBadge({
    super.key,
    required this.status,
    this.error,
  });

  final String status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    Color dot;
    String label;
    switch (status) {
      case SocketStatus.connected:
        dot = Palette.success;
        label = 'connected';
        break;
      case SocketStatus.connecting:
        dot = Palette.accent;
        label = 'connecting';
        break;
      case SocketStatus.error:
        dot = Palette.danger;
        label = 'error';
        break;
      default:
        dot = Palette.muted;
        label = 'offline';
    }
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          error != null && status == SocketStatus.error
              ? 'Realtime: $label ($error)'
              : 'Realtime: $label',
          style: const TextStyle(color: Palette.muted, fontSize: 12),
        ),
      ],
    );
  }
}
