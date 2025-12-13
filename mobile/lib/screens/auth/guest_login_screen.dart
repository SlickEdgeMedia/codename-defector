import 'package:flutter/material.dart';
import 'package:imposter_app/constants/avatars.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/avatar_selector.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/containers/mission_banner.dart';
import 'package:imposter_app/widgets/containers/mission_panel.dart';
import 'package:provider/provider.dart';

/// Guest login screen for entering codename and joining as guest.
class GuestLoginScreen extends StatefulWidget {
  const GuestLoginScreen({super.key});

  @override
  State<GuestLoginScreen> createState() => _GuestLoginScreenState();
}

class _GuestLoginScreenState extends State<GuestLoginScreen> {
  final _guestName = TextEditingController();
  SpyAvatar _selectedAvatar = SpyAvatar.agent;

  @override
  void initState() {
    super.initState();
    _guestName.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0A0B11), Color(0xFF0F1119)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Back button
                Align(
                  alignment: Alignment.topLeft,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_back, color: Palette.accent),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                // Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'GUEST ACCESS',
                            style: TextStyle(
                              color: Palette.accent,
                              letterSpacing: 4,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'THE SPY',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 4,
                                ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'ENTER CODENAME',
                            style: TextStyle(color: Palette.muted, letterSpacing: 2),
                          ),
                          const SizedBox(height: 32),
                          MissionPanel(
                            title: 'Codename',
                            child: Column(
                              children: [
                                TextField(
                                  controller: _guestName,
                                  autofocus: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Enter your codename',
                                    hintText: 'Agent007',
                                  ),
                                  onSubmitted: (_) async {
                                    if (_guestName.text.trim().isNotEmpty && !state.loading) {
                                      await state.guestLogin(nickname: _guestName.text.trim());
                                      if (mounted && state.token != null) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(height: 20),
                                AvatarSelector(
                                  selectedAvatar: _selectedAvatar,
                                  onAvatarSelected: (avatar) {
                                    setState(() {
                                      _selectedAvatar = avatar;
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),
                                PrimaryMissionButton(
                                  label: state.loading ? 'Joining...' : 'Confirm',
                                  onTap: state.loading || _guestName.text.trim().isEmpty
                                      ? null
                                      : () async {
                                          await state.guestLogin(nickname: _guestName.text.trim());
                                          if (mounted && state.token != null) {
                                            Navigator.pop(context);
                                          }
                                        },
                                ),
                              ],
                            ),
                          ),
                          if (state.errorMessage != null) ...[
                            const SizedBox(height: 16),
                            MissionBanner(text: state.errorMessage!, color: Palette.danger),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _guestName.dispose();
    super.dispose();
  }
}
