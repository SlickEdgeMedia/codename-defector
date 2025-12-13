import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/containers/mission_banner.dart';
import 'package:imposter_app/widgets/containers/mission_panel.dart';
import 'package:provider/provider.dart';

/// Authentication screen for guest login, agent login, and registration.
///
/// This is the entry point when the user is not authenticated.
class MissionBriefingScreen extends StatefulWidget {
  const MissionBriefingScreen({super.key});

  @override
  State<MissionBriefingScreen> createState() => _MissionBriefingScreenState();
}

class _MissionBriefingScreenState extends State<MissionBriefingScreen> {
  bool showLogin = false;
  bool showRegister = false;
  bool showGuest = false;

  final _loginEmail = TextEditingController();
  final _loginPassword = TextEditingController();
  final _regName = TextEditingController();
  final _regEmail = TextEditingController();
  final _regPassword = TextEditingController();
  final _guestName = TextEditingController();

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
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('TOP SECRET', style: TextStyle(color: Palette.gold, letterSpacing: 4)),
                    const SizedBox(height: 8),
                    Text(
                      'IMPOSTER',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 4,
                          ),
                    ),
                    const SizedBox(height: 6),
                    const Text('MISSION BRIEFING', style: TextStyle(color: Palette.muted, letterSpacing: 2)),
                    const SizedBox(height: 24),
                    PrimaryMissionButton(
                      label: 'ENTER AS GUEST',
                      onTap: () => setState(() {
                        showGuest = true;
                        showLogin = false;
                        showRegister = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    SecondaryMissionButton(
                      label: 'AGENT LOGIN',
                      onTap: () => setState(() {
                        showLogin = true;
                        showRegister = false;
                        showGuest = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    SecondaryMissionButton(
                      label: 'NEW REGISTRATION',
                      onTap: () => setState(() {
                        showRegister = true;
                        showLogin = false;
                        showGuest = false;
                      }),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      MissionBanner(text: state.errorMessage!, color: Palette.danger),
                    ],
                    if (showGuest) ...[
                      const SizedBox(height: 16),
                      MissionPanel(
                        title: 'Enter codename',
                        child: Column(
                          children: [
                            TextField(
                              controller: _guestName,
                              decoration: const InputDecoration(labelText: 'Codename'),
                            ),
                            const SizedBox(height: 12),
                            PrimaryMissionButton(
                              label: state.loading ? 'Joining...' : 'Confirm',
                              onTap: state.loading
                                  ? null
                                  : () => state.guestLogin(nickname: _guestName.text.trim()),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (showLogin) ...[
                      const SizedBox(height: 16),
                      MissionPanel(
                        title: 'Agent login',
                        child: Column(
                          children: [
                            TextField(
                              controller: _loginEmail,
                              decoration: const InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _loginPassword,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'Password'),
                            ),
                            const SizedBox(height: 12),
                            PrimaryMissionButton(
                              label: state.loading ? 'Signing in...' : 'Login',
                              onTap: state.loading
                                  ? null
                                  : () => state.login(
                                        email: _loginEmail.text.trim(),
                                        password: _loginPassword.text,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (showRegister) ...[
                      const SizedBox(height: 16),
                      MissionPanel(
                        title: 'Create agent profile',
                        child: Column(
                          children: [
                            TextField(
                              controller: _regName,
                              decoration: const InputDecoration(labelText: 'Name'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _regEmail,
                              decoration: const InputDecoration(labelText: 'Email'),
                            ),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _regPassword,
                              obscureText: true,
                              decoration: const InputDecoration(labelText: 'Password'),
                            ),
                            const SizedBox(height: 12),
                            PrimaryMissionButton(
                              label: state.loading ? 'Registering...' : 'Register',
                              onTap: state.loading
                                  ? null
                                  : () => state.register(
                                        name: _regName.text.trim(),
                                        email: _regEmail.text.trim(),
                                        password: _regPassword.text,
                                      ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
