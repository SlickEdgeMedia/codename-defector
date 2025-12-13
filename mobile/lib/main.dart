import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:imposter_app/config/env.dart';
import 'package:imposter_app/constants/palette.dart';
import 'package:imposter_app/data/api_client.dart';
import 'package:imposter_app/data/auth_repository.dart';
import 'package:imposter_app/data/room_repository.dart';
import 'package:imposter_app/data/round_repository.dart';
import 'package:imposter_app/screens/auth/mission_briefing_screen.dart';
import 'package:imposter_app/screens/lobby/mission_lobby_screen.dart';
import 'package:imposter_app/screens/round/round_phase_screen.dart';
import 'package:imposter_app/screens/setup/mission_setup_screen.dart';
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

