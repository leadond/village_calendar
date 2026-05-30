import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../src/services/setup_services.dart';

class LandingPage extends StatefulWidget {
  const LandingPage({super.key, required this.setupStatus});

  final SetupStatus setupStatus;

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  User? get _currentUser => SetupServices.maybeSupabaseClient?.auth.currentUser;

  Future<void> _signOut() async {
    await SetupServices.maybeSupabaseClient?.auth.signOut();

    if (mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = _currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Village Calendar'), centerTitle: false),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Image.asset(
                    'assets/village_calendar_logo.png',
                    width: 144,
                    height: 144,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'Welcome to Village Calendar',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Coordinate local events, shared spaces, subscriptions, and location-aware reminders from one calm place.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  if (currentUser == null)
                    FilledButton.icon(
                      onPressed: () async {
                        await Navigator.pushNamed(context, '/auth');

                        if (mounted) {
                          setState(() {});
                        }
                      },
                      icon: const Icon(Icons.arrow_forward),
                      label: const Text('Get Started'),
                    )
                  else
                    _SignedInCard(
                      user: currentUser,
                      // RootGate routes signed-in users automatically; just
                      // rebuild so the gate re-evaluates.
                      onContinue: () => setState(() {}),
                      onSignOut: _signOut,
                    ),
                  if (widget.setupStatus.warnings.isNotEmpty) ...[
                    const SizedBox(height: 28),
                    _SetupNotice(warnings: widget.setupStatus.warnings),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SignedInCard extends StatelessWidget {
  const _SignedInCard({
    required this.user,
    required this.onContinue,
    required this.onSignOut,
  });

  final User user;
  final VoidCallback onContinue;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(Icons.verified_user, color: theme.colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              'Signed in',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.email ?? user.id,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.icon(
                  onPressed: onContinue,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Open App'),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: onSignOut,
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign Out'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupNotice extends StatelessWidget {
  const _SetupNotice({required this.warnings});

  final List<String> warnings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Setup pending',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (final warning in warnings.take(3))
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(warning, style: theme.textTheme.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}
