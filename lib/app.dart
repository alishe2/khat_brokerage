import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme/app_theme.dart';

import 'features/auth/presentation/login_screen.dart';
import 'features/dashboard/presentation/admin_dashboard.dart';
import 'features/dashboard/presentation/accountant_dashboard.dart';

class KhatBrokerageApp extends StatelessWidget {
  const KhatBrokerageApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      title: 'Khat Brokerage',

      theme: AppTheme.lightTheme,

      home: const AuthGate(),
    );
  }
}

// ================================================================
// AUTHENTICATION GATE
// ================================================================

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: supabase.auth.onAuthStateChange,

      builder: (context, snapshot) {
        // ==========================================================
        // NO LOGGED-IN USER
        // ==========================================================

        final session = supabase.auth.currentSession;

        if (session == null) {
          return const LoginScreen();
        }

        // ==========================================================
        // USER IS LOGGED IN
        // ==========================================================

        return const _RoleGate();
      },
    );
  }
}

// ================================================================
// ROLE GATE
// ================================================================

class _RoleGate extends StatefulWidget {
  const _RoleGate();

  @override
  State<_RoleGate> createState() => _RoleGateState();
}

class _RoleGateState extends State<_RoleGate> {
  final _supabase = Supabase.instance.client;

  String? _role;
  String? _error;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();

    _loadRole();
  }

  // ==============================================================
  // LOAD CURRENT USER ROLE
  // ==============================================================

  Future<void> _loadRole() async {
    try {
      final role = await _supabase.rpc(
        'get_my_role',
      );

      if (!mounted) return;

      if (role == null || role.toString().isEmpty) {
        setState(() {
          _error = 'User role was not found.';
          _isLoading = false;
        });

        return;
      }

      setState(() {
        _role = role.toString();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = 'Could not load user role: $e';
        _isLoading = false;
      });
    }
  }

  // ==============================================================
  // BUILD
  // ==============================================================

  @override
  Widget build(BuildContext context) {
    // ============================================================
    // LOADING
    // ============================================================

    if (_isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // ============================================================
    // ERROR
    // ============================================================

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                ),

                const SizedBox(height: 16),

                Text(
                  _error!,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 20),

                FilledButton(
                  onPressed: () async {
                    await _supabase.auth.signOut();
                  },
                  child: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ============================================================
    // ADMIN
    // ============================================================

    if (_role == 'admin') {
      return const AdminDashboard();
    }

    // ============================================================
    // ACCOUNTANT
    // ============================================================

    if (_role == 'accountant') {
      return const AccountantDashboard();
    }

    // ============================================================
    // INVALID ROLE
    // ============================================================

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.block_outlined,
                size: 48,
              ),

              const SizedBox(height: 16),

              Text(
                'Invalid user role: $_role',
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 20),

              FilledButton(
                onPressed: () async {
                  await _supabase.auth.signOut();
                },
                child: const Text('Sign Out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}