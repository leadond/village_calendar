import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationProvider = StateNotifierProvider<NotificationNotifier, List<String>>((ref) {
  return NotificationNotifier();
});

class NotificationNotifier extends StateNotifier<List<String>> {
  NotificationNotifier() : super([]);

  void addNotification(String message) {
    state = [...state, message];
  }

  void clearNotifications() {
    state = [];
  }

  void removeNotificationAt(int index) {
    final updated = List<String>.from(state);
    updated.removeAt(index);
    state = updated;
  }
}

class NotificationCenter extends ConsumerWidget {
  const NotificationCenter({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: ListView.builder(
        itemCount: notifications.length,
        itemBuilder: (context, index) {
          return ListTile(
            title: Text(notifications[index]),
            trailing: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                ref.read(notificationProvider.notifier).removeNotificationAt(index);
              },
            ),
          );
        },
      ),
    );
  }
}

class NotificationCenterScreen extends NotificationCenter {
  const NotificationCenterScreen({super.key});
}
