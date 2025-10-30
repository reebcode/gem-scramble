import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/api_service.dart';
import '../services/config_service.dart';
import '../main.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _usernameController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
    });

    final isDevAuth = await ConfigService.instance.isDevAuth();

    if (isDevAuth) {
      // Dev mode: login with username
      final api = ApiService.instance;
      final user =
          await api.loginOrRegisterWithUsername(_emailController.text.trim());
      if (user != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      } else {
        _showErrorDialog('Failed to login with username.');
      }
    } else {
      // Firebase mode: email/password authentication
      try {
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();

        if (email.isEmpty || password.isEmpty) {
          _showErrorDialog('Please enter both email and password.');
          return;
        }

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

          await FirebaseAuth.instance.createUserWithEmailAndPassword(
            email: email,
            password: password,
          );

          // Set username after account creation
          await ApiService.instance.setUsername(username);
        } else {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        }
        // AuthGate will handle navigation
      } on FirebaseAuthException catch (e) {
        String message = 'Authentication failed. ';
        switch (e.code) {
          case 'user-not-found':
            message += 'No user found with this email.';
            break;
          case 'wrong-password':
            message += 'Incorrect password.';
            break;
          case 'email-already-in-use':
            message += 'An account already exists with this email.';
            break;
          case 'weak-password':
            message += 'Password is too weak.';
            break;
          case 'invalid-email':
            message += 'Invalid email address.';
            break;
          default:
            message += e.message ?? 'Unknown error occurred.';
        }
        _showErrorDialog(message);
      } catch (e) {
        _showErrorDialog('An unexpected error occurred.');
      }
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showErrorDialog(String message) {
    if (mounted) {
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
              FutureBuilder<bool>(
                future: ConfigService.instance.isDevAuth(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const CircularProgressIndicator();
                  }
                  final isDevAuth = snapshot.data ?? true;
                  return isDevAuth
                      ? _buildDevLoginForm()
                      : _buildFirebaseAuthForm();
                },
              ),
              const SizedBox(height: 24),
              if (_isLoading)
                const CircularProgressIndicator()
              else
                Column(
                  children: [
                    FutureBuilder<bool>(
                      future: ConfigService.instance.isDevAuth(),
                      builder: (context, snapshot) {
                        final isDevAuth = snapshot.data ?? true;
                        return ElevatedButton(
                          onPressed: _login,
                          child: Text(isDevAuth
                              ? 'Dev Login'
                              : (_isSignUp ? 'Sign Up' : 'Sign In')),
                        );
                      },
                    ),
                    FutureBuilder<bool>(
                      future: ConfigService.instance.isDevAuth(),
                      builder: (context, snapshot) {
                        final isDevAuth = snapshot.data ?? true;
                        if (isDevAuth) return const SizedBox.shrink();
                        return Column(
                          children: [
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
                        );
                      },
                    ),
                  ],
                ),
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
