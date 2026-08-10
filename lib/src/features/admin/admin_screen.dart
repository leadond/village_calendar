import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/profile.dart';
import '../../state/providers.dart';

class AdminScreen extends ConsumerWidget {
  const AdminScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(activeRoleProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => _refresh(ref),
          ),
        ],
      ),
      body: role != UserRole.admin
          ? const _AdminGuard()
          : RefreshIndicator(
              onRefresh: () async => _refresh(ref),
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: const [
                  _AdminStatsSection(),
                  SizedBox(height: 24),
                  _PendingApprovalsSection(),
                  SizedBox(height: 24),
                  _MemberManagementSection(),
                  SizedBox(height: 24),
                  _AnnouncementSection(),
                ],
              ),
            ),
    );
  }

  void _refresh(WidgetRef ref) {
    ref.invalidate(adminDashboardStatsProvider);
    ref.invalidate(villageMembersProvider);
    ref.invalidate(pendingJoinRequestsProvider);
    ref.invalidate(announcementsProvider);
    ref.invalidate(myVillagesProvider);
    ref.invalidate(currentProfileProvider);
    ref.invalidate(currentVillageProvider);
  }
}

class _AdminGuard extends StatelessWidget {
  const _AdminGuard();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Text(
          'You need admin access in the active village to use this dashboard.',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}

class _AdminStatsSection extends ConsumerWidget {
  const _AdminStatsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminDashboardStatsProvider);

