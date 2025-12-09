import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:imposter_app/config/env.dart';
import 'package:imposter_app/data/api_client.dart';
import 'package:imposter_app/data/auth_repository.dart';
import 'package:imposter_app/data/room_repository.dart';
import 'package:imposter_app/data/round_repository.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/models/round_models.dart';
import 'package:imposter_app/services/socket_service.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');
  GoogleFonts.config.allowRuntimeFetching = false;

  final env = AppEnv.load();
  final apiClient = ApiClient(env);
  final authRepository = AuthRepository(apiClient);
  final roomRepository = RoomRepository(apiClient);
  final roundRepository = RoundRepository(apiClient);
  final socketService = SocketService(env);
  final prefs = await SharedPreferences.getInstance();

  final appState = AppState(
    authRepository: authRepository,
    roomRepository: roomRepository,
    roundRepository: roundRepository,
    socketService: socketService,
    prefs: prefs,
  );
  await appState.bootstrap();

  runApp(MyApp(appState: appState));
}

class Palette {
  static const Color bg = Color(0xFF0B0C10);
  static const Color panel = Color(0xFF12131A);
  static const Color gold = Color(0xFFD4A019);
  static const Color goldDark = Color(0xFF9C7614);
  static const Color text = Color(0xFFF5F5F5);
  static const Color muted = Color(0xFF9EA2AF);
  static const Color success = Color(0xFF3CD070);
  static const Color danger = Color(0xFFFF4E50);
  static const Color stroke = Color(0xFF1E202A);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    final baseText = GoogleFonts.orbitronTextTheme(
      Theme.of(context).textTheme,
    ).apply(bodyColor: Palette.text, displayColor: Palette.text);

    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'Imposter',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Palette.gold,
            brightness: Brightness.dark,
            surface: Palette.bg,
          ),
          scaffoldBackgroundColor: Palette.bg,
          textTheme: baseText,
          useMaterial3: true,
          sliderTheme: SliderThemeData(
            activeTrackColor: Palette.gold,
            thumbColor: Palette.gold,
            inactiveTrackColor: Palette.stroke,
          ),
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Palette.panel,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Palette.stroke),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: const BorderSide(color: Palette.gold, width: 2),
            ),
            labelStyle: const TextStyle(color: Palette.muted),
          ),
        ),
        home: const HomeSwitcher(),
      ),
    );
  }
}

