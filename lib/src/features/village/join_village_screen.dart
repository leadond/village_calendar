import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../state/providers.dart';
import '../subscriptions/paywall_screen.dart';

/// Reachable any time (not just onboarding) so a member can request to join
/// additional villages. Membership stays pending until that village's admin
/// approves it.
class JoinVillageScreen extends ConsumerStatefulWidget {
  const JoinVillageScreen({super.key});

  @override
  ConsumerState<JoinVillageScreen> createState() => _JoinVillageScreenState();
}

class _JoinVillageScreenState extends ConsumerState<JoinVillageScreen> {
  final _code = TextEditingController();
  UserRole _requestedRole = UserRole.helper;
  bool _busy = false;
  String? _message;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _message = 'Enter an invite code.');
      return;
    }

    // Free tier = one village. Joining additional villages needs Premium.
    final villageCount = ref.read(myVillagesProvider).value?.length ?? 0;
    if (villageCount >= 1 && !ref.read(isPremiumProvider)) {
      final upgraded = await requirePremium(context, ref);
      if (!upgraded) {
        setState(() => _message =
            'Premium is required to belong to more than one village.');
        return;
      }
    }

    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final result = await ref.read(villageRepositoryProvider).requestToJoin(
            code,
            requestedRole: _requestedRole.name,
          );
      if (result.isAlreadyMember) {
        setState(() =>
            _message = 'You are already a member of ${result.villageName}.');
      } else if (result.notFound) {
        setState(() => _message = 'No village found for code "$code".');
      } else {
        // Pending — refresh providers so it shows up wherever relevant.
        ref.invalidate(myPendingJoinProvider);
        ref.invalidate(myVillagesProvider);
        if (mounted) {
          setState(() => _message = 'Request sent to ${result.villageName} as a '
              '${UserRole.fromName(result.requestedRole).label.toLowerCase()}. '
              'You\'ll get access once an admin approves it.');
        }
      }
    } catch (e) {
      setState(() => _message = 'Could not send request: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join another village')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: ListView(
              padding: const EdgeInsets.all(24),
              shrinkWrap: true,
              children: [
                const Text(
                  'Enter the invite code for the village you want to join. '
                  'Each village keeps its own members and data separate. '
                  'You can be a parent in one village and a helper in another.',
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _code,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: 'Invite code',
                    prefixIcon: Icon(Icons.vpn_key_outlined),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<UserRole>(
                  initialValue: _requestedRole,
                  decoration: const InputDecoration(
                    labelText: 'Join as',
                    prefixIcon: Icon(Icons.badge_outlined),
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: UserRole.helper,
                      child: Text('Helper'),
                    ),
                    DropdownMenuItem(
                      value: UserRole.parent,
                      child: Text('Parent'),
                    ),
                  ],
                  onChanged: _busy
                      ? null
                      : (value) {
                          if (value == null) return;
                          setState(() => _requestedRole = value);
                        },
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Request to join'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: 16),
                  Text(_message!,
                      style: Theme.of(context).textTheme.bodyMedium),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// App-bar action: shows the active village and lets the user switch between
/// their villages or jump to "Join another village".
class VillageSwitcherAction extends ConsumerWidget {
  const VillageSwitcherAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final villages = ref.watch(myVillagesProvider).value ?? const [];

    return PopupMenuButton<String>(
      tooltip: 'Switch village',
      icon: const Icon(Icons.swap_horiz),
      onSelected: (value) async {
        if (value == '__join__') {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const JoinVillageScreen()),
          );
          return;
        }
        await ref.read(villageRepositoryProvider).switchActiveVillage(value);
        // Re-scope the whole app to the newly active village.
        ref.invalidate(currentProfileProvider);
        ref.invalidate(currentVillageProvider);
        ref.invalidate(villageMembersProvider);
        ref.invalidate(myVillagesProvider);
        ref.invalidate(myRequestsProvider);
        ref.invalidate(availableRequestsProvider);
        ref.invalidate(pendingJoinRequestsProvider);
      },
      itemBuilder: (context) => [
        for (final v in villages)
          PopupMenuItem(
            value: v.villageId,
            child: Row(
              children: [
                Icon(
                  v.isActive
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(child: Text(v.name)),
                Text(v.role, style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: '__join__',
          child: Row(
            children: [
              Icon(Icons.add, size: 18),
              SizedBox(width: 8),
              Text('Join another village'),
            ],
          ),
        ),
      ],
    );
  }
}
