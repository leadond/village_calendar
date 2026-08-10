import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
import '../../state/providers.dart';

DateTime _at(DateTime day, int mins) =>
    DateTime(day.year, day.month, day.day, mins ~/ 60, mins % 60);

/// Computes coverage gaps (parent working AND kid not in school/daycare) for the
/// next 14 days and creates DRAFT requests. Runs in local time to avoid
/// timezone drift. Returns how many drafts were created.
Future<int> generateCareDrafts(WidgetRef ref) async {
  final profile = ref.read(currentProfileProvider).value;
  if (profile == null || !profile.hasVillage) return 0;
  final repo = ref.read(helpRequestRepositoryProvider);

  final blocks = await ref.read(availabilityRepositoryProvider).forUser(profile.id);
  final work = blocks.where((b) => b.kind == 'work').toList();
  final kids = (ref.read(myKidsProvider).value ?? const [])
      .where((k) => k.hasCareWindow)
      .toList();
  if (work.isEmpty || kids.isEmpty) return 0;

  final existing = await repo.myDrafts(profile.villageId!, profile.id);
  bool dup(DateTime start, String kidId) => existing.any(
      (r) => r.scheduledStart.isAtSameMomentAs(start) && r.kidIds.contains(kidId));

  var created = 0;
  final today = DateTime.now();
  for (var i = 0; i < 14; i++) {
    final day = DateTime(today.year, today.month, today.day).add(Duration(days: i));
    final dayWork = work.where((b) => b.appliesOn(day)).toList();
    if (dayWork.isEmpty) continue;

    for (final k in kids) {
      if (!k.careWeekdays.contains(day.weekday)) continue;
      for (final wb in dayWork) {
        // Morning: parent starts work before school/daycare opens.
        if (wb.startMinutes < k.careStartMinutes!) {
          final start = _at(day, wb.startMinutes);
          final end = _at(day, k.careStartMinutes!);
          if (!dup(start, k.id)) {
            await repo.createDraft(
              villageId: profile.villageId!,
              creatorId: profile.id,
              title: 'Morning care – ${k.name}',
              category: HelpCategory.babysitting,
              start: start,
              end: end,
              kidIds: [k.id],
              description:
                  'Auto-created from your work schedule (before school/daycare opens).',
            );
            created++;
          }
        }
        // Afternoon: parent works past school/daycare close -> pickup + care.
        if (wb.endMinutes > k.careEndMinutes!) {
          final start = _at(day, k.careEndMinutes!);
          final end = _at(day, wb.endMinutes);
          if (!dup(start, k.id)) {
            await repo.createDraft(
              villageId: profile.villageId!,
              creatorId: profile.id,
              title: 'Pickup & care – ${k.name}',
              category: HelpCategory.schoolPickup,
              start: start,
              end: end,
              kidIds: [k.id],
              description:
                  'Auto-created from your work schedule (after school/daycare ends).',
            );
            created++;
          }
        }
      }
    }
  }
  return created;
}

class DraftsReviewScreen extends ConsumerStatefulWidget {
  const DraftsReviewScreen({super.key});

  @override
  ConsumerState<DraftsReviewScreen> createState() => _DraftsReviewScreenState();
}

class _DraftsReviewScreenState extends ConsumerState<DraftsReviewScreen> {
  bool _busy = false;

  Future<void> _generate() async {
    setState(() => _busy = true);
    try {
      final n = await generateCareDrafts(ref);
      ref.invalidate(myDraftsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(n == 0
              ? 'No new drafts. Add work hours (My schedule) and kid school/daycare hours first.'
              : 'Created $n draft request${n == 1 ? '' : 's'} to review.'),
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not generate: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publishAll(List<HelpRequest> drafts) async {
    setState(() => _busy = true);
    try {
      final repo = ref.read(helpRequestRepositoryProvider);
      for (final d in drafts) {
        await repo.publishDraft(d.id);
      }
      ref.invalidate(myDraftsProvider);
      ref.invalidate(myRequestsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('All drafts published to the village.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editTime(HelpRequest r) async {
    final date = r.scheduledStart;
    final startTod = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(r.scheduledStart),
      helpText: 'Start time',
    );
    if (startTod == null || !mounted) return;
    final endTod = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
          r.scheduledEnd ?? r.scheduledStart.add(const Duration(hours: 2))),
      helpText: 'End time',
    );
    if (endTod == null) return;
    final start =
        DateTime(date.year, date.month, date.day, startTod.hour, startTod.minute);
    final end =
        DateTime(date.year, date.month, date.day, endTod.hour, endTod.minute);
    await ref.read(helpRequestRepositoryProvider).updateSchedule(r.id, start, end);
    ref.invalidate(myDraftsProvider);
  }

  @override
  Widget build(BuildContext context) {
    final drafts = ref.watch(myDraftsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(
        title: const Text('Auto-scheduled drafts'),
        actions: [
          if (drafts.isNotEmpty)
            TextButton(
              onPressed: _busy ? null : () => _publishAll(drafts),
              child: const Text('Publish all'),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'requests-review-drafts-fab',
        onPressed: _busy ? null : _generate,
        icon: _busy
            ? const SizedBox.square(
                dimension: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.auto_awesome),
        label: const Text('Generate'),
      ),
      body: drafts.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No drafts yet.\n\nSet your work hours (Profile → My schedule) '
                  'and each kid\'s school/daycare hours (Kids), then tap '
                  'Generate. The app finds the gaps where a sitter is needed and '
                  'creates drafts for you to review and publish.',
                  textAlign: TextAlign.center,
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Text(
                    'Review and adjust, then publish. Nothing is sent to the '
                    'village until you publish.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                for (final r in drafts)
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.auto_awesome_outlined),
                      title: Text(r.title),
                      subtitle: Text(
                        '${DateFormat('EEE, MMM d').format(r.scheduledStart)} · '
                        '${DateFormat('h:mm a').format(r.scheduledStart)}'
                        '${r.scheduledEnd != null ? ' – ${DateFormat('h:mm a').format(r.scheduledEnd!)}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Adjust time',
                            icon: const Icon(Icons.schedule),
                            onPressed: () => _editTime(r),
                          ),
                          IconButton(
                            tooltip: 'Publish',
                            icon: const Icon(Icons.publish, color: Colors.green),
                            onPressed: () async {
                              await ref
                                  .read(helpRequestRepositoryProvider)
                                  .publishDraft(r.id);
                              ref.invalidate(myDraftsProvider);
                              ref.invalidate(myRequestsProvider);
                            },
                          ),
                          IconButton(
                            tooltip: 'Discard',
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () async {
                              await ref
                                  .read(helpRequestRepositoryProvider)
                                  .deleteRequest(r.id);
                              ref.invalidate(myDraftsProvider);
                            },
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
