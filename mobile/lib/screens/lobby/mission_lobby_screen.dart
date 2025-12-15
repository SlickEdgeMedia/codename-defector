import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:imposter_app/constants/avatars.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/containers/mission_banner.dart';
import 'package:imposter_app/widgets/containers/mission_panel.dart';
import 'package:imposter_app/widgets/indicators/socket_status_badge.dart';
import 'package:provider/provider.dart';

/// Lobby screen showing participants waiting for the round to start.
///
/// Displays room participants, ready status, and allows the host to start the round.
class MissionLobbyScreen extends StatelessWidget {
  const MissionLobbyScreen({super.key});

  bool _everyoneReady(Room room) => room.participants.every((p) => p.readyAt != null);

  // Assign a consistent avatar based on participant ID
  SpyAvatar _getAvatarForParticipant(int participantId) {
    final avatars = SpyAvatar.values;
    return avatars[participantId % avatars.length];
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final room = state.room!;
    final isHost = state.participant?.isHost ?? false;
    final canStart = isHost && room.participants.length >= 3 && _everyoneReady(room);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.bg,
        elevation: 0,
        title: const Text('LOBBY'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: SocketStatusBadge(status: state.socketStatus, error: state.socketError),
          ),
          TextButton(
            onPressed: () => state.logout(),
            child: const Text('Logout', style: TextStyle(color: Palette.accent)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MissionBanner(text: state.errorMessage!, color: Palette.danger),
              ),
            MissionPanel(
              title: 'Safehouse ${room.code}',
              subtitle: 'Status: ${room.status}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Access code', style: TextStyle(color: Palette.muted)),
                      const SizedBox(width: 8),
                      Text(room.code, style: const TextStyle(fontWeight: FontWeight.bold)),
                      IconButton(
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: room.code));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Code copied')),
                            );
                          }
                        },
                        icon: const Icon(Icons.copy, size: 18, color: Palette.accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Agents (${room.participants.length}/${room.maxPlayers})',
                    style: const TextStyle(color: Palette.muted),
                  ),
                  const SizedBox(height: 8),
                  ...room.participants.map((p) {
                    final ready = p.readyAt != null;
                    final avatar = _getAvatarForParticipant(p.id);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      decoration: BoxDecoration(
                        color: Palette.panel,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Palette.stroke),
                      ),
                      child: Row(
                        children: [
                          AvatarIcon(
                            avatar: avatar,
                            size: 40,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p.nickname, style: const TextStyle(fontWeight: FontWeight.w700)),
                                Text(
                                  p.isHost ? 'Host' : 'Agent',
                                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            ready ? Icons.check_circle : Icons.hourglass_bottom,
                            color: ready ? Palette.success : Palette.muted,
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
            const SizedBox(height: 14),
            MissionPanel(
              title: 'Status',
              subtitle: isHost ? 'Awaiting agents' : 'Standby',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: state.participant?.readyAt != null,
                    onChanged: (v) => state.setReady(v),
                    activeThumbColor: Palette.accent,
                    activeTrackColor: Palette.accent.withOpacity(0.5),
                    title: const Text('Ready up'),
                  ),
                  const SizedBox(height: 8),
                  if (isHost)
                    PrimaryMissionButton(
                      label: 'Start mission',
                      onTap: canStart ? () => state.startRound() : null,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: SecondaryMissionButton(
                    label: 'Refresh',
                    onTap: () => state.refreshRoom(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: SecondaryMissionButton(
                    label: 'Leave safehouse',
                    onTap: () => state.leaveRoom(),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
