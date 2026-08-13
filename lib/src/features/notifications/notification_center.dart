import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../state/providers.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsStreamProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: user == null
                ? null
                : () async {
                    await ref
                        .read(notificationRepositoryProvider)
                        .markAllRead(user.id);
                  },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load notifications.\n$error'),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No notifications yet.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final item = items[index];
              return _NotificationCard(item: item);
            },
          );
        },
      ),
    );
  }
}

class _NotificationCard extends ConsumerWidget {
  const _NotificationCard({required this.item});

  final AppNotification item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final timestamp = DateFormat('EEE, MMM d · h:mm a').format(item.createdAt);

    return Card(
      color: item.isUnread ? theme.colorScheme.primaryContainer : null,
      child: ListTile(
        leading: CircleAvatar(
          child: Icon(_iconFor(item.type)),
        ),
        title: Text(
          item.title.isEmpty ? 'Notification' : item.title,
          style: item.isUnread
              ? theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                )
              : null,
        ),
        subtitle: Text(
          '${item.body.isEmpty ? 'No message body' : item.body}\n$timestamp',
        ),
        isThreeLine: true,
        trailing: item.isUnread
            ? IconButton(
                tooltip: 'Mark read',
                icon: const Icon(Icons.done),
                onPressed: () async {
                  await ref
                      .read(notificationRepositoryProvider)
                      .markRead(item.id);
                },
              )
            : const Icon(Icons.done_all, size: 20),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'new_request':
        return Icons.handshake_outlined;
      case 'direct_message':
        return Icons.chat_bubble_outline;
      case 'announcement':
        return Icons.campaign_outlined;
      case 'emergency':
        return Icons.sos_outlined;
      default:
        return Icons.notifications_none;
    }
  }
}
