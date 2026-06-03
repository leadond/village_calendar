import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
import '../../state/providers.dart';
import '../subscriptions/paywall_screen.dart';

/// Helper-side control to share live location during an active trip. Only
/// streams while the toggle is on and the tab is open (foreground web).
class HelperLiveShare extends ConsumerStatefulWidget {
  const HelperLiveShare({super.key, required this.request});
  final HelpRequest request;

  @override
  ConsumerState<HelperLiveShare> createState() => _HelperLiveShareState();
}

class _HelperLiveShareState extends ConsumerState<HelperLiveShare> {
  StreamSubscription<Position>? _sub;
  bool _sharing = false;
  int _sent = 0;
  String? _error;

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _toggle(bool on) async {
    if (!on) {
      await _sub?.cancel();
      _sub = null;
      setState(() => _sharing = false);
      return;
    }

    // Live GPS sharing is a Premium feature.
    if (!await requirePremium(context, ref)) {
      setState(() => _error = 'Live location sharing requires Premium.');
      return;
    }

    final loc = ref.read(locationServiceProvider);
    final granted = await loc.ensurePermission();
    if (!granted) {
      setState(() => _error = 'Location permission denied.');
      return;
    }

    setState(() {
      _sharing = true;
      _error = null;
    });

    _sub = loc.positionStream().listen((pos) async {
      try {
        await ref.read(gpsRepositoryProvider).insertBreadcrumb(
              requestId: widget.request.id,
              lat: pos.latitude,
              lng: pos.longitude,
              accuracy: pos.accuracy,
              speed: pos.speed,
              heading: pos.heading,
            );
        if (mounted) setState(() => _sent++);
      } catch (_) {
        // transient write failures are ignored; next tick retries
      }
    }, onError: (e) {
      if (mounted) {
        setState(() {
          _error = 'Location error: $e';
          _sharing = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.share_location),
            title: const Text('Share my live location'),
            subtitle: Text(_sharing
                ? 'Sharing… $_sent updates sent'
                : 'Off — turn on so the parent can follow your trip'),
            value: _sharing,
            onChanged: _toggle,
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text(_error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
        ],
      ),
    );
  }
}

/// Parent-side live view of the helper's position. Map renders once a Google
/// Maps JS key is configured; until then we show live coordinates + trail.
class ParentLiveView extends ConsumerWidget {
  const ParentLiveView({super.key, required this.request});
  final HelpRequest request;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(breadcrumbsStreamProvider(request.id));

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Could not load location.\n$e'),
          data: (crumbs) {
            if (crumbs.isEmpty) {
              return const Row(
                children: [
                  Icon(Icons.location_searching),
                  SizedBox(width: 12),
                  Expanded(
                      child: Text('Waiting for the helper to share location…')),
                ],
              );
            }
            final latest = crumbs.last;
            final coords =
                '${latest.lat.toStringAsFixed(5)}, ${latest.lng.toStringAsFixed(5)}';
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.my_location, color: theme.colorScheme.primary),
                    const SizedBox(width: 8),
                    Text('Helper location',
                        style: theme.textTheme.titleSmall),
                  ],
                ),
                const SizedBox(height: 8),
                SelectableText(coords,
                    style: theme.textTheme.titleMedium),
                Text('Updated ${DateFormat('h:mm:ss a').format(latest.ts)}'
                    '${latest.accuracy != null ? ' · ±${latest.accuracy!.round()}m' : ''}'),
                Text('${crumbs.length} points in this trip',
                    style: theme.textTheme.labelSmall),
                const SizedBox(height: 8),
                Text(
                  'Live map needs a Google Maps key — add it and I\'ll render '
                  'the route here.',
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
