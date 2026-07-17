import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../state/providers.dart';

/// A 1:1 direct-message conversation with another villager.
class DirectThreadScreen extends ConsumerStatefulWidget {
  const DirectThreadScreen({
    super.key,
    required this.otherId,
    required this.otherName,
  });

  final String otherId;
  final String otherName;

  @override
  ConsumerState<DirectThreadScreen> createState() => _DirectThreadScreenState();
}

class _DirectThreadScreenState extends ConsumerState<DirectThreadScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text.trim();
    if (text.isEmpty) return;
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || !profile.hasVillage) return;
    _input.clear();
    try {
      await ref.read(directMessageRepositoryProvider).send(
            villageId: profile.villageId!,
            recipientId: widget.otherId,
            body: text,
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
    final me = ref.watch(currentUserProvider)?.id;
    final all = ref.watch(directMessagesProvider).value ?? const [];
    final thread = all
        .where((m) =>
            (m.senderId == me && m.recipientId == widget.otherId) ||
            (m.senderId == widget.otherId && m.recipientId == me))
        .toList();

    // Mark incoming unread as read.
    final repo = ref.read(directMessageRepositoryProvider);
    for (final m in thread) {
      if (m.recipientId == me && m.readAt == null) {
        repo.markRead(m.id);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: thread.isEmpty
                ? const Center(child: Text('Say hello 👋'))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: thread.length,
                    itemBuilder: (context, i) {
                      final m = thread[i];
                      final mine = m.senderId == me;
                      return Align(
                        alignment:
                            mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.all(10),
                          constraints: BoxConstraints(
                              maxWidth:
                                  MediaQuery.of(context).size.width * 0.72),
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
                              Text(DateFormat('MMM d · h:mm a').format(m.createdAt),
                                  style:
                                      Theme.of(context).textTheme.labelSmall),
                            ],
                          ),
                        ),
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
                  IconButton.filled(onPressed: _send, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
