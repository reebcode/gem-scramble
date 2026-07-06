import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'auth/auth_gate.dart';
import 'core/api_client.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'providers/game_session_provider.dart';
import 'providers/lobby_provider.dart';
import 'providers/match_history_provider.dart';
import 'providers/wallet_provider.dart';
import 'repositories/auth_repository.dart';
import 'repositories/lobby_repository.dart';
import 'repositories/match_repository.dart';
import 'repositories/wallet_repository.dart';
import 'screens/lobby_screen.dart';
import 'screens/results_tab.dart';
import 'screens/settings_screen.dart';
import 'screens/wallet_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase is only needed for production auth; local development uses the
  // backend's dev auth mode.
  if (kReleaseMode) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const GemScrambleApp());
}

/// Composition root: builds the dependency graph explicitly.
///
/// Layering (bottom to top):
///   ApiClient  ->  repositories (data access)  ->  providers (view state)
/// Widgets only ever talk to providers.
class GemScrambleApp extends StatelessWidget {
  const GemScrambleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Core HTTP client (single instance, disposed with the app).
        Provider<ApiClient>(
          create: (_) => ApiClient(),
          dispose: (_, client) => client.dispose(),
        ),

        // Repositories: stateless data access over the ApiClient.
        Provider<AuthRepository>(
          create: (ctx) => AuthRepository(ctx.read<ApiClient>()),
        ),
        Provider<WalletRepository>(
          create: (ctx) => WalletRepository(ctx.read<ApiClient>()),
        ),
        Provider<MatchRepository>(
          create: (ctx) => MatchRepository(ctx.read<ApiClient>()),
        ),
        Provider<LobbyRepository>(
          create: (ctx) => LobbyRepository(ctx.read<ApiClient>()),
        ),

        // Providers: observable view state consumed by widgets.
        ChangeNotifierProvider<AuthProvider>(
          create: (ctx) => AuthProvider(ctx.read<AuthRepository>()),
        ),
        ChangeNotifierProvider<WalletProvider>(
          create: (ctx) => WalletProvider(ctx.read<WalletRepository>()),
        ),
        ChangeNotifierProvider<LobbyProvider>(
          create: (ctx) => LobbyProvider(ctx.read<LobbyRepository>()),
        ),
        ChangeNotifierProvider<GameSessionProvider>(
          create: (ctx) => GameSessionProvider(ctx.read<MatchRepository>()),
        ),
        ChangeNotifierProvider<MatchHistoryProvider>(
          create: (ctx) => MatchHistoryProvider(ctx.read<MatchRepository>()),
        ),
      ],
      child: MaterialApp(
        title: 'Gem Scramble',
        theme: _buildTheme(context),
        home: const AuthGate(),
        routes: {
          '/lobby': (context) => const LobbyScreen(),
          '/wallet': (context) => const WalletScreen(),
        },
      ),
    );
  }

  ThemeData _buildTheme(BuildContext context) {
    const surface = Color(0xFF2A2A2A);
    const gold = Color(0xFFFFD700);

    return ThemeData(
      brightness: Brightness.dark,
      primarySwatch: Colors.amber,
      primaryColor: gold,
      scaffoldBackgroundColor: const Color(0xFF1A1A1A),
      textTheme: GoogleFonts.robotoTextTheme(
        ThemeData(brightness: Brightness.dark).textTheme.apply(
              bodyColor: Colors.white,
              displayColor: Colors.white,
            ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
        contentTextStyle: TextStyle(
          color: Colors.white70,
          fontSize: 16,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: surface,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: surface,
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
      ),
    );
  }
}

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const LobbyScreen(),
    const WalletScreen(),
    const ResultsTab(),
    const SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Kick off wallet loading as soon as the signed-in shell appears.
    context.read<WalletProvider>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        backgroundColor: const Color(0xFF2A2A2A),
        selectedItemColor: const Color(0xFFFFD700),
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Lobby',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.account_balance_wallet),
            label: 'Wallet',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.emoji_events),
            label: 'Results',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
