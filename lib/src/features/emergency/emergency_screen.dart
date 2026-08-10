import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/emergency_alert.dart';
import '../../state/providers.dart';

/// List of village emergency alerts (active first) with resolve actions.
class EmergencyScreen extends ConsumerWidget {
  const EmergencyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(emergencyAlertsStreamProvider);
    final names = ref.watch(memberNameLookupProvider);
    final myId = ref.watch(currentUserProvider)?.id;
    final isAdmin = ref.watch(activeRoleProvider).name == 'admin';

    return Scaffold(
      appBar: AppBar(title: const Text('Emergency alerts')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'emergency-sos-fab',
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SosCreateScreen()),
        ),
        icon: const Icon(Icons.sos),
        label: const Text('Send SOS'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (alerts) {
          if (alerts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No alerts. Tap "Send SOS" only in a real '
                    'emergency to notify your village.',
                    textAlign: TextAlign.center),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final a in alerts)
                _AlertCard(
                  alert: a,
                  senderName: names[a.senderId] ?? 'A member',
                  canResolve: a.senderId == myId || isAdmin,
                  onResolve: (falseAlarm) async {
                    await ref
                        .read(emergencyRepositoryProvider)
                        .resolve(a.id, falseAlarm: falseAlarm);
                  },
                ),
            ],
          );
        },
      ),
    );
  }
}

class _AlertCard extends StatelessWidget {
  const _AlertCard({
    required this.alert,
    required this.senderName,
    required this.canResolve,
    required this.onResolve,
  });

  final EmergencyAlert alert;
  final String senderName;
  final bool canResolve;
  final Future<void> Function(bool falseAlarm) onResolve;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: alert.isActive ? Colors.red.shade50 : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(alert.type.emoji, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${alert.type.label} · $senderName',
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700)),
                ),
                Chip(
                  label: Text(alert.status),
                  backgroundColor: alert.isActive
                      ? Colors.red.shade100
                      : theme.colorScheme.surfaceContainerHighest,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            if (alert.message != null && alert.message!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(alert.message!),
            ],
            if (alert.lat != null && alert.lng != null) ...[
              const SizedBox(height: 6),
              SelectableText(
                'Location: ${alert.lat!.toStringAsFixed(5)}, ${alert.lng!.toStringAsFixed(5)}',
                style: theme.textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 4),
            Text(DateFormat('MMM d · h:mm a').format(alert.createdAt),
                style: theme.textTheme.labelSmall),
            if (alert.isActive && canResolve) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: () => onResolve(false),
                    icon: const Icon(Icons.check),
                    label: const Text('Resolve'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () => onResolve(true),
                    child: const Text('False alarm'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// SOS creation: pick a type, optional message, optionally attach location.
class SosCreateScreen extends ConsumerStatefulWidget {
  const SosCreateScreen({super.key});

  @override
  ConsumerState<SosCreateScreen> createState() => _SosCreateScreenState();
}

class _SosCreateScreenState extends ConsumerState<SosCreateScreen> {
  EmergencyType _type = EmergencyType.helpNeeded;
  final _message = TextEditingController();
  bool _attachLocation = true;
  bool _busy = false;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || !profile.hasVillage) return;
    setState(() => _busy = true);
    try {
      double? lat, lng;
      if (_attachLocation) {
        try {
          final loc = ref.read(locationServiceProvider);
          if (await loc.ensurePermission()) {
            final pos = await loc.current();
            lat = pos.latitude;
            lng = pos.longitude;
          }
        } catch (_) {/* location optional */}
      }
      await ref.read(emergencyRepositoryProvider).create(
            villageId: profile.villageId!,
            type: _type,
            message: _message.text.trim().isEmpty ? null : _message.text.trim(),
            lat: lat,
            lng: lng,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Alert sent to your village')),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Send SOS')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Type', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                for (final t in EmergencyType.values)
                  ChoiceChip(
                    label: Text('${t.emoji} ${t.label}'),
                    selected: _type == t,
                    onSelected: _busy ? null : (_) => setState(() => _type = t),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _message,
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'What is happening? (optional)',
                border: OutlineInputBorder(),
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Share my current location'),
              value: _attachLocation,
              onChanged: _busy ? null : (v) => setState(() => _attachLocation = v),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              onPressed: _busy ? null : _send,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Icons.sos),
              label: const Text('Send to my village'),
            ),
          ],
        ),
      ),
    );
  }
}
