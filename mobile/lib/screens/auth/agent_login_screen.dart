import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/containers/mission_banner.dart';
import 'package:imposter_app/widgets/containers/mission_panel.dart';
import 'package:provider/provider.dart';

/// Agent login screen for authenticated users.
class AgentLoginScreen extends StatefulWidget {
  const AgentLoginScreen({super.key});

  @override
  State<AgentLoginScreen> createState() => _AgentLoginScreenState();
}

class _AgentLoginScreenState extends State<AgentLoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();

  @override
  void initState() {
    super.initState();
    _email.addListener(() => setState(() {}));
    _password.addListener(() => setState(() {}));
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
                    icon: const Icon(Icons.arrow_back, color: Palette.gold),
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
                            'CLASSIFIED',
                            style: TextStyle(
                              color: Palette.gold,
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
                            'AGENT LOGIN',
                            style: TextStyle(color: Palette.muted, letterSpacing: 2),
                          ),
                          const SizedBox(height: 32),
                          MissionPanel(
                            title: 'Credentials',
                            child: Column(
                              children: [
                                TextField(
                                  controller: _email,
                                  autofocus: true,
                                  keyboardType: TextInputType.emailAddress,
                                  decoration: const InputDecoration(
                                    labelText: 'Email',
                                  ),
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _password,
                                  obscureText: true,
                                  decoration: const InputDecoration(
                                    labelText: 'Password',
                                  ),
                                  onSubmitted: (_) async {
                                    if (_email.text.trim().isNotEmpty &&
                                        _password.text.isNotEmpty &&
                                        !state.loading) {
                                      await state.login(
                                        email: _email.text.trim(),
                                        password: _password.text,
                                      );
                                      if (mounted && state.token != null) {
                                        Navigator.pop(context);
                                      }
                                    }
                                  },
                                ),
                                const SizedBox(height: 16),
                                PrimaryMissionButton(
                                  label: state.loading ? 'Authenticating...' : 'Login',
                                  onTap: state.loading ||
                                          _email.text.trim().isEmpty ||
                                          _password.text.isEmpty
                                      ? null
                                      : () async {
                                          await state.login(
                                            email: _email.text.trim(),
                                            password: _password.text,
                                          );
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
    _email.dispose();
    _password.dispose();
    super.dispose();
  }
}
