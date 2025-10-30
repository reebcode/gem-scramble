import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'screens/lobby_screen.dart';
import 'screens/wallet_screen.dart';
import 'screens/results_tab.dart';
import 'screens/settings_screen.dart';
import 'services/wallet_service.dart';
import 'services/matchmaking_service.dart';
import 'services/api_service.dart';
import 'auth/auth_gate.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Only initialize Firebase in production mode
  // For local development, we use dev authentication
  if (kReleaseMode) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const GemScrambleApp());
}

class GemScrambleApp extends StatelessWidget {
  const GemScrambleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppStateProvider()),
      ],
      child: MaterialApp(
        title: 'Gem Scramble',
        theme: ThemeData(
          primarySwatch: Colors.amber,
          primaryColor: const Color(0xFFFFD700), // Gold
          scaffoldBackgroundColor: const Color(0xFF1A1A1A), // Dark background
          textTheme: GoogleFonts.robotoTextTheme(
            Theme.of(context).textTheme.apply(
                  bodyColor: Colors.white,
                  displayColor: Colors.white,
                ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xFF2A2A2A),
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFD700),
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          cardTheme: const CardThemeData(
            color: Color(0xFF2A2A2A),
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        ),
        home: const AuthGate(),
        routes: {
          '/lobby': (context) => const LobbyScreen(),
          '/wallet': (context) => const WalletScreen(),
        },
      ),
    );
  }
}

class AppStateProvider extends ChangeNotifier {
  final WalletService _walletService = WalletService.instance;
  final MatchmakingService _matchmakingService = MatchmakingService.instance;
  final ApiService _apiService = ApiService.instance;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _apiService.initialize();
      await _walletService.initialize();
      await _matchmakingService.initialize();
      _isInitialized = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Error initializing app: $e');
    }
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
    context.read<AppStateProvider>().initialize();
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
