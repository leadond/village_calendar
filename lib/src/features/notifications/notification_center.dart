import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../state/providers.dart';
import '../requests/request_detail_screen.dart';

class NotificationCenterScreen extends ConsumerWidget {
  const NotificationCenterScreen({super.key});

  Future<void> _open(
      BuildContext context, WidgetRef ref, AppNotification n) async {
    final repo = ref.read(notificationRepositoryProvider);
    if (n.isUnread) await repo.markRead(n.id);
    final requestId = n.requestId;
    if (requestId != null && context.mounted) {
      try {
        final req =
            await ref.read(helpRequestRepositoryProvider).fetch(requestId);
        if (context.mounted) {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RequestDetailScreen(request: req),
          ));
        }
      } catch (_) {/* request may be outside active village */}
    }
  }

  IconData _icon(String type) {
    if (type.startsWith('request')) return Icons.handshake_outlined;
    if (type == 'message') return Icons.chat_bubble_outline;
    if (type == 'comment') return Icons.mode_comment_outlined;
    if (type == 'emergency') return Icons.warning_amber;
    return Icons.notifications_none;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(notificationsStreamProvider);
    final userId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: userId == null
                ? null
                : () => ref
                    .read(notificationRepositoryProvider)
                    .markAllRead(userId),
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No notifications yet.'),
              ),
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = items[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: n.isUnread
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: Icon(_icon(n.type)),
                ),
                title: Text(n.title,
                    style: TextStyle(
                        fontWeight:
                            n.isUnread ? FontWeight.w700 : FontWeight.w400)),
                subtitle: Text(n.body),
                trailing: Text(
                  DateFormat('MMM d\nh:mm a').format(n.createdAt),
                  textAlign: TextAlign.right,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                onTap: () => _open(context, ref, n),
              );
            },
          );
        },
      ),
    );
  }
}
