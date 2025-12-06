import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:imposter_app/config/env.dart';
import 'package:imposter_app/data/api_client.dart';
import 'package:imposter_app/data/auth_repository.dart';
import 'package:imposter_app/data/room_repository.dart';
import 'package:imposter_app/models/room.dart';
import 'package:imposter_app/services/socket_service.dart';
import 'package:imposter_app/state/app_state.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env');

  final env = AppEnv.load();
  final apiClient = ApiClient(env);
  final authRepository = AuthRepository(apiClient);
  final roomRepository = RoomRepository(apiClient);
  final socketService = SocketService(env);
  final prefs = await SharedPreferences.getInstance();

  final appState = AppState(
    authRepository: authRepository,
    roomRepository: roomRepository,
    socketService: socketService,
    prefs: prefs,
  );
  await appState.bootstrap();

  runApp(MyApp(appState: appState));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: appState,
      child: MaterialApp(
        title: 'Imposter',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFF2A93B),
            brightness: Brightness.light,
          ),
          scaffoldBackgroundColor: const Color(0xFFFDF6EC),
          textTheme: Theme.of(context).textTheme.apply(
            fontFamily: 'Roboto',
            bodyColor: const Color(0xFF3E2E1E),
            displayColor: const Color(0xFF3E2E1E),
          ),
          useMaterial3: true,
          inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white.withOpacity(0.9),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFE4D7C5)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: Color(0xFFF2A93B), width: 2),
            ),
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
      builder: (context, state, _) {
        if (state.token == null) {
          return const AuthScreen();
        }
        return const LobbyScreen();
      },
    );
  }
}

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool isRegister = false;

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      body: Stack(
        children: [
          const _Background(),
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Imposter',
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            color: const Color(0xFFE65F2B),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isRegister ? 'Create your crew' : 'Welcome back',
                      style: const TextStyle(color: Color(0xFF6D5240)),
                    ),
                    const SizedBox(height: 20),
                    if (isRegister)
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Name'),
                      ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _emailController,
                      decoration: const InputDecoration(labelText: 'Email'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _passwordController,
                      decoration: const InputDecoration(labelText: 'Password'),
                      obscureText: true,
                    ),
                    const SizedBox(height: 12),
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFE65F2B),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                        onPressed: state.loading
                            ? null
                            : () async {
                                if (isRegister) {
                                  await state.register(
                                    name: _nameController.text.trim(),
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                  );
                                } else {
                                  await state.login(
                                    email: _emailController.text.trim(),
                                    password: _passwordController.text,
                                  );
                                }
                              },
                        child: Text(
                          state.loading
                              ? 'Please wait...'
                              : (isRegister ? 'Register & Play' : 'Login'),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: state.loading
                          ? null
                          : () => setState(() => isRegister = !isRegister),
                      child: Text(
                        isRegister
                            ? 'Have an account? Login'
                            : 'Need an account? Register',
                        style: const TextStyle(color: Color(0xFF9A6E46)),
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

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  final _nicknameController = TextEditingController();
  final _joinCodeController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final room = state.room;

    return Scaffold(
      body: Stack(
        children: [
          const _Background(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: state.loading
                  ? const Center(child: CircularProgressIndicator())
                  : SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Lobby',
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: const Color(0xFFE65F2B),
                                        ),
                                  ),
                                  Text(
                                    'Logged in as: ${state.user?.name ?? ''}',
                                    style: const TextStyle(
                                      color: Color(0xFF6D5240),
                                    ),
                                  ),
                                ],
                              ),
                              TextButton(
                                onPressed: () => state.logout(),
                                child: const Text(
                                  'Logout',
                                  style: TextStyle(color: Color(0xFFD84315)),
                                ),
                              ),
                            ],
                          ),
                          if (state.errorMessage != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, bottom: 8),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFE5E0),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  state.errorMessage!,
                                  style: const TextStyle(
                                    color: Color(0xFFD84315),
                                  ),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          if (room == null) ...[
                            _CardSection(
                              title: 'Create a room',
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _nicknameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Your nickname',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _PrimaryButton(
                                    label: 'Create room',
                                    onPressed: () => state.createRoom(
                                      nickname: _nicknameController.text.trim(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _CardSection(
                              title: 'Join a room',
                              child: Column(
                                children: [
                                  TextField(
                                    controller: _joinCodeController,
                                    decoration: const InputDecoration(
                                      labelText: 'Room code',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  TextField(
                                    controller: _nicknameController,
                                    decoration: const InputDecoration(
                                      labelText: 'Your nickname',
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _PrimaryButton(
                                    label: 'Join room',
                                    onPressed: () => state.joinRoom(
                                      code: _joinCodeController.text.trim(),
                                      nickname: _nicknameController.text.trim(),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ] else ...[
                            _RoomDetails(room: room),
                            const SizedBox(height: 12),
                            if (state.participant != null)
                              SwitchListTile(
                                value: state.participant?.readyAt != null,
                                title: const Text('Ready up'),
                                activeColor: const Color(0xFFE65F2B),
                                onChanged: (value) => state.setReady(value),
                              ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: _PrimaryButton(
                                    label: 'Refresh',
                                    onPressed: () => state.refreshRoom(),
                                    filled: false,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _PrimaryButton(
                                    label: 'Leave room',
                                    onPressed: () => state.leaveRoom(),
                                    filled: false,
                                    color: const Color(0xFFD84315),
                                  ),
                                ),
                              ],
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

class _RoomDetails extends StatelessWidget {
  const _RoomDetails({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return _CardSection(
      title: 'Room ${room.code}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Status: ${room.status}'),
          const SizedBox(height: 8),
          const Text('Players'),
          const SizedBox(height: 4),
          ...room.participants.map(
            (p) => Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 6,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: p.isHost
                          ? const Color(0xFFEFE3D8)
                          : const Color(0xFFF6F1E7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      p.isHost ? Icons.star : Icons.person,
                      color: const Color(0xFFE65F2B),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.nickname,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        Text(
                          p.isHost ? 'Host' : 'Player',
                          style: const TextStyle(
                            color: Color(0xFF8A7765),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (p.readyAt != null)
                    const Icon(Icons.check_circle, color: Colors.green)
                  else
                    const Icon(Icons.hourglass_empty, color: Color(0xFFE65F2B)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CardSection extends StatelessWidget {
  const _CardSection({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF3E2E1E),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.onPressed,
    this.filled = true,
    this.color,
  });

  final String label;
  final VoidCallback onPressed;
  final bool filled;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final bg = color ?? const Color(0xFFE65F2B);
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: filled ? bg : Colors.white,
          foregroundColor: filled ? Colors.white : bg,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: bg, width: 1.5),
          ),
        ),
        onPressed: onPressed,
        child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}

class _Background extends StatelessWidget {
  const _Background();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFFEECDC), Color(0xFFFFF7EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}