    return statsAsync.when(
      loading: () => const _SectionLoading(),
      error: (error, _) => _SectionError(message: 'Could not load stats.\n$error'),
      data: (stats) {
        final items = [
          _StatItem(
            label: 'Members',
            value: '${stats.memberCount}',
            icon: Icons.people_alt_outlined,
          ),
          _StatItem(
            label: 'Pending approvals',
            value: '${stats.pendingApprovals}',
            icon: Icons.approval_outlined,
          ),
          _StatItem(
            label: 'Open requests',
            value: '${stats.openRequests}',
            icon: Icons.assignment_late_outlined,
          ),
          _StatItem(
            label: 'Active trips',
            value: '${stats.activeTrips}',
            icon: Icons.directions_car_filled_outlined,
          ),
          _StatItem(
            label: 'Announcements',
            value: '${stats.announcementCount}',
            icon: Icons.campaign_outlined,
          ),
          _StatItem(
            label: 'Premium members',
            value: '${stats.premiumMembers}',
            icon: Icons.workspace_premium_outlined,
          ),
        ];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionTitle(
              title: 'Village Snapshot',
              subtitle: 'Live metrics from the active village workspace.',
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 1.45,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          item.icon,
                          size: 28,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          item.value,
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          item.label,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _PendingApprovalsSection extends ConsumerWidget {
  const _PendingApprovalsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingJoinRequestsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Pending Join Requests',
          subtitle: 'Approve or reject village membership requests.',
        ),
        const SizedBox(height: 12),
        pendingAsync.when(
          loading: () => const _SectionLoading(),
          error: (error, _) =>
              _SectionError(message: 'Could not load join requests.\n$error'),
          data: (requests) {
            if (requests.isEmpty) {
              return const _EmptyCard(message: 'No pending join requests right now.');
            }

            return Column(
              children: [
                for (final request in requests)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          request.displayName.isNotEmpty
                              ? request.displayName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(request.displayName),
                      subtitle: Text(
                        '${request.email}\nRequested ${DateFormat('MMM d, h:mm a').format(request.createdAt)}',
                      ),
                      isThreeLine: true,
                      trailing: Wrap(
                        spacing: 8,
                        children: [
                          IconButton(
                            tooltip: 'Approve',
                            icon: const Icon(Icons.check_circle, color: Colors.green),
                            onPressed: () => _handleRequestAction(
                              context,
                              ref,
                              request.requestId,
                              approve: true,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Reject',
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => _handleRequestAction(
                              context,
                              ref,
                              request.requestId,
                              approve: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleRequestAction(
    BuildContext context,
    WidgetRef ref,
    String requestId, {
    required bool approve,
  }) async {
    try {
      final repo = ref.read(villageRepositoryProvider);
      if (approve) {
        await repo.approveJoin(requestId);
      } else {
        await repo.rejectJoin(requestId);
      }
      ref.invalidate(pendingJoinRequestsProvider);
      ref.invalidate(villageMembersProvider);
      ref.invalidate(adminDashboardStatsProvider);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? 'Join request approved.' : 'Join request rejected.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update request: $error')),
        );
      }
    }
  }
}

class _MemberManagementSection extends ConsumerWidget {
  const _MemberManagementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(villageMembersProvider);
    final me = ref.watch(currentUserProvider)?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Member Management',
          subtitle: 'Review roles, plans, and member-level admin actions.',
        ),
        const SizedBox(height: 12),
        membersAsync.when(
          loading: () => const _SectionLoading(),
          error: (error, _) =>
              _SectionError(message: 'Could not load members.\n$error'),
          data: (members) {
            if (members.isEmpty) {
              return const _EmptyCard(message: 'No village members found.');
            }

            return Column(
              children: [
                for (final member in members)
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          member.displayName.isNotEmpty
                              ? member.displayName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(member.displayName),
                      subtitle: Text(
                        '${member.email}\n${member.role.label} • ${member.subscriptionTier} • Reliability ${member.reliabilityScore.toStringAsFixed(1)}',
                      ),
                      isThreeLine: true,
                      trailing: member.id == me
                          ? const Chip(label: Text('You'))
                          : PopupMenuButton<String>(
                              onSelected: (value) => _handleMemberAction(
                                context,
                                ref,
                                member,
                                value,
                              ),
                              itemBuilder: (context) => [
                                for (final role in UserRole.values)
                                  PopupMenuItem<String>(
                                    value: 'role:${role.name}',
                                    child: Text('Set role: ${role.label}'),
                                  ),
                                const PopupMenuDivider(),
                                const PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Text('Remove from village'),
                                ),
                              ],
                            ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _handleMemberAction(
    BuildContext context,
    WidgetRef ref,
    Profile member,
    String value,
  ) async {
    final repo = ref.read(villageRepositoryProvider);

    try {
      if (value == 'remove') {
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Remove member'),
            content: Text('Remove ${member.displayName} from this village?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Remove'),
              ),
            ],
          ),
        );

        if (confirmed != true) return;
        await repo.removeMember(member.id);
      } else if (value.startsWith('role:')) {
        final role = value.split(':').last;
        await repo.setMemberRole(member.id, role);
      }

      ref.invalidate(villageMembersProvider);
      ref.invalidate(myVillagesProvider);
      ref.invalidate(currentProfileProvider);
      ref.invalidate(adminDashboardStatsProvider);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Updated ${member.displayName}.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not update member: $error')),
        );
      }
    }
  }
}

class _AnnouncementSection extends ConsumerWidget {
  const _AnnouncementSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final announcementsAsync = ref.watch(announcementsProvider);
    final names = ref.watch(memberNameLookupProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(
          title: 'Recent Announcements',
          subtitle: 'Latest village-wide broadcasts from real activity.',
        ),
        const SizedBox(height: 12),
        announcementsAsync.when(
          loading: () => const _SectionLoading(),
          error: (error, _) =>
              _SectionError(message: 'Could not load announcements.\n$error'),
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyCard(message: 'No village announcements yet.');
            }

            return Column(
              children: [
                for (final item in items.take(5))
                  Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(item.title),
                      subtitle: Text(
                        '${item.message}\n${names[item.createdBy] ?? 'Member'} • ${DateFormat('MMM d, h:mm a').format(item.createdAt)}',
                      ),
                      isThreeLine: true,
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ],
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(message),
      ),
    );
  }
}

class _StatItem {
  const _StatItem({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;
}
