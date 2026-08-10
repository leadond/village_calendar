import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/setup_services.dart';
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
  bool _pushBusy = false;
  String? _pushToken;
  String? _pushStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;
    final s = await ref.read(notificationRepositoryProvider).getSettings(userId);
    final token = await SetupServices.getFirebaseMessagingToken();
    if (mounted) {
      setState(() {
        _settings = s;
        _pushToken = token;
        _pushStatus = token != null && token.isNotEmpty
            ? 'Push notifications are connected for this device.'
            : _defaultPushStatus();
        _loading = false;
      });
    }
  }

  String _defaultPushStatus() {
    if (!SetupServices.isFirebaseMessagingConfigured) {
      return 'Push notifications are not configured for this build yet.';
    }

    return kIsWeb
        ? 'Browser notifications are ready to enable.'
        : 'Push notifications are ready to enable on this device.';
  }

  Future<void> _enablePushNotifications() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) return;

    setState(() => _pushBusy = true);
    try {
      final token = await SetupServices.getFirebaseMessagingToken(
        requestPermission: true,
      );

      if (token == null || token.isEmpty) {
        if (mounted) {
          setState(() {
            _pushStatus =
                'Notification permission was not granted for this browser yet.';
          });
        }
        return;
      }

      await ref.read(notificationRepositoryProvider).savePushToken(userId, token);
      if (mounted) {
        setState(() {
          _pushToken = token;
          _pushStatus = 'Push notifications are connected for this device.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Push notifications enabled.')),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _pushStatus = 'Could not enable push notifications.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not enable push notifications: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _pushBusy = false);
      }
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
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Push notifications',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(_pushStatus ?? _defaultPushStatus()),
                        if (_pushToken != null && _pushToken!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Connected token: ${_pushToken!.substring(0, 12)}...',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                        const SizedBox(height: 12),
                        FilledButton.icon(
                          onPressed: (!SetupServices.isFirebaseMessagingConfigured ||
                                  _pushBusy)
                              ? null
                              : _enablePushNotifications,
                          icon: const Icon(Icons.notifications_active_outlined),
                          label: Text(
                            _pushToken?.isNotEmpty == true
                                ? 'Refresh push connection'
                                : 'Enable push notifications',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
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
