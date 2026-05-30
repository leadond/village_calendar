import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
import '../../state/providers.dart';

/// List of chat threads (one per request where the user has a counterpart).
class ThreadsScreen extends ConsumerWidget {
  const ThreadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final threadsAsync = ref.watch(messageThreadsProvider);
    final names = ref.watch(memberNameLookupProvider);
    final myId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Messages'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(messageThreadsProvider),
          ),
        ],
      ),
      body: threadsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (threads) {
          if (threads.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No conversations yet. Once a request is claimed, you can '
                  'message the other person here.',
                  textAlign: TextAlign.center,
                ),
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
                  leading: CircleAvatar(
                    child: Text(otherName.isNotEmpty
                        ? otherName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(otherName),
                  subtitle: Text('${r.title} · ${r.status.label}'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ThreadScreen(request: r),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// A single request conversation, subscribed to messages realtime.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.request});

  final HelpRequest request;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  String? get _myId => ref.read(currentUserProvider)?.id;

  String? get _otherId {
    final r = widget.request;
    return r.creatorId == _myId ? r.helperId : r.creatorId;
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    _input.clear();
    try {
      await ref.read(messageRepositoryProvider).send(
            requestId: widget.request.id,
            recipientId: _otherId,
            text: text,
          );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final names = ref.watch(memberNameLookupProvider);
    final messagesAsync = ref.watch(messagesStreamProvider(widget.request.id));
    final otherName = names[_otherId] ?? 'Member';

    return Scaffold(
      appBar: AppBar(
        title: Text(otherName),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(widget.request.title,
                style: Theme.of(context).textTheme.labelMedium),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Could not load.\n$e')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(child: Text('Say hello 👋'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: messages.length,
                  itemBuilder: (context, i) {
                    final m = messages[i];
                    final mine = m.senderId == _myId;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(10),
                        constraints: BoxConstraints(
                          maxWidth:
                              MediaQuery.of(context).size.width * 0.72,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? Theme.of(context).colorScheme.primaryContainer
                              : Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(m.body),
                            const SizedBox(height: 2),
                            Text(
                              DateFormat('MMM d · h:mm a').format(m.createdAt),
                              style: Theme.of(context).textTheme.labelSmall,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Message…',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
