import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../main.dart';
import '../providers/auth_provider.dart';
import 'login_screen.dart';

/// Routes to the main app or the login screen based on [AuthProvider] state.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  @override
  void initState() {
    super.initState();
    // Resolve auth mode and restore any persisted session.
    context.read<AuthProvider>().initialize();
  }

  @override
  Widget build(BuildContext context) {
    final status = context.watch<AuthProvider>().status;
    return switch (status) {
      AuthStatus.unknown => const Scaffold(
          body: Center(child: CircularProgressIndicator()),
        ),
      AuthStatus.authenticated => const MainScreen(),
      AuthStatus.unauthenticated ||
      AuthStatus.authenticating =>
        const LoginScreen(),
    };
  }
}
