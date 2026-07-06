import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isSignUp = false;

  Future<void> _login() async {
    final auth = context.read<AuthProvider>();

    if (auth.isDevMode) {
      final username = _emailController.text.trim();
      if (username.isEmpty) {
        _showErrorDialog('Please enter a username.');
        return;
      }
      final user = await auth.loginDev(username);
      if (user == null && mounted) {
        _showErrorDialog(auth.error ?? 'Failed to login with username.');
      }
      // On success AuthGate rebuilds into MainScreen automatically.
      return;
    }

    // Firebase mode: email/password authentication.
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (email.isEmpty || password.isEmpty) {
      _showErrorDialog('Please enter both email and password.');
      return;
    }

    String? error;
    if (_isSignUp) {
      final username = _usernameController.text.trim();
      if (username.isEmpty) {
        _showErrorDialog('Please enter a username.');
        return;
      }
      if (username.length < 3) {
        _showErrorDialog('Username must be at least 3 characters long.');
        return;
      }
      if (username.length > 20) {
        _showErrorDialog('Username must be 20 characters or less.');
        return;
      }
      error = await auth.signUpWithEmail(email, password, username);
    } else {
      error = await auth.signInWithEmail(email, password);
    }

    if (error != null && mounted) {
      _showErrorDialog(error);
    }
  }

  void _showErrorDialog(String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final isResolvingMode = auth.authMode == null;
    final isDevMode = auth.isDevMode;
    final isBusy = auth.status == AuthStatus.authenticating;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Welcome to Gem Scramble!',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              if (isResolvingMode)
                const CircularProgressIndicator()
              else ...[
                isDevMode ? _buildDevLoginForm() : _buildFirebaseAuthForm(),
                const SizedBox(height: 24),
                if (isBusy)
                  const CircularProgressIndicator()
                else ...[
                  ElevatedButton(
                    onPressed: _login,
                    child: Text(isDevMode
                        ? 'Dev Login'
                        : (_isSignUp ? 'Sign Up' : 'Sign In')),
                  ),
                  if (!isDevMode) ...[
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          _isSignUp = !_isSignUp;
                        });
                      },
                      child: Text(_isSignUp
                          ? 'Already have an account? Sign In'
                          : 'Need an account? Sign Up'),
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDevLoginForm() {
    return Column(
      children: [
        const Text(
          'Enter a username for development login:',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Enter username',
            border: OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _buildFirebaseAuthForm() {
    return Column(
      children: [
        Text(
          _isSignUp ? 'Create a new account:' : 'Sign in to your account:',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 24),
        if (_isSignUp) ...[
          TextField(
            controller: _usernameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Username',
              border: OutlineInputBorder(),
              prefixIcon: Icon(Icons.person),
            ),
          ),
          const SizedBox(height: 16),
        ],
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          autofocus: !_isSignUp,
          decoration: const InputDecoration(
            hintText: 'Email address',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.email),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _passwordController,
          obscureText: true,
          decoration: const InputDecoration(
            hintText: 'Password',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.lock),
          ),
        ),
      ],
    );
  }
}
