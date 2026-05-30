import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
import '../../repositories/help_request_repository.dart';
import '../../state/providers.dart';
import '../messages/messages_screen.dart';
import 'trip_tracking.dart';

class RequestDetailScreen extends ConsumerStatefulWidget {
  const RequestDetailScreen({super.key, required this.request});

  final HelpRequest request;

  @override
  ConsumerState<RequestDetailScreen> createState() =>
      _RequestDetailScreenState();
}

class _RequestDetailScreenState extends ConsumerState<RequestDetailScreen> {
  late HelpRequest _req = widget.request;
  final _comment = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  String? get _myId => ref.read(currentUserProvider)?.id;
  bool get _isCreator => _req.creatorId == _myId;
  bool get _isHelper => _req.helperId == _myId;

  /// Live GPS is relevant once the trip is underway.
  bool get _trackingActive =>
      _req.status == HelpStatus.confirmed ||
      _req.status == HelpStatus.inProgress ||
      _req.status == HelpStatus.arrived;

  Future<void> _run(Future<void> Function() action, String okMsg) async {
    setState(() => _busy = true);
    try {
      await action();
      _req = await ref.read(helpRequestRepositoryProvider).fetch(_req.id);
      ref.invalidate(myRequestsProvider);
      ref.invalidate(availableRequestsProvider);
      ref.invalidate(myClaimedProvider);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(okMsg)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addComment() async {
    final text = _comment.text.trim();
    if (text.isEmpty) return;
    _comment.clear();
    try {
      await ref
          .read(helpRequestRepositoryProvider)
          .addComment(_req.id, text);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(helpRequestRepositoryProvider);
    final names = ref.watch(memberNameLookupProvider);
    final theme = Theme.of(context);

    final canChat = _req.helperId != null && (_isCreator || _isHelper);

    return Scaffold(
      appBar: AppBar(
        title: Text(_req.title),
        actions: [
          if (canChat)
            IconButton(
              tooltip: 'Message',
              icon: const Icon(Icons.chat_bubble_outline),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ThreadScreen(request: _req),
                ),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Row(
                  children: [
                    Chip(label: Text(_req.category.label)),
                    const SizedBox(width: 8),
                    Chip(
                      label: Text(_req.status.label),
                      backgroundColor:
                          theme.colorScheme.primaryContainer,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _info(Icons.event, 'When',
                    DateFormat('EEE, MMM d · h:mm a').format(_req.scheduledStart)),
                _info(Icons.person, 'Requested by',
                    names[_req.creatorId] ?? (_isCreator ? 'You' : 'Member')),
                if (_req.helperId != null)
                  _info(Icons.volunteer_activism, 'Helper',
                      names[_req.helperId] ?? (_isHelper ? 'You' : 'Member')),
                if (_req.description?.isNotEmpty == true)
                  _info(Icons.notes, 'Details', _req.description!),
                if (_req.pickupAddress?.isNotEmpty == true)
                  _info(Icons.my_location, 'Pickup', _req.pickupAddress!),
                if (_req.dropoffAddress?.isNotEmpty == true)
                  _info(Icons.location_on_outlined, 'Dropoff',
                      _req.dropoffAddress!),
                if (_req.specialInstructions?.isNotEmpty == true)
                  _info(Icons.info_outline, 'Instructions',
                      _req.specialInstructions!),
                const SizedBox(height: 8),
                _timeline(),
                const SizedBox(height: 16),
                ..._actions(repo),
                if (_trackingActive) ...[
                  const SizedBox(height: 12),
                  if (_isHelper) HelperLiveShare(request: _req),
                  if (_isCreator) ParentLiveView(request: _req),
                ],
                const Divider(height: 32),
                Text('Comments', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                _comments(names),
              ],
            ),
          ),
          _commentInput(),
        ],
      ),
    );
  }

  Widget _info(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: Theme.of(context).textTheme.labelSmall),
                Text(value, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _timeline() {
    final steps = <(String, bool)>[
      ('Confirmed', _req.parentConfirmedAt != null),
      ('On the way', _req.status == HelpStatus.inProgress ||
          _req.status == HelpStatus.arrived ||
          _req.status == HelpStatus.completed),
      ('Arrived pickup', _req.helperCheckinAt != null),
      ('At destination', _req.arrivedAtDestinationAt != null),
      ('Completed', _req.parentReceiptConfirmedAt != null),
    ];
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final s in steps)
          Chip(
            avatar: Icon(
              s.$2 ? Icons.check_circle : Icons.radio_button_unchecked,
              size: 18,
              color: s.$2 ? Colors.green : null,
            ),
            label: Text(s.$1),
            visualDensity: VisualDensity.compact,
          ),
      ],
    );
  }

  List<Widget> _actions(HelpRequestRepository repo) {
    final status = _req.status;
    final buttons = <Widget>[];

    void add(String label, IconData icon, Future<void> Function() fn,
        String ok) {
      buttons.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: FilledButton.icon(
          onPressed: _busy ? null : () => _run(fn, ok),
          icon: Icon(icon),
          label: Text(label),
        ),
      ));
    }

    if (status == HelpStatus.open) {
      if (_isCreator) {
        add('Cancel request', Icons.close,
            () => repo.cancel(_req.id, byUserId: _myId!), 'Request cancelled');
      } else {
        add('Claim this request', Icons.pan_tool_alt,
            () => repo.claim(_req.id), 'Claimed — waiting for confirmation');
      }
    } else if (status == HelpStatus.claimed) {
      if (_isCreator) {
        add('Confirm helper', Icons.check, () => repo.confirm(_req.id),
            'Helper confirmed');
      } else if (_isHelper) {
        buttons.add(const Padding(
          padding: EdgeInsets.only(top: 8),
          child: Text('Waiting for the parent to confirm you.'),
        ));
      }
    } else if (status == HelpStatus.confirmed) {
      if (_isHelper) {
        add("I'm on my way", Icons.directions_car,
            () => repo.startTrip(_req.id), 'Trip started');
      }
    } else if (status == HelpStatus.inProgress) {
      if (_isHelper) {
        add('Arrived at pickup', Icons.flag,
            () => repo.arrivePickup(_req.id), 'Checked in at pickup');
      }
    } else if (status == HelpStatus.arrived) {
      if (_isHelper && _req.arrivedAtDestinationAt == null) {
        add('Arrived at destination', Icons.place,
            () => repo.arriveDropoff(_req.id), 'Arrived at destination');
      }
      if (_isCreator) {
        add('Confirm receipt (complete)', Icons.done_all,
            () => repo.complete(_req.id), 'Marked complete');
      }
    }

    // Allow cancel while still cancellable.
    if ((status == HelpStatus.claimed ||
            status == HelpStatus.confirmed) &&
        _isCreator) {
      buttons.add(Padding(
        padding: const EdgeInsets.only(top: 8),
        child: OutlinedButton.icon(
          onPressed: _busy
              ? null
              : () => _run(
                  () => repo.cancel(_req.id, byUserId: _myId!),
                  'Request cancelled'),
          icon: const Icon(Icons.close),
          label: const Text('Cancel request'),
        ),
      ));
    }

    if (buttons.isEmpty) {
      buttons.add(Text('Status: ${status.label}',
          style: Theme.of(context).textTheme.bodyMedium));
    }
    return buttons;
  }

  Widget _comments(Map<String, String> names) {
    final commentsAsync = ref.watch(requestCommentsProvider(_req.id));
    return commentsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(8),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (e, _) => Text('Could not load comments.\n$e'),
      data: (comments) {
        if (comments.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('No comments yet.'),
          );
        }
        return Column(
          children: [
            for (final c in comments)
              Align(
                alignment: c.authorId == _myId
                    ? Alignment.centerRight
                    : Alignment.centerLeft,
                child: Card(
                  color: c.authorId == _myId
                      ? Theme.of(context).colorScheme.primaryContainer
                      : null,
                  child: Padding(
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.authorId == _myId
                              ? 'You'
                              : (names[c.authorId] ?? 'Member'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                        Text(c.body),
                        Text(
                          DateFormat('MMM d · h:mm a').format(c.createdAt),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _commentInput() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _comment,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _addComment(),
                decoration: const InputDecoration(
                  hintText: 'Add a comment…',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _addComment,
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}
