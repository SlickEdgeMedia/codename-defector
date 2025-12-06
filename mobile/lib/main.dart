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
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.orangeAccent),
          useMaterial3: true,
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
      appBar: AppBar(title: const Text('Imposter Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isRegister)
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            const SizedBox(height: 12),
            if (state.errorMessage != null)
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
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
              child: Text(isRegister ? 'Register' : 'Login'),
            ),
            TextButton(
              onPressed: state.loading
                  ? null
                  : () => setState(() => isRegister = !isRegister),
              child: Text(
                isRegister
                    ? 'Have an account? Login'
                    : 'Need an account? Register',
              ),
            ),
          ],
        ),
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
      appBar: AppBar(
        title: const Text('Lobby'),
        actions: [
          TextButton(
            onPressed: () => state.logout(),
            child: const Text('Logout'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: state.loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (state.errorMessage != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          state.errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    Text('Logged in as: ${state.user?.name ?? ''}'),
                    const SizedBox(height: 12),
                    if (room == null) ...[
                      const Text('Create a room'),
                      TextField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: 'Your nickname',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          state.createRoom(
                            nickname: _nicknameController.text.trim(),
                          );
                        },
                        child: const Text('Create room'),
                      ),
                      const Divider(height: 32),
                      const Text('Join a room'),
                      TextField(
                        controller: _joinCodeController,
                        decoration: const InputDecoration(
                          labelText: 'Room code',
                        ),
                      ),
                      TextField(
                        controller: _nicknameController,
                        decoration: const InputDecoration(
                          labelText: 'Your nickname',
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          state.joinRoom(
                            code: _joinCodeController.text.trim(),
                            nickname: _nicknameController.text.trim(),
                          );
                        },
                        child: const Text('Join room'),
                      ),
                    ] else ...[
                      _RoomDetails(room: room),
                      const SizedBox(height: 12),
                      if (state.participant != null)
                        SwitchListTile(
                          value: state.participant?.readyAt != null,
                          title: const Text('Ready'),
                          onChanged: (value) => state.setReady(value),
                        ),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () => state.refreshRoom(),
                        child: const Text('Refresh'),
                      ),
                      TextButton(
                        onPressed: () => state.leaveRoom(),
                        child: const Text('Leave room'),
                      ),
                    ],
                  ],
                ),
              ),
      ),
    );
  }
}

class _RoomDetails extends StatelessWidget {
  const _RoomDetails({required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Room code: ${room.code}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text('Status: ${room.status}'),
            const SizedBox(height: 8),
            const Text('Participants:'),
            ...room.participants.map(
              (p) => ListTile(
                dense: true,
                title: Text(p.nickname),
                subtitle: Text(p.isHost ? 'Host' : 'Player'),
                trailing: p.readyAt != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.hourglass_empty),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
