import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import 'login_screen.dart';
import '../main.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Initialize API service on app start
    ApiService.instance.initialize();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: ConfigService.instance.isDevAuth(),
      builder: (context, authModeSnapshot) {
        if (authModeSnapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }

        final isDevAuth = authModeSnapshot.data ?? true; // Default to dev mode

        if (isDevAuth) {
          // Dev mode: check for stored user ID
          return FutureBuilder<bool>(
            future: _checkDevLoginStatus(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              final isLoggedIn = snapshot.data ?? false;
              return isLoggedIn ? const MainScreen() : const LoginScreen();
            },
          );
        } else {
          // Firebase mode: use stream for auth state
          return StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasData) {
                return const MainScreen();
              } else {
                return const LoginScreen();
              }
            },
          );
        }
      },
    );
  }

  Future<bool> _checkDevLoginStatus() async {
    await ApiService.instance.initialize();
    return ApiService.instance.isDevUserLoggedIn();
  }
}
