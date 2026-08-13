import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
import '../../models/kid_profile.dart';
import '../../state/providers.dart';
import '../kids/kids_tab.dart';
import 'care_scheduler.dart';
import 'create_request_screen.dart';
import 'request_detail_screen.dart';

class RequestsTab extends ConsumerStatefulWidget {
  const RequestsTab({super.key});

  @override
  ConsumerState<RequestsTab> createState() => _RequestsTabState();
}

class _RequestsTabState extends ConsumerState<RequestsTab> {
  bool _available = false; // false = Mine, true = Available

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Requests'),
        actions: [
          IconButton(
            tooltip: 'Auto-schedule from work hours',
            icon: const Icon(Icons.auto_awesome),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DraftsReviewScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(myRequestsProvider);
              ref.invalidate(availableRequestsProvider);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'requests-new-request-fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateRequestScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('New request'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                    value: false,
                    label: Text('Mine'),
                    icon: Icon(Icons.assignment_ind_outlined)),
                ButtonSegment(
                    value: true,
                    label: Text('Available'),
                    icon: Icon(Icons.handshake_outlined)),
              ],
              selected: {_available},
              onSelectionChanged: (s) => setState(() => _available = s.first),
            ),
          ),
          Expanded(
              child: _available ? const _AvailableList() : const _MineList()),
        ],
      ),
    );
  }
}

class _MineList extends ConsumerWidget {
  const _MineList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myRequestsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load.\n$e')),
      data: (all) {
        if (all.isEmpty) {
          return const _Empty(
              'No requests yet. Tap "New request" to create one.');
        }
        final active = all.where((r) => r.status.isActive).toList();
        final open = all.where((r) => r.status == HelpStatus.open).toList();
        final past = all.where((r) => r.status.isTerminal).toList();
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(myRequestsProvider),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              ..._section(context, 'Active', active),
              ..._section(context, 'Open', open),
              ..._section(context, 'Past', past),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _section(
      BuildContext context, String title, List<HelpRequest> items) {
    if (items.isEmpty) return const [];
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 4),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall),
      ),
      for (final r in items) RequestCard(request: r),
    ];
  }
}

class _AvailableList extends ConsumerWidget {
  const _AvailableList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(availableRequestsProvider);
    final names = ref.watch(memberNameLookupProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Could not load.\n$e')),
      data: (items) {
        if (items.isEmpty) {
          return const _Empty('No open requests in your village right now.');
        }
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(availableRequestsProvider),
          child: ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final r in items)
                RequestCard(
                  request: r,
                  subtitle: 'by ${names[r.creatorId] ?? 'a member'}',
                ),
            ],
          ),
        );
      },
    );
  }
}

class RequestCard extends ConsumerWidget {
  const RequestCard({super.key, required this.request, this.subtitle});

  final HelpRequest request;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final when =
        DateFormat('EEE, MMM d · h:mm a').format(request.scheduledStart);
    final kids = ref.watch(villageKidsProvider).value ?? const <KidProfile>[];
    final requestKids = kids
        .where((kid) => request.kidIds.contains(kid.id))
        .toList(growable: false);
    final kidNames = requestKids.map((kid) => kid.name).join(', ');
    final lines = <String>[
      '${request.category.label} · $when',
      if (kidNames.isNotEmpty) 'Kids: $kidNames',
      if (subtitle != null) subtitle!,
    ];
    return Card(
      child: ListTile(
        leading: requestKids.isEmpty
            ? CircleAvatar(child: Icon(_iconFor(request.category)))
            : _KidAssignmentAvatar(kids: requestKids),
        title: Text(request.title),
        subtitle: Text(lines.join('\n')),
        isThreeLine: lines.length > 1,
        trailing: Chip(
          label: Text(request.status.label),
          visualDensity: VisualDensity.compact,
        ),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => RequestDetailScreen(request: request),
          ),
        ),
      ),
    );
  }

  IconData _iconFor(HelpCategory c) {
    switch (c) {
      case HelpCategory.schoolPickup:
      case HelpCategory.schoolDropoff:
        return Icons.directions_bus;
      case HelpCategory.sportsPractice:
        return Icons.sports_soccer;
      case HelpCategory.doctorAppointment:
        return Icons.local_hospital;
      case HelpCategory.playdate:
        return Icons.toys;
      case HelpCategory.babysitting:
      case HelpCategory.overnight:
        return Icons.crib;
      case HelpCategory.emergency:
        return Icons.emergency;
      case HelpCategory.event:
      case HelpCategory.party:
        return Icons.celebration;
      case HelpCategory.other:
        return Icons.help_outline;
    }
  }
}

class _KidAssignmentAvatar extends StatelessWidget {
  const _KidAssignmentAvatar({required this.kids});

  final List<KidProfile> kids;

  @override
  Widget build(BuildContext context) {
    final visible = kids.take(2).toList(growable: false);
    if (visible.length == 1) {
      return KidPhotoAvatar(
          stored: visible.first.photoUrl, fallback: visible.first.name);
    }

    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            top: 6,
            child: KidPhotoAvatar(
              stored: visible.first.photoUrl,
              fallback: visible.first.name,
              radius: 14,
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            child: KidPhotoAvatar(
              stored: visible.last.photoUrl,
              fallback: visible.last.name,
              radius: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }
}
