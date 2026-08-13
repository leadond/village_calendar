import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/availability_block.dart';
import '../../state/providers.dart';

/// Helpers mark specific dates they are NOT available (vacations, etc.).
/// Stored as full-day `unavailable` blocks with a specific_date.
class BlackoutDatesScreen extends ConsumerWidget {
  const BlackoutDatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAvailabilityProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Blackout dates')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'blackout-add-fab',
        onPressed: () => _addDate(context, ref),
        icon: const Icon(Icons.event_busy),
        label: const Text('Add date'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (blocks) {
          final blackout = blocks
              .where((b) => b.kind == 'unavailable' && !b.isRecurring)
              .toList()
            ..sort((a, b) => a.specificDate!.compareTo(b.specificDate!));
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 4, 4, 12),
                child: Text(
                  'Add the days you can’t help. Parents see these on the '
                  'availability roster and won’t be notified to ask you on '
                  'those days.',
                  style: TextStyle(fontSize: 13),
                ),
              ),
              if (blackout.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('No blackout dates yet.')),
                ),
              for (final b in blackout)
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.event_busy, color: Colors.red),
                    title: Text(
                        DateFormat('EEEE, MMM d, y').format(b.specificDate!)),
                    subtitle: b.note != null && b.note!.isNotEmpty
                        ? Text(b.note!)
                        : null,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        await ref
                            .read(availabilityRepositoryProvider)
                            .delete(b.id);
                        ref.invalidate(myAvailabilityProvider);
                        ref.invalidate(villageAvailabilityProvider);
                      },
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addDate(BuildContext context, WidgetRef ref) async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || !profile.hasVillage) return;
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 365)),
      helpText: 'Pick a day you are unavailable',
    );
    if (picked == null) return;
    try {
      await ref.read(availabilityRepositoryProvider).add(
            villageId: profile.villageId!,
            kind: 'unavailable',
            startMinutes: 0,
            endMinutes: 1439,
            specificDate: picked,
            note: 'Blackout',
          );
      ref.invalidate(myAvailabilityProvider);
      ref.invalidate(villageAvailabilityProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not add: $e')));
      }
    }
  }
}

/// Parents see who in the village is available/unavailable on a chosen day, so
/// they can make other arrangements.
class WhoIsAvailableScreen extends ConsumerStatefulWidget {
  const WhoIsAvailableScreen({super.key});

  @override
  ConsumerState<WhoIsAvailableScreen> createState() =>
      _WhoIsAvailableScreenState();
}

class _WhoIsAvailableScreenState extends ConsumerState<WhoIsAvailableScreen> {
  late DateTime _date = DateTime.now();

  ({String label, Color color}) _status(
      List<AvailabilityBlock> memberBlocks) {
    final onDay = memberBlocks.where((b) => b.appliesOn(_date)).toList();
    if (onDay.any((b) => b.kind == 'unavailable')) {
      return (label: 'Unavailable', color: Colors.red);
    }
    if (onDay.any((b) => b.kind == 'work')) {
      return (label: 'Working', color: Colors.orange);
    }
    return (label: 'Available', color: Colors.green);
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(villageMembersProvider).value ?? const [];
    final blocks = ref.watch(villageAvailabilityProvider).value ?? const [];
    final myId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(title: const Text('Who’s available')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(
                      () => _date = _date.subtract(const Duration(days: 1))),
                ),
                Expanded(
                  child: TextButton(
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _date,
                        firstDate: DateTime(now.year - 1),
                        lastDate: now.add(const Duration(days: 365)),
                      );
                      if (picked != null) setState(() => _date = picked);
                    },
                    child: Text(DateFormat('EEEE, MMM d, y').format(_date),
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(
                      () => _date = _date.add(const Duration(days: 1))),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: members.isEmpty
                ? const Center(child: Text('No village members.'))
                : ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      for (final m in members)
                        Builder(builder: (context) {
                          final s = _status(
                              blocks.where((b) => b.userId == m.id).toList());
                          return Card(
                            child: ListTile(
                              leading: CircleAvatar(
                                child: Text(m.displayName.isNotEmpty
                                    ? m.displayName[0].toUpperCase()
                                    : '?'),
                              ),
                              title: Text(m.id == myId
                                  ? '${m.displayName} (you)'
                                  : m.displayName),
                              subtitle: Text(m.role.label),
                              trailing: Chip(
                                label: Text(s.label,
                                    style:
                                        const TextStyle(color: Colors.white)),
                                backgroundColor: s.color,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                          );
                        }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