class HomeSwitcher extends StatelessWidget {
  const HomeSwitcher({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AppState>(
      builder: (context, state, child) {
        if (state.token == null) return const MissionBriefingScreen();

        if (state.room == null) return const MissionSetupScreen();

        if (state.activeRoundId != null && state.showRound) {
          return const RoundPhaseScreen();
        }

        return const MissionLobbyScreen();
      },
    );
  }
}

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
                    _PrimaryMissionButton(
                      label: 'ENTER AS GUEST',
                      onTap: () => setState(() {
                        showGuest = true;
                        showLogin = false;
                        showRegister = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _SecondaryMissionButton(
                      label: 'AGENT LOGIN',
                      onTap: () => setState(() {
                        showLogin = true;
                        showRegister = false;
                        showGuest = false;
                      }),
                    ),
                    const SizedBox(height: 12),
                    _SecondaryMissionButton(
                      label: 'NEW REGISTRATION',
                      onTap: () => setState(() {
                        showRegister = true;
                        showLogin = false;
                        showGuest = false;
                      }),
                    ),
                    if (state.errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _Banner(text: state.errorMessage!, color: Palette.danger),
                    ],
                    if (showGuest) ...[
                      const SizedBox(height: 16),
                      _MissionPanel(
                        title: 'Enter codename',
                        child: Column(
                          children: [
                            TextField(
                              controller: _guestName,
                              decoration: const InputDecoration(labelText: 'Codename'),
                            ),
                            const SizedBox(height: 12),
                            _PrimaryMissionButton(
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
                      _MissionPanel(
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
                            _PrimaryMissionButton(
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
                      _MissionPanel(
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
                            _PrimaryMissionButton(
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
        title: const Text('IMPOSTER'),
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
                child: _Banner(text: state.errorMessage!, color: Palette.danger),
              ),
            Column(
              children: [
                _MissionPanel(
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
                      _PrimaryMissionButton(
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
                _MissionPanel(
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
                      _SecondaryMissionButton(
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

class MissionLobbyScreen extends StatelessWidget {
  const MissionLobbyScreen({super.key});

  bool _everyoneReady(Room room) => room.participants.every((p) => p.readyAt != null);

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
            child: _SocketStatusBadge(status: state.socketStatus, error: state.socketError),
          ),
          TextButton(
            onPressed: () => state.logout(),
            child: const Text('Logout', style: TextStyle(color: Palette.gold)),
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
                child: _Banner(text: state.errorMessage!, color: Palette.danger),
              ),
            _MissionPanel(
              title: 'Room ${room.code}',
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
                        icon: const Icon(Icons.copy, size: 18, color: Palette.gold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('Agents', style: TextStyle(color: Palette.muted)),
                  const SizedBox(height: 8),
                  ...room.participants.map((p) {
                    final ready = p.readyAt != null;
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
                          CircleAvatar(
                            backgroundColor: Palette.gold.withAlpha(51),
                            foregroundColor: Palette.gold,
                            child: Text(
                              p.nickname.isNotEmpty ? p.nickname[0].toUpperCase() : 'A',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
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
            _MissionPanel(
              title: 'Status',
              subtitle: isHost ? 'Awaiting agents' : 'Standby',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    value: state.participant?.readyAt != null,
                    onChanged: (v) => state.setReady(v),
                    activeThumbColor: Palette.gold,
                    title: const Text('Ready up'),
                  ),
                  const SizedBox(height: 8),
                  if (isHost)
                    _PrimaryMissionButton(
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
                  child: _SecondaryMissionButton(
                    label: 'Refresh',
                    onTap: () => state.refreshRoom(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SecondaryMissionButton(
                    label: 'Leave mission',
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

class RoundPhaseScreen extends StatefulWidget {
  const RoundPhaseScreen({super.key});

  @override
  State<RoundPhaseScreen> createState() => _RoundPhaseScreenState();
}

class _RoundPhaseScreenState extends State<RoundPhaseScreen> {
  int? _voteTarget;
  final _questionText = TextEditingController();
  int? _questionTarget;
  final Map<int, TextEditingController> _answerControllers = {};
  int? _lastQuestionId;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final role = state.roundRole;
    final room = state.room;
    if (role == null || room == null) {
      return const MissionLobbyScreen();
    }

    if (_lastQuestionId != state.currentQuestionId) {
      _lastQuestionId = state.currentQuestionId;
      _questionText.clear();
      _questionTarget = null;
    }

    final phase = state.roundPhase;
    final isImposter = role.isImposter;
    final title = () {
      switch (phase) {
        case 'countdown':
          return 'MISSION COUNTDOWN';
        case 'question':
          return 'MISSION QUESTIONS';
        case 'voting':
          return 'MISSION VOTING';
        case 'results':
          return 'MISSION RESULTS';
        default:
          return 'MISSION ROLE';
      }
    }();

    Widget phaseBody;
    switch (phase) {
      case 'countdown':
        phaseBody = _CountdownPhase(seconds: state.countdownSeconds);
        break;
      case 'question':
        phaseBody = _QuestionPhase(
          room: room,
          state: state,
          questionTarget: _questionTarget,
          onTargetChanged: (id) => setState(() => _questionTarget = id),
          questionText: _questionText,
          answerControllers: _answerControllers,
        );
        break;
      case 'voting':
        phaseBody = _VotingPhase(
          room: room,
          state: state,
          voteTarget: _voteTarget,
          onVote: (id) {
            setState(() => _voteTarget = id);
            state.submitVote(id);
          },
        );
        break;
      case 'results':
        phaseBody = _ResultsPhase(state: state);
        break;
      case 'role':
      default:
        phaseBody = _RolePhase(role: role, state: state, isImposter: isImposter);
    }

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Palette.bg,
        elevation: 0,
        title: Text(title, style: const TextStyle(letterSpacing: 2)),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: _SocketStatusBadge(status: state.socketStatus, error: state.socketError),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _RoleStrip(
              role: role,
              agentName: state.participant?.nickname ?? state.user?.name ?? '',
            ),
            const SizedBox(height: 8),
            _PhaseHeader(
              roundNumber: role.roundNumber,
              code: room.code,
              missionSeconds: state.missionSeconds,
              phase: phase,
            ),
            const SizedBox(height: 12),
            Expanded(child: phaseBody),
          ],
        ),
      ),
    );
  }
}

class _RoleStrip extends StatelessWidget {
  const _RoleStrip({required this.role, required this.agentName});

  final RoundRoleInfo role;
  final String agentName;

  @override
  Widget build(BuildContext context) {
    final isImposter = role.isImposter;
    final accent = isImposter ? Palette.danger : Palette.success;
    final subtitle = isImposter
        ? 'Blend in and identify the word'
        : (role.word != null ? 'Word: ${role.word}' : 'Civilian');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.stroke),
      ),
      child: Row(
        children: [
          Icon(isImposter ? Icons.visibility_off : Icons.shield_moon, color: accent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AGENT: ${agentName.isNotEmpty ? agentName : 'UNKNOWN'}',
                  style: const TextStyle(color: Palette.muted, fontSize: 12, letterSpacing: 1),
                ),
                const SizedBox(height: 2),
                Text(
                  isImposter ? 'IMPOSTER' : 'CIVILIAN',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: accent,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RolePhase extends StatelessWidget {
  const _RolePhase({required this.role, required this.state, required this.isImposter});

  final RoundRoleInfo role;
  final AppState state;
  final bool isImposter;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isImposter ? 'IMPOSTER' : 'CIVILIAN',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: isImposter ? Palette.danger : Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Text('Category: ${role.category}', style: const TextStyle(color: Palette.muted)),
          const SizedBox(height: 24),
          if (!isImposter)
            _MissionCard(
              title: 'CLASSIFIED WORD',
              value: role.word ?? 'Unknown',
              actionLabel: 'Conceal word',
            )
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('POSSIBLE TARGETS', style: TextStyle(color: Palette.muted)),
                const SizedBox(height: 10),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 280),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const AlwaysScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.2,
                    ),
                    itemCount: role.wordOptions.length,
                    itemBuilder: (context, index) {
                      final w = role.wordOptions[index];
                      final crossed = state.crossedWords.contains(w.text);
                      return GestureDetector(
                        onTap: () => state.toggleCrossedWord(w.text),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: Palette.stroke,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: crossed ? Palette.danger : Palette.stroke,
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  w.text,
                                  style: TextStyle(
                                    decoration: crossed ? TextDecoration.lineThrough : TextDecoration.none,
                                    color: crossed ? Palette.muted : Palette.text,
                                  ),
                                ),
                              ),
                              if (crossed)
                                const Icon(Icons.close, size: 16, color: Palette.danger),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CountdownPhase extends StatelessWidget {
  const _CountdownPhase({required this.seconds});
  final int seconds;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('MISSION COMMENCING', style: TextStyle(color: Palette.muted, letterSpacing: 2)),
          const SizedBox(height: 12),
          Text(
            seconds.clamp(0, 99).toString(),
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  color: Palette.gold,
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          const Text('Prepare for deployment', style: TextStyle(color: Palette.muted)),
        ],
      ),
    );
  }
}

class _QuestionPhase extends StatelessWidget {
  const _QuestionPhase({
    required this.room,
    required this.state,
    required this.questionTarget,
    required this.onTargetChanged,
    required this.questionText,
    required this.answerControllers,
  });

  final Room room;
  final AppState state;
  final int? questionTarget;
  final void Function(int?) onTargetChanged;
  final TextEditingController questionText;
  final Map<int, TextEditingController> answerControllers;

  @override
  Widget build(BuildContext context) {
    final participant = state.participant;
    final askerId = state.currentAskerId;
    final asker = askerId != null
        ? room.participants.firstWhere(
            (p) => p.id == askerId,
            orElse: () => participant ?? room.participants.first,
          )
        : null;
    final isMyTurn = askerId != null && askerId == participant?.id;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: isMyTurn ? 'Your turn to interrogate' : 'Waiting for next agent'),
          const SizedBox(height: 8),
          if (state.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _Banner(text: state.errorMessage!, color: Palette.danger),
            ),
          if (!isMyTurn)
            Text(
              asker != null ? 'Agent ${asker.nickname} is asking' : 'Turn order not started',
              style: const TextStyle(color: Palette.muted),
            ),
          if (!isMyTurn) const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: questionTarget,
            hint: const Text('Select target'),
            items: room.participants
                .where((p) => p.id != participant?.id)
                .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nickname)))
                .toList(),
            onChanged: (!isMyTurn || state.askedQuestion) ? null : onTargetChanged,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: questionText,
            maxLines: 2,
            decoration: const InputDecoration(labelText: 'Your question'),
            enabled: isMyTurn && !state.askedQuestion,
          ),
          const SizedBox(height: 8),
          _PrimaryMissionButton(
            label: state.askedQuestion ? 'Question sent' : 'Submit question',
            onTap: state.askedQuestion || questionTarget == null || !isMyTurn
                ? null
                : () => state.askQuestion(
                      targetId: questionTarget!,
                      text: questionText.text.trim(),
                    ),
          ),
          const SizedBox(height: 20),
          _SectionHeader(label: 'Answer queue'),
          const SizedBox(height: 8),
          if (state.pendingQuestions.isEmpty)
            const Text('No pending questions for you.', style: TextStyle(color: Palette.muted))
          else
            Column(
              children: state.pendingQuestions.map((q) {
                final ctrl = answerControllers.putIfAbsent(q.id, () => TextEditingController());
                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Palette.panel,
                    border: Border.all(color: Palette.stroke),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('From: ${q.askerName ?? 'Agent'}'),
                      const SizedBox(height: 4),
                      Text(q.text),
                      const SizedBox(height: 6),
                      TextField(
                        controller: ctrl,
                        decoration: const InputDecoration(labelText: 'Your answer'),
                      ),
                      const SizedBox(height: 6),
                      _SecondaryMissionButton(
                        label: 'Submit answer',
                        onTap: () => state.answerQuestion(
                          questionId: q.id,
                          text: ctrl.text.trim(),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }
}

class _VotingPhase extends StatelessWidget {
  const _VotingPhase({
    required this.room,
    required this.state,
    required this.voteTarget,
    required this.onVote,
  });

  final Room room;
  final AppState state;
  final int? voteTarget;
  final void Function(int) onVote;

  @override
  Widget build(BuildContext context) {
    final participant = state.participant;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'Identify imposter'),
          const SizedBox(height: 8),
          Column(
            children: room.participants
                .where((p) => p.id != participant?.id)
                .map(
                  (p) {
                    final votes = state.voteTotals[p.id] ?? 0;
                    final selected = voteTarget == p.id;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? Palette.gold.withAlpha(20) : Palette.panel,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: selected ? Palette.gold : Palette.stroke),
                      ),
                      child: ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: Palette.gold.withAlpha(40),
                          child: Text(
                            p.nickname.isNotEmpty ? p.nickname.substring(0, 2).toUpperCase() : '?',
                            style: const TextStyle(color: Palette.text),
                          ),
                        ),
                        title: Text(p.nickname),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.how_to_vote, color: Palette.muted, size: 16),
                            const SizedBox(width: 6),
                            Text(votes.toString()),
                          ],
                        ),
                        onTap: state.voted ? null : () => onVote(p.id),
                      ),
                    );
                  },
                )
                .toList(),
          ),
          if (state.voted)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Vote submitted', style: TextStyle(color: Palette.success)),
            ),
          const SizedBox(height: 12),
          const Text('Tally updates in realtime', style: TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _ResultsPhase extends StatelessWidget {
  const _ResultsPhase({required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final results = state.roundResults;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionHeader(label: 'Mission outcome'),
          const SizedBox(height: 8),
          _SecondaryMissionButton(
            label: 'Refresh results',
            onTap: () => state.fetchResults(),
          ),
          const SizedBox(height: 10),
          if (results == null)
            const Text('Awaiting scoring...', style: TextStyle(color: Palette.muted))
          else
            Column(
              children: results.scores
                  .map(
                    (s) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: Palette.gold.withAlpha(51),
                        child: Text(s.points.toString(), style: const TextStyle(color: Palette.text)),
                      ),
                      title: Text(s.nickname),
                      subtitle: Text(s.reason),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label, style: const TextStyle(letterSpacing: 1.5, color: Palette.muted));
  }
}

class _PhaseHeader extends StatelessWidget {
  const _PhaseHeader({
    required this.roundNumber,
    required this.code,
    required this.missionSeconds,
    required this.phase,
  });

  final int roundNumber;
  final String code;
  final int? missionSeconds;
  final String phase;

  String _format(int? seconds) {
    if (seconds == null || seconds < 0) return '--:--';
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('ROUND', style: TextStyle(color: Palette.muted, fontSize: 12)),
            Text(
              roundNumber.toString().padLeft(2, '0'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              phase == 'countdown' ? 'MISSION TIMER' : 'TIME LEFT',
              style: const TextStyle(color: Palette.muted, fontSize: 12),
            ),
            Text(
              _format(missionSeconds),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: Palette.danger,
                  ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const Text('CODE', style: TextStyle(color: Palette.muted, fontSize: 12)),
            Text(code, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      ],
    );
  }
}

class _MissionPanel extends StatelessWidget {
  const _MissionPanel({required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: const TextStyle(color: Palette.muted)),
          ],
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PrimaryMissionButton extends StatelessWidget {
  const _PrimaryMissionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: onTap == null ? Palette.goldDark : Palette.gold,
          foregroundColor: Palette.text,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _SecondaryMissionButton extends StatelessWidget {
  const _SecondaryMissionButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          side: const BorderSide(color: Palette.gold, width: 1.5),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          foregroundColor: Palette.gold,
        ),
        onPressed: onTap,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }
}

class _SocketStatusBadge extends StatelessWidget {
  const _SocketStatusBadge({required this.status, this.error});

  final String status;
  final String? error;

  @override
  Widget build(BuildContext context) {
    Color dot;
    String label;
    switch (status) {
      case 'connected':
        dot = Palette.success;
        label = 'connected';
        break;
      case 'connecting':
        dot = Palette.gold;
        label = 'connecting';
        break;
      case 'error':
        dot = Palette.danger;
        label = 'error';
        break;
      default:
        dot = Palette.muted;
        label = 'offline';
    }
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(
          error != null && status == 'error' ? 'Realtime: $label (${error!})' : 'Realtime: $label',
          style: const TextStyle(color: Palette.muted, fontSize: 12),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, this.color = Palette.gold});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color),
      ),
      child: Text(text, style: TextStyle(color: color)),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.title, required this.value, required this.actionLabel});

  final String title;
  final String value;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Palette.bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.stroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Palette.muted)),
          const SizedBox(height: 8),
          Text(
            value.toUpperCase(),
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800, color: Palette.gold),
          ),
          const SizedBox(height: 10),
          Text(actionLabel, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ],
      ),
    );
  }
}
