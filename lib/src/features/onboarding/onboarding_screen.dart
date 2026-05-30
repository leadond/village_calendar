import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../models/village.dart';
import '../../state/providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

enum _Step { profile, village }

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _nameController = TextEditingController();
  final _villageNameController = TextEditingController();
  final _inviteController = TextEditingController();

  _Step _step = _Step.profile;
  UserRole _role = UserRole.parent;
  String _villageType = 'family';
  bool _joinMode = false;
  bool _busy = false;
  bool _seeded = false;

  @override
  void dispose() {
    _nameController.dispose();
    _villageNameController.dispose();
    _inviteController.dispose();
    super.dispose();
  }

  Profile? get _profile => ref.read(currentProfileProvider).value;

  void _seed() {
    if (_seeded) return;
    final profile = _profile;
    if (profile != null) {
      _nameController.text = profile.displayName;
      _role = profile.role;
      _seeded = true;
    }
  }

  Future<void> _saveProfileAndContinue() async {
    final profile = _profile;
    if (profile == null) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      _toast('Please enter your name.');
      return;
    }

    setState(() => _busy = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            id: profile.id,
            displayName: name,
            role: _role,
          );
      ref.invalidate(currentProfileProvider);
      if (!mounted) return;
      setState(() => _step = _Step.village);
    } catch (error) {
      _toast('Could not save profile: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createVillage() async {
    final profile = _profile;
    if (profile == null) return;
    final name = _villageNameController.text.trim();
    if (name.isEmpty) {
      _toast('Please name your village.');
      return;
    }

    setState(() => _busy = true);
    try {
      // RPC creates the village, adds you as admin member, makes it active.
      await ref.read(villageRepositoryProvider).createVillage(
            name: name,
            villageType: _villageType,
          );
      _refreshAll();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not create village: $error');
      }
    }
  }

  Future<void> _joinVillage() async {
    final profile = _profile;
    if (profile == null) return;
    final code = _inviteController.text.trim();
    if (code.isEmpty) {
      _toast('Enter an invite code.');
      return;
    }

    setState(() => _busy = true);
    try {
      // Creates a pending request for an admin to approve (RLS-safe RPC).
      final result =
          await ref.read(villageRepositoryProvider).requestToJoin(code);

      if (result.isAlreadyMember) {
        _refreshAll();
        return;
      }
      if (result.notFound) {
        if (mounted) {
          setState(() => _busy = false);
          _toast('No village found for code "$code".');
        }
        return;
      }
      // Pending: surface the waiting-for-approval view.
      ref.invalidate(myPendingJoinProvider);
      if (mounted) setState(() => _busy = false);
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _toast('Could not join village: $error');
      }
    }
  }

  /// Invalidate downstream providers so RootGate re-routes to the home shell.
  void _refreshAll() {
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentVillageProvider);
    ref.invalidate(villageMembersProvider);
    ref.invalidate(myVillagesProvider);
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _cancelPending(String requestId) async {
    setState(() => _busy = true);
    try {
      await ref.read(villageRepositoryProvider).cancelMyJoin(requestId);
      ref.invalidate(myPendingJoinProvider);
    } catch (error) {
      _toast('Could not cancel: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    _seed();

    // If the user has a pending join request, show the waiting state instead
    // of the create/join form.
    final pending = ref.watch(myPendingJoinProvider).value;
    if (pending != null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Request pending'),
          automaticallyImplyLeading: false,
        ),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.hourglass_top, size: 48),
                    const SizedBox(height: 16),
                    Text(
                      'Waiting for approval',
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your request to join "${pending.villageName}" is pending '
                      'an admin\'s approval. You\'ll get in as soon as they '
                      'approve it.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () {
                              ref.invalidate(currentProfileProvider);
                              ref.invalidate(myPendingJoinProvider);
                            },
                      icon: const Icon(Icons.refresh),
                      label: const Text('Check status'),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed:
                          _busy ? null : () => _cancelPending(pending.requestId),
                      child: const Text('Cancel request'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_step == _Step.profile ? 'Set up your profile' : 'Your village'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: _step == _Step.profile
                  ? _buildProfileStep(context)
                  : _buildVillageStep(context),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome! Tell us who you are.',
          style: theme.textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Your name',
            prefixIcon: Icon(Icons.person_outline),
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        Text('Your role', style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        for (final role in [UserRole.parent, UserRole.helper, UserRole.guest])
          _SelectableCard(
            selected: _role == role,
            title: role.label,
            subtitle: role.description,
            onTap: _busy ? null : () => setState(() => _role = role),
          ),
        const SizedBox(height: 8),
        Text(
          'Creating a village makes you its admin automatically.',
          style: theme.textTheme.bodySmall
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _busy ? null : _saveProfileAndContinue,
          child: _busy
              ? const _ButtonSpinner()
              : const Text('Continue'),
        ),
      ],
    );
  }

  Widget _buildVillageStep(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(value: false, label: Text('Create'), icon: Icon(Icons.add_home_outlined)),
            ButtonSegment(value: true, label: Text('Join'), icon: Icon(Icons.group_add_outlined)),
          ],
          selected: {_joinMode},
          onSelectionChanged:
              _busy ? null : (s) => setState(() => _joinMode = s.first),
        ),
        const SizedBox(height: 24),
        if (!_joinMode) ...[
          Text(
            'Create a new village',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _villageNameController,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Village name',
              prefixIcon: Icon(Icons.holiday_village_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Type', style: theme.textTheme.titleSmall),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final t in kVillageTypes)
                ChoiceChip(
                  label: Text('${t[0].toUpperCase()}${t.substring(1)}'),
                  selected: _villageType == t,
                  onSelected:
                      _busy ? null : (_) => setState(() => _villageType = t),
                ),
            ],
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _createVillage,
            child: _busy ? const _ButtonSpinner() : const Text('Create village'),
          ),
        ] else ...[
          Text(
            'Join with an invite code',
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _inviteController,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              labelText: 'Invite code',
              hintText: 'e.g. 7K2Q9P',
              prefixIcon: Icon(Icons.vpn_key_outlined),
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _joinVillage,
            child:
                _busy ? const _ButtonSpinner() : const Text('Request to join'),
          ),
        ],
        const SizedBox(height: 12),
        TextButton(
          onPressed: _busy ? null : () => setState(() => _step = _Step.profile),
          child: const Text('Back to profile'),
        ),
      ],
    );
  }
}

class _ButtonSpinner extends StatelessWidget {
  const _ButtonSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.square(
      dimension: 20,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: selected ? theme.colorScheme.primaryContainer : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: selected
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: selected ? 2 : 1,
        ),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          selected ? Icons.radio_button_checked : Icons.radio_button_off,
          color: selected ? theme.colorScheme.primary : null,
        ),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}
