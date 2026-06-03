import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/profile.dart';
import '../../state/providers.dart';

/// Admin-only management of the active village's members + audit log.
class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  static const _roles = ['parent', 'helper', 'admin', 'guest'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(villageMembersProvider);
    final myId = ref.watch(currentUserProvider)?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage village'),
        actions: [
          IconButton(
            tooltip: 'Audit log',
            icon: const Icon(Icons.receipt_long),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AuditLogScreen()),
            ),
          ),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load.\n$e')),
        data: (members) => ListView(
          padding: const EdgeInsets.all(12),
          children: [
            for (final m in members)
              Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Text(m.displayName.isNotEmpty
                        ? m.displayName[0].toUpperCase()
                        : '?'),
                  ),
                  title: Text(m.displayName),
                  subtitle: Text(m.email),
                  trailing: m.id == myId
                      ? const Chip(label: Text('You'))
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            DropdownButton<String>(
                              value: _roles.contains(m.role.name)
                                  ? m.role.name
                                  : 'parent',
                              underline: const SizedBox.shrink(),
                              items: [
                                for (final r in _roles)
                                  DropdownMenuItem(
                                      value: r,
                                      child: Text(UserRole.fromName(r).label)),
                              ],
                              onChanged: (r) async {
                                if (r == null) return;
                                await ref
                                    .read(villageRepositoryProvider)
                                    .setMemberRole(m.id, r);
                                ref.invalidate(villageMembersProvider);
                              },
                            ),
                            IconButton(
                              tooltip: 'Remove',
                              icon: const Icon(Icons.person_remove_outlined),
                              onPressed: () =>
                                  _confirmRemove(context, ref, m),
                            ),
                          ],
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmRemove(
      BuildContext context, WidgetRef ref, Profile m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member?'),
        content: Text('Remove ${m.displayName} from this village?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Remove')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(villageRepositoryProvider).removeMember(m.id);
      ref.invalidate(villageMembersProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }
}

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  late Future<List<Map<String, dynamic>>> _future =
      ref.read(villageRepositoryProvider).activeVillageAudit();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Audit log')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('No audit entries yet.'));
          }
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _future =
                  ref.read(villageRepositoryProvider).activeVillageAudit());
              await _future;
            },
            child: ListView.separated(
              itemCount: rows.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final r = rows[i];
                final ts = DateTime.tryParse(r['created_at'] as String? ?? '')
                        ?.toLocal() ??
                    DateTime.now();
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text((r['action'] as String?) ?? ''),
                  subtitle: Text('by ${(r['actor_name'] as String?) ?? 'someone'}'),
                  trailing: Text(DateFormat('MMM d\nh:mm a').format(ts),
                      textAlign: TextAlign.right,
                      style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
