import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../models/breadcrumb.dart';
import '../../models/help_request.dart';
import '../../state/providers.dart';

final tripProvider =
    StateNotifierProvider<TripNotifier, List<Map<String, dynamic>>>((ref) {
  return TripNotifier();
});

class TripNotifier extends StateNotifier<List<Map<String, dynamic>>> {
  TripNotifier() : super([]);

  void addTrip(String destination, DateTime time) {
    state = [
      ...state,
      {'id': const Uuid().v4(), 'destination': destination, 'time': time},
    ];
  }

  void removeTrip(String id) {
    state = state.where((trip) => trip['id'] != id).toList();
  }
}

class TripTracking extends ConsumerWidget {
  const TripTracking({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Trip Tracking')),
      body: ListView.builder(
        itemCount: trips.length,
        itemBuilder: (context, index) {
          final trip = trips[index];
          return ListTile(
            title: Text(trip['destination'] as String),
            subtitle: Text('${trip['time']}'),
            trailing: IconButton(
              icon: const Icon(Icons.delete),
              onPressed: () {
                ref.read(tripProvider.notifier).removeTrip(trip['id'] as String);
              },
            ),
          );
        },
      ),
    );
  }
}

class HelperLiveShare extends ConsumerWidget {
  const HelperLiveShare({super.key, required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crumbs = ref.watch(breadcrumbsStreamProvider(request.id));
    return _LiveTripCard(
      title: 'Live helper sharing',
      subtitle:
          'Location sharing is active for this trip. Parents can follow progress in real time.',
      icon: Icons.my_location,
      child: crumbs.when(
        loading: () => const _LiveTripLoading(),
        error: (error, _) => _LiveTripMessage(
          icon: Icons.error_outline,
          message: 'Could not load live location: $error',
        ),
        data: (items) {
          final latest = items.isNotEmpty ? items.last : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (latest == null)
                const _LiveTripMessage(
                  icon: Icons.location_searching,
                  message: 'No GPS breadcrumbs yet. Start moving and the trip trail will appear here.',
                )
              else
                _BreadcrumbSummary(latest: latest, count: items.length),
            ],
          );
        },
      ),
    );
  }
}

class ParentLiveView extends ConsumerWidget {
  const ParentLiveView({super.key, required this.request});

  final HelpRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final crumbs = ref.watch(breadcrumbsStreamProvider(request.id));
    return _LiveTripCard(
      title: 'Parent live view',
      subtitle:
          'Follow the helper on the active trip. The most recent breadcrumb is shown below.',
      icon: Icons.route,
      child: crumbs.when(
        loading: () => const _LiveTripLoading(),
        error: (error, _) => _LiveTripMessage(
          icon: Icons.error_outline,
          message: 'Could not load helper location: $error',
        ),
        data: (items) {
          final latest = items.isNotEmpty ? items.last : null;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (latest == null)
                const _LiveTripMessage(
                  icon: Icons.map_outlined,
                  message: 'Waiting for the helper to begin location sharing.',
                )
              else
                _BreadcrumbSummary(latest: latest, count: items.length),
            ],
          );
        },
      ),
    );
  }
}

class _LiveTripCard extends StatelessWidget {
  const _LiveTripCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _LiveTripLoading extends StatelessWidget {
  const _LiveTripLoading();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox.square(
          dimension: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        SizedBox(width: 12),
        Expanded(child: Text('Loading live trip updates...')),
      ],
    );
  }
}

class _LiveTripMessage extends StatelessWidget {
  const _LiveTripMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Text(message)),
      ],
    );
  }
}

class _BreadcrumbSummary extends StatelessWidget {
  const _BreadcrumbSummary({required this.latest, required this.count});

  final Breadcrumb latest;
  final int count;

  @override
  Widget build(BuildContext context) {
    final formatter = DateFormat('MMM d, h:mm a');
    final rows = <(String, String)>[
      ('Updated', formatter.format(latest.ts)),
      ('Coordinates', '${latest.lat.toStringAsFixed(5)}, ${latest.lng.toStringAsFixed(5)}'),
      ('Accuracy', latest.accuracy == null ? 'Unknown' : '${latest.accuracy!.toStringAsFixed(0)} m'),
      ('Trail points', '$count'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 100,
                  child: Text(
                    row.$1,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
                Expanded(child: Text(row.$2)),
              ],
            ),
          ),
      ],
    );
  }
}
