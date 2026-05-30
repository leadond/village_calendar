import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../screens/landing_page.dart';
import '../features/home/home_shell.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../services/setup_services.dart';
import '../state/providers.dart';

/// Top-level reactive router. Replaces manual `Navigator.pushNamed` flows with
/// state-driven screen selection:
///   not configured        -> LandingPage (shows setup warnings)
///   signed out            -> LandingPage (Get Started -> /auth)
///   signed in, no village -> OnboardingScreen
///   signed in, in village -> HomeShell
class RootGate extends ConsumerWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final setupStatus = ref.watch(setupStatusProvider);

    // Guard: backend must be configured before any Supabase-backed screen.
    if (!SetupServices.isSupabaseReady) {
      return LandingPage(setupStatus: setupStatus);
    }

    final user = ref.watch(currentUserProvider);

    // Guard: must be signed in.
    if (user == null) {
      return LandingPage(setupStatus: setupStatus);
    }

    final profileAsync = ref.watch(currentProfileProvider);

    return profileAsync.when(
      loading: () => const _GateSplash(),
      error: (error, _) => _GateError(
        message: 'Could not load your profile.\n$error',
        onRetry: () => ref.invalidate(currentProfileProvider),
      ),
      data: (profile) {
        if (profile == null) {
          return _GateError(
            message: 'No profile found for your account.',
            onRetry: () => ref.invalidate(currentProfileProvider),
          );
        }

        // Guard: must be in a village.
        if (!profile.hasVillage) {
          return const OnboardingScreen();
        }

        return HomeShell(profile: profile);
      },
    );
  }
}

class _GateSplash extends StatelessWidget {
  const _GateSplash();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}

class _GateError extends StatelessWidget {
  const _GateError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 40),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: onRetry, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
