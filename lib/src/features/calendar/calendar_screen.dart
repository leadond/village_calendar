import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/availability_block.dart';
import '../../models/help_request.dart';
import '../../state/providers.dart';
import '../requests/request_detail_screen.dart';
import 'availability_screen.dart';
import 'blackout_and_roster.dart';

/// Week-view "mutual calendar": village help requests + your own schedule blocks.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  late DateTime _weekStart = _mondayOf(DateTime.now());

  static DateTime _mondayOf(DateTime d) {
    final date = DateTime(d.year, d.month, d.day);
    return date.subtract(Duration(days: date.weekday - 1));
  }

  @override
  Widget build(BuildContext context) {
    final requests = ref.watch(weekRequestsProvider(_weekStart)).value ?? const [];
    final myBlocks = ref.watch(myAvailabilityProvider).value ?? const [];
    final weekEnd = _weekStart.add(const Duration(days: 6));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            tooltip: 'Who’s available',
            icon: const Icon(Icons.people_alt_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const WhoIsAvailableScreen(),
            )),
          ),
          IconButton(
            tooltip: 'Blackout dates',
            icon: const Icon(Icons.event_busy),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const BlackoutDatesScreen(),
            )),
          ),
          IconButton(
            tooltip: 'My schedule',
            icon: const Icon(Icons.event_available),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const AvailabilityScreen(),
            )),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.chevron_left),
                  onPressed: () => setState(() =>
                      _weekStart = _weekStart.subtract(const Duration(days: 7))),
                ),
                Expanded(
                  child: Text(
                    '${DateFormat('MMM d').format(_weekStart)} – '
                    '${DateFormat('MMM d').format(weekEnd)}',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.chevron_right),
                  onPressed: () => setState(() =>
                      _weekStart = _weekStart.add(const Duration(days: 7))),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(weekRequestsProvider(_weekStart));
                ref.invalidate(myAvailabilityProvider);
              },
              child: ListView.builder(
                itemCount: 7,
                itemBuilder: (context, i) {
                  final day = _weekStart.add(Duration(days: i));
                  final dayRequests = requests
                      .where((r) =>
                          r.scheduledStart.year == day.year &&
                          r.scheduledStart.month == day.month &&
                          r.scheduledStart.day == day.day)
                      .toList();
                  final dayBlocks =
                      myBlocks.where((b) => b.appliesOn(day)).toList();
                  return _DaySection(
                    day: day,
                    requests: dayRequests,
                    blocks: dayBlocks,
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DaySection extends StatelessWidget {
  const _DaySection({
    required this.day,
    required this.requests,
    required this.blocks,
  });

  final DateTime day;
  final List<HelpRequest> requests;
  final List<AvailabilityBlock> blocks;

  Color _kindColor(BuildContext context, String kind) {
    switch (kind) {
      case 'work':
        return Colors.blue.shade100;
      case 'available':
        return Colors.green.shade100;
      default:
        return Colors.grey.shade300;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(day, DateTime.now());
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, MMM d').format(day),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: isToday ? Theme.of(context).colorScheme.primary : null,
                ),
          ),
          const SizedBox(height: 4),
          if (blocks.isNotEmpty)
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final b in blocks)
                  Chip(
                    backgroundColor: _kindColor(context, b.kind),
                    visualDensity: VisualDensity.compact,
                    label: Text('${b.kind}: ${b.label}',
                        style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          if (requests.isEmpty && blocks.isEmpty)
            Text('—', style: Theme.of(context).textTheme.bodySmall),
          for (final r in requests)
            Card(
              margin: const EdgeInsets.symmetric(vertical: 3),
              child: ListTile(
                dense: true,
                leading: const Icon(Icons.handshake_outlined),
                title: Text(r.title),
                subtitle: Text(
                    '${DateFormat('h:mm a').format(r.scheduledStart)} · ${r.status.label}'),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => RequestDetailScreen(request: r),
                )),
              ),
            ),
          const Divider(height: 12),
        ],
      ),
    );
  }
}
