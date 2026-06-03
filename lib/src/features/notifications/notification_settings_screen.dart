import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../state/providers.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  static const _toggles = <String, String>{
    'new_requests': 'New help requests',
    'claim_updates': 'Claim & confirmation updates',
    'trip_updates': 'Trip status updates',
    'messages': 'Messages',
    'emergency_alerts': 'Emergency alerts',
  };

  Map<String, dynamic> _settings = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final s = await ref.read(notificationRepositoryProvider).getSettings(userId);
    if (mounted) {
      setState(() {
        _settings = s;
        _loading = false;
      });
    }
  }

  Future<void> _set(String key, bool value) async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    setState(() => _settings[key] = value);
    try {
      await ref
          .read(notificationRepositoryProvider)
          .updateSettings(userId, {key: value});
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Notification settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                for (final entry in _toggles.entries)
                  SwitchListTile(
                    title: Text(entry.value),
                    value: _settings[entry.key] as bool? ?? true,
                    onChanged: (v) => _set(entry.key, v),
                  ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text(
                    'These control which in-app notifications you receive. '
                    'Push delivery to your device also requires notifications '
                    'to be enabled in your browser/OS.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
