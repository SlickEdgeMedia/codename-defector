import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/screens/auth/agent_login_screen.dart';
import 'package:imposter_app/screens/auth/agent_register_screen.dart';
import 'package:imposter_app/screens/auth/guest_login_screen.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';

/// Authentication screen for guest login, agent login, and registration.
///
/// This is the entry point when the user is not authenticated.
class MissionBriefingScreen extends StatefulWidget {
  const MissionBriefingScreen({super.key});

  @override
  State<MissionBriefingScreen> createState() => _MissionBriefingScreenState();
}

class _MissionBriefingScreenState extends State<MissionBriefingScreen> {

  @override
  Widget build(BuildContext context) {
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
                      'THE SPY',
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
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const GuestLoginScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SecondaryMissionButton(
                      label: 'AGENT LOGIN',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AgentLoginScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SecondaryMissionButton(
                      label: 'NEW REGISTRATION',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const AgentRegisterScreen()),
                      ),
                    ),
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
