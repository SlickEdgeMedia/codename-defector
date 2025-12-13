import 'package:flutter/material.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:imposter_app/widgets/buttons/primary_mission_button.dart';
import 'package:imposter_app/widgets/buttons/secondary_mission_button.dart';
import 'package:imposter_app/widgets/containers/mission_banner.dart';
import 'package:imposter_app/widgets/containers/mission_panel.dart';
import 'package:provider/provider.dart';

/// Room setup screen for creating or joining a mission.
///
/// Allows the user to host a new room or join an existing one with a room code.
class MissionSetupScreen extends StatefulWidget {
  const MissionSetupScreen({super.key});

  @override
  State<MissionSetupScreen> createState() => _MissionSetupScreenState();
}

class _MissionSetupScreenState extends State<MissionSetupScreen> {
  final _hostCodename = TextEditingController();
  final _joinCodename = TextEditingController();
  final _joinCode = TextEditingController();
  String _category = 'countries';
  double _durationMinutes = 10;
  int _categoryIndex = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final state = context.watch<AppState>();
    // Pre-fill nickname from user or guest login
    final defaultNickname = state.user?.name ?? state.guestNickname ?? '';
    if (_hostCodename.text.isEmpty && defaultNickname.isNotEmpty) {
      _hostCodename.text = defaultNickname;
    }
    if (_joinCodename.text.isEmpty && defaultNickname.isNotEmpty) {
      _joinCodename.text = defaultNickname;
    }
  }

  List<Map<String, String>> get categories => const [
        {'slug': 'countries', 'label': 'Countries'},
        {'slug': 'animals', 'label': 'Animals'},
        {'slug': 'food', 'label': 'Food'},
        {'slug': 'objects', 'label': 'Objects'},
        {'slug': 'brands', 'label': 'Brands'},
      ];

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.bg,
        elevation: 0,
        title: const Text('THE SPY'),
        actions: [
          TextButton(
            onPressed: () => state.logout(),
            child: const Text('Logout', style: TextStyle(color: Palette.gold)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (state.errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MissionBanner(text: state.errorMessage!, color: Palette.danger),
              ),
            Column(
              children: [
                MissionPanel(
                  title: 'Host mission',
                  subtitle: 'Configure operation parameters',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 6),
                      const Text('Agent codename', style: TextStyle(color: Palette.muted)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _hostCodename,
                        decoration: const InputDecoration(labelText: 'Codename'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Mission category', style: TextStyle(color: Palette.muted)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _categoryIndex = (_categoryIndex - 1 + categories.length) % categories.length;
                                _category = categories[_categoryIndex]['slug']!;
                              });
                            },
                            icon: const Icon(Icons.chevron_left, color: Palette.gold),
                          ),
                          Expanded(
                            child: Center(
                              child: Text(
                                categories[_categoryIndex]['label']!,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _categoryIndex = (_categoryIndex + 1) % categories.length;
                                _category = categories[_categoryIndex]['slug']!;
                              });
                            },
                            icon: const Icon(Icons.chevron_right, color: Palette.gold),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Mission duration', style: TextStyle(color: Palette.muted)),
                          Text('${_durationMinutes.toInt()} min'),
                        ],
                      ),
                      Slider(
                        value: _durationMinutes,
                        min: 5,
                        max: 15,
                        divisions: 10,
                        onChanged: (v) => setState(() => _durationMinutes = v),
                      ),
                      const SizedBox(height: 12),
                      PrimaryMissionButton(
                        label: state.loading ? 'Creating...' : 'Create mission',
                        onTap: state.loading
                            ? null
                            : () => state.createRoom(
                                  nickname: _hostCodename.text.trim(),
                                  category: _category,
                                  roundDurationSeconds: (_durationMinutes * 60).toInt(),
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                MissionPanel(
                  title: 'Join mission',
                  subtitle: 'Enter access code',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _joinCode,
                        decoration: const InputDecoration(labelText: 'Access code'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _joinCodename,
                        decoration: const InputDecoration(labelText: 'Codename'),
                      ),
                      const SizedBox(height: 12),
                      SecondaryMissionButton(
                        label: state.loading ? 'Joining...' : 'Join mission',
                        onTap: state.loading
                            ? null
                            : () => state.joinRoom(
                                  code: _joinCode.text.trim(),
                                  nickname: _joinCodename.text.trim(),
                                ),
                      ),
                    ],
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
