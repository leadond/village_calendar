import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/providers.dart';
import 'direct_thread_screen.dart';
import 'messages_screen.dart' show ThreadScreen;

/// Unified messaging: 1:1 direct chats, per-request threads, and broadcasts.
class MessagesHub extends ConsumerWidget {
  const MessagesHub({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Messages'),
          bottom: const TabBar(tabs: [
            Tab(text: 'Direct'),
            Tab(text: 'Requests'),
            Tab(text: 'Announcements'),
          ]),
        ),
        body: const TabBarView(children: [
          _DirectTab(),
          _RequestThreadsTab(),
          _AnnouncementsTab(),
        ]),
      ),
    );
  }
}

class _DirectTab extends ConsumerWidget {
  const _DirectTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider)?.id;
    final members = ref.watch(villageMembersProvider).value ?? const [];
    final msgs = ref.watch(directMessagesProvider).value ?? const [];
    final others = members.where((m) => m.id != me).toList();

    if (others.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No one else in this village yet.'),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8),
      itemCount: others.length,
      itemBuilder: (context, i) {
        final other = others[i];
        final convo = msgs
            .where((m) =>
                m.senderId == other.id || m.recipientId == other.id)
            .toList();
        final last = convo.isNotEmpty ? convo.last : null;
        final unread = convo
            .where((m) => m.recipientId == me && m.readAt == null)
            .length;
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              child: Text(other.displayName.isNotEmpty
                  ? other.displayName[0].toUpperCase()
                  : '?'),
            ),
            title: Text(other.displayName),
            subtitle: last == null
                ? Text(other.role.label)
                : Text(last.body, maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: unread > 0
                ? CircleAvatar(
                    radius: 11,
                    backgroundColor: Colors.red,
                    child: Text('$unread',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 11)),
                  )
                : const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => DirectThreadScreen(
                  otherId: other.id, otherName: other.displayName),
            )),
          ),
        );
      },
    );
  }
}

class _RequestThreadsTab extends ConsumerWidget {
  const _RequestThreadsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(messageThreadsProvider);
    final names = ref.watch(memberNameLookupProvider);
    final myId = ref.watch(currentUserProvider)?.id;

    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load.\n$e')),
      data: (threads) {
        if (threads.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('No request conversations yet. Claim or post a '
                  'request to start one.', textAlign: TextAlign.center),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(8),
          itemCount: threads.length,
          itemBuilder: (context, i) {
            final r = threads[i];
            final otherId = r.creatorId == myId ? r.helperId : r.creatorId;
            final otherName = names[otherId] ?? 'Member';
            return Card(
              child: ListTile(
                leading: const CircleAvatar(child: Icon(Icons.handshake)),
                title: Text(otherName),
                subtitle: Text('${r.title} · ${r.status.label}'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ThreadScreen(request: r),
                )),
              ),
            );
          },
        );
      },
    );
  }
}

class _AnnouncementsTab extends ConsumerWidget {
  const _AnnouncementsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(announcementsProvider);
    final names = ref.watch(memberNameLookupProvider);
    final me = ref.watch(currentUserProvider)?.id;
    final isAdmin = ref.watch(activeRoleProvider).name == 'admin';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'messages-broadcast-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const BroadcastComposeScreen()),
        ),
        icon: const Icon(Icons.campaign),
        label: const Text('Broadcast'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No announcements yet. Tap "Broadcast" to send one '
                    'to the whole village.', textAlign: TextAlign.center),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final a = items[i];
              final canDelete = a.createdBy == me || isAdmin;
              return Card(
                child: ListTile(
                  leading: const Icon(Icons.campaign_outlined),
                  title: Text(a.title,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(a.message),
                      const SizedBox(height: 4),
                      Text(
                        '${names[a.createdBy] ?? 'A member'} · '
                        '${DateFormat('MMM d · h:mm a').format(a.createdAt)}',
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
                    ],
                  ),
                  trailing: canDelete
                      ? IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => ref
                              .read(announcementRepositoryProvider)
                              .delete(a.id),
                        )
                      : null,
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class BroadcastComposeScreen extends ConsumerStatefulWidget {
  const BroadcastComposeScreen({super.key});

  @override
  ConsumerState<BroadcastComposeScreen> createState() =>
      _BroadcastComposeScreenState();
}

class _BroadcastComposeScreenState
    extends ConsumerState<BroadcastComposeScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  bool _busy = false;
  bool _aiBusy = false;

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || !profile.hasVillage) return;
    if (_title.text.trim().isEmpty || _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a title and a message.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(announcementRepositoryProvider).post(
            villageId: profile.villageId!,
            title: _title.text,
            message: _message.text,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Broadcast sent to the village')),
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

  Future<void> _improveWithAi() async {
    if (_title.text.trim().isEmpty && _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add a rough title or message first.')),
      );
      return;
    }

    setState(() => _aiBusy = true);
    try {
      final improved = await ref.read(aiAssistantServiceProvider).improveAnnouncement(
            title: _title.text,
            message: _message.text,
          );
      if (!mounted) return;
      setState(() {
        _title.text = improved['title'] ?? _title.text;
        _message.text = improved['message'] ?? _message.text;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI polished your announcement.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('AI improvement failed: $e')),
      );
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Broadcast to village')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                prefixIcon: Icon(Icons.title),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Message',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text('Everyone in your village gets a notification.',
                style: Theme.of(context).textTheme.labelSmall),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: (_busy || _aiBusy) ? null : _improveWithAi,
              icon: _aiBusy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome),
              label: const Text('Polish with AI'),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: (_busy || _aiBusy) ? null : _send,
              icon: _busy
                  ? const SizedBox.square(
                      dimension: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.campaign),
              label: const Text('Send broadcast'),
            ),
          ],
        ),
      ),
    );
  }
}
