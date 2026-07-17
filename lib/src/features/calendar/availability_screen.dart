import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/availability_block.dart';
import '../../models/profile.dart';
import '../../state/providers.dart';

const _kindLabels = {
  'work': 'Work (need coverage)',
  'available': 'Available to help',
  'unavailable': 'Unavailable',
};

const _kindIcons = {
  'work': Icons.work_outline,
  'available': Icons.check_circle_outline,
  'unavailable': Icons.block,
};

class AvailabilityScreen extends ConsumerWidget {
  const AvailabilityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myAvailabilityProvider);
    final isHelper = ref.watch(activeRoleProvider) == UserRole.helper;

    return Scaffold(
      appBar: AppBar(title: const Text('My schedule')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addSheet(context, ref, isHelper ? 'available' : 'work'),
        icon: const Icon(Icons.add),
        label: const Text('Add block'),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (blocks) {
          if (blocks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Add your weekly work hours (parents) or the times you can '
                  'help (helpers). The village calendar and request '
                  'notifications use this.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              for (final b in blocks)
                Card(
                  child: ListTile(
                    leading: Icon(_kindIcons[b.kind]),
                    title: Text(b.isRecurring
                        ? 'Every ${kWeekdayNames[b.weekday ?? 0]}'
                        : '${b.specificDate!.month}/${b.specificDate!.day}'),
                    subtitle: Text('${_kindLabels[b.kind]} · ${b.label}'
                        '${b.note != null && b.note!.isNotEmpty ? ' · ${b.note}' : ''}'),
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

  Future<void> _addSheet(
      BuildContext context, WidgetRef ref, String defaultKind) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AddAvailabilitySheet(defaultKind: defaultKind),
    );
  }
}

class _AddAvailabilitySheet extends ConsumerStatefulWidget {
  const _AddAvailabilitySheet({required this.defaultKind});
  final String defaultKind;

  @override
  ConsumerState<_AddAvailabilitySheet> createState() =>
      _AddAvailabilitySheetState();
}

class _AddAvailabilitySheetState extends ConsumerState<_AddAvailabilitySheet> {
  late String _kind = widget.defaultKind;
  final Set<int> _weekdays = {DateTime.now().weekday % 7};
  TimeOfDay _start = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _end = const TimeOfDay(hour: 17, minute: 0);
  final _note = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  int _mins(TimeOfDay t) => t.hour * 60 + t.minute;

  Future<void> _save() async {
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || !profile.hasVillage || _weekdays.isEmpty) return;
    if (_mins(_end) <= _mins(_start)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('End time must be after start time.')),
      );
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(availabilityRepositoryProvider);
      for (final wd in _weekdays) {
        await repo.add(
          villageId: profile.villageId!,
          kind: _kind,
          startMinutes: _mins(_start),
          endMinutes: _mins(_end),
          weekday: wd,
          note: _note.text.trim().isEmpty ? null : _note.text.trim(),
        );
      }
      ref.invalidate(myAvailabilityProvider);
      ref.invalidate(villageAvailabilityProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add schedule block',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final k in _kindLabels.keys)
                ChoiceChip(
                  label: Text(_kindLabels[k]!),
                  selected: _kind == k,
                  onSelected: (_) => setState(() => _kind = k),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Repeats on'),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (var wd = 0; wd < 7; wd++)
                FilterChip(
                  label: Text(kWeekdayNames[wd]),
                  selected: _weekdays.contains(wd),
                  onSelected: (sel) => setState(() {
                    if (sel) {
                      _weekdays.add(wd);
                    } else {
                      _weekdays.remove(wd);
                    }
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _start);
                    if (t != null) setState(() => _start = t);
                  },
                  child: Text('Start: ${_start.format(context)}'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final t = await showTimePicker(
                        context: context, initialTime: _end);
                    if (t != null) setState(() => _end = t);
                  },
                  child: Text('End: ${_end.format(context)}'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
