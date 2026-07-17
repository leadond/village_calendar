import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/profile.dart';
import '../../models/village.dart';
import '../../services/setup_services.dart';
import '../../state/providers.dart';
import '../admin/admin_screen.dart';
import '../calendar/availability_screen.dart';
import '../calendar/calendar_screen.dart';
import '../emergency/emergency_screen.dart';
import '../kids/kids_tab.dart';
import '../legal/legal_screens.dart';
import '../messages/messages_hub.dart';
import '../notifications/notification_center.dart';
import '../notifications/notification_settings_screen.dart';
import '../requests/requests_tab.dart';
import '../subscriptions/paywall_screen.dart';
import '../village/join_village_screen.dart';

/// Role-aware app shell shown once the user is signed in and in a village.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.profile});

  final Profile profile;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Persist the FCM token (if Firebase messaging produced one) so the backend
    // can push to this user. No-op until messaging is configured.
    final token = ref.read(setupStatusProvider).firebaseMessagingToken;
    final uid = ref.read(currentUserProvider)?.id;
    if (token != null && token.isNotEmpty && uid != null) {
      ref.read(notificationRepositoryProvider).savePushToken(uid, token);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Role is per-village now: use the role held in the ACTIVE village.
    final role = ref.watch(activeRoleProvider);
    final canManageKids = role == UserRole.parent || role == UserRole.admin;

    final tabs = <_TabDef>[
      _TabDef('Home', Icons.home_outlined, Icons.home, const _HomeTab()),
      _TabDef('Requests', Icons.handshake_outlined, Icons.handshake,
          const RequestsTab()),
      if (canManageKids)
        _TabDef('Kids', Icons.child_care_outlined, Icons.child_care,
            const KidsTab()),
      _TabDef('Village', Icons.groups_outlined, Icons.groups, const _VillageTab()),
      _TabDef('Profile', Icons.person_outline, Icons.person, const _ProfileTab()),
    ];

    final safeIndex = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      body: IndexedStack(
        index: safeIndex,
        children: [for (final t in tabs) t.body],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: safeIndex,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon),
              selectedIcon: Icon(t.selectedIcon),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

class _TabDef {
  const _TabDef(this.label, this.icon, this.selectedIcon, this.body);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget body;
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final villageAsync = ref.watch(currentVillageProvider);
    final members = ref.watch(villageMembersProvider).value ?? const [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
        actions: [
          IconButton(
            tooltip: 'Calendar',
            icon: const Icon(Icons.calendar_month),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CalendarScreen()),
            ),
          ),
          _NotificationBell(
            icon: Icons.chat_bubble_outline,
            tooltip: 'Messages',
            count: ref.watch(unreadDirectCountProvider),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MessagesHub()),
            ),
          ),
          _NotificationBell(
            count: ref.watch(unreadCountProvider),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const NotificationCenterScreen()),
            ),
          ),
          const VillageSwitcherAction(),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Hi ${profile?.displayName ?? 'there'} 👋',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 16),
          const _EmergencyBanner(),
          villageAsync.when(
            loading: () => const Card(
              child: ListTile(
                leading: CircularProgressIndicator(),
                title: Text('Loading your village…'),
              ),
            ),
            error: (e, _) => Card(
              child: ListTile(
                leading: const Icon(Icons.error_outline),
                title: const Text('Could not load village'),
                subtitle: Text('$e'),
              ),
            ),
            data: (village) => _VillageSummaryCard(
              village: village,
              memberCount: members.length,
              role: ref.watch(activeRoleProvider),
            ),
          ),
          const SizedBox(height: 16),
          Text('Quick actions', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const _NextStepCard(
            icon: Icons.handshake_outlined,
            title: 'Help requests',
            subtitle: 'Create a request or claim one in the Requests tab.',
          ),
          const _NextStepCard(
            icon: Icons.child_care,
            title: 'Kid profiles',
            subtitle: 'Add and manage your kids in the Kids tab.',
          ),
        ],
      ),
    );
  }
}

class _VillageSummaryCard extends StatelessWidget {
  const _VillageSummaryCard({
    required this.village,
    required this.memberCount,
    required this.role,
  });

  final Village? village;
  final int memberCount;
  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.holiday_village, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    village?.name ?? 'Your village',
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                Chip(label: Text(role.label)),
              ],
            ),
            const SizedBox(height: 8),
            Text('$memberCount member${memberCount == 1 ? '' : 's'}'),
            if (village != null && village!.inviteCode.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.vpn_key_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('Invite code: ',
                      style: theme.textTheme.bodyMedium),
                  SelectableText(
                    village!.inviteCode,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: 2),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    icon: const Icon(Icons.copy, size: 18),
                    onPressed: () {
                      Clipboard.setData(
                          ClipboardData(text: village!.inviteCode));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Invite code copied')),
                      );
                    },
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NextStepCard extends StatelessWidget {
  const _NextStepCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _VillageTab extends ConsumerWidget {
  const _VillageTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final village = ref.watch(currentVillageProvider).value;
    final membersAsync = ref.watch(villageMembersProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(village?.name ?? 'Village'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(villageMembersProvider);
              ref.invalidate(pendingJoinRequestsProvider);
            },
          ),
          const VillageSwitcherAction(),
        ],
      ),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load members.\n$e')),
        data: (members) {
          return RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(villageMembersProvider);
              ref.invalidate(pendingJoinRequestsProvider);
            },
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                const _PendingRequestsSection(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
                  child: Text('Members (${members.length})',
                      style: Theme.of(context).textTheme.titleSmall),
                ),
                if (members.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No members yet.'),
                  ),
                for (final m in members)
                  Card(
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          m.displayName.isNotEmpty
                              ? m.displayName[0].toUpperCase()
                              : '?',
                        ),
                      ),
                      title: Text(m.displayName),
                      subtitle: Text(m.email),
                      trailing: Chip(
                        label: Text(m.role.label),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Admin-only list of pending join requests with approve/reject actions.
/// Renders nothing for non-admins or when there are no pending requests.
class _PendingRequestsSection extends ConsumerWidget {
  const _PendingRequestsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final requests = ref.watch(pendingJoinRequestsProvider).value ?? const [];
    if (requests.isEmpty) return const SizedBox.shrink();

    Future<void> act(String id, bool approve) async {
      final repo = ref.read(villageRepositoryProvider);
      try {
        if (approve) {
          await repo.approveJoin(id);
        } else {
          await repo.rejectJoin(id);
        }
        ref.invalidate(pendingJoinRequestsProvider);
        ref.invalidate(villageMembersProvider);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(approve ? 'Approved' : 'Rejected')),
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text('Failed: $e')));
        }
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
          child: Text('Pending requests (${requests.length})',
              style: theme.textTheme.titleSmall
                  ?.copyWith(color: theme.colorScheme.primary)),
        ),
        for (final r in requests)
          Card(
            color: theme.colorScheme.secondaryContainer,
            child: ListTile(
              leading: const Icon(Icons.person_add_alt),
              title: Text(r.displayName),
              subtitle: Text(r.email),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Approve',
                    icon: const Icon(Icons.check_circle, color: Colors.green),
                    onPressed: () => act(r.requestId, true),
                  ),
                  IconButton(
                    tooltip: 'Reject',
                    icon: const Icon(Icons.cancel, color: Colors.red),
                    onPressed: () => act(r.requestId, false),
                  ),
                ],
              ),
            ),
          ),
        const Divider(height: 24),
      ],
    );
  }
}

class _ProfileTab extends ConsumerWidget {
  const _ProfileTab();

  Future<void> _signOut(BuildContext context) async {
    await SetupServices.maybeSupabaseClient?.auth.signOut();
    // RootGate reacts to the auth-state change automatically.
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final profile = ref.watch(currentProfileProvider).value;
    final village = ref.watch(currentVillageProvider).value;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: CircleAvatar(
              radius: 36,
              child: Text(
                (profile?.displayName.isNotEmpty ?? false)
                    ? profile!.displayName[0].toUpperCase()
                    : '?',
                style: theme.textTheme.headlineMedium,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              profile?.displayName ?? '',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          Center(child: Text(profile?.email ?? '')),
          const SizedBox(height: 24),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.badge_outlined),
                  title: const Text('Role (this village)'),
                  trailing: Text(ref.watch(activeRoleProvider).label),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.holiday_village_outlined),
                  title: const Text('Village'),
                  trailing: Text(village?.name ?? '—'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.workspace_premium_outlined),
                  title: const Text('Plan'),
                  trailing: Text(profile?.subscriptionTier ?? 'free'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (!ref.watch(isPremiumProvider))
            Card(
              color: theme.colorScheme.tertiaryContainer,
              child: ListTile(
                leading: const Icon(Icons.workspace_premium),
                title: const Text('Upgrade to Premium'),
                subtitle: const Text('Multiple villages, live GPS, carpool automation'),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PaywallScreen()),
                ),
              ),
            ),
          Card(
            child: Column(
              children: [
                if (ref.watch(activeRoleProvider) == UserRole.admin)
                  ListTile(
                    leading: const Icon(Icons.admin_panel_settings_outlined),
                    title: const Text('Manage village'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AdminScreen()),
                    ),
                  ),
                ListTile(
                  leading: const Icon(Icons.event_available_outlined),
                  title: const Text('My schedule / availability'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const AvailabilityScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text('Notification settings'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => const NotificationSettingsScreen()),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description_outlined),
                  title: const Text('Terms of Service'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LegalScreen(
                        title: 'Terms of Service', body: kTermsText),
                  )),
                ),
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined),
                  title: const Text('Privacy Policy'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => const LegalScreen(
                        title: 'Privacy Policy', body: kPrivacyText),
                  )),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: const Icon(Icons.logout),
            label: const Text('Sign out'),
          ),
        ],
      ),
    );
  }
}

class _NotificationBell extends StatelessWidget {
  const _NotificationBell({
    required this.count,
    required this.onTap,
    this.icon = Icons.notifications_none,
    this.tooltip = 'Notifications',
  });
  final int count;
  final VoidCallback onTap;
  final IconData icon;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        IconButton(
          tooltip: tooltip,
          icon: Icon(icon),
          onPressed: onTap,
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                  color: Colors.red, shape: BoxShape.circle),
              constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                count > 9 ? '9+' : '$count',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
      ],
    );
  }
}

class _EmergencyBanner extends ConsumerWidget {
  const _EmergencyBanner();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(activeEmergencyCountProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: active > 0 ? Colors.red.shade50 : null,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: active > 0
                ? Colors.red
                : Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
        child: ListTile(
          leading: Icon(Icons.sos, color: active > 0 ? Colors.red : null),
          title: Text(active > 0
              ? '$active active emergency alert${active == 1 ? '' : 's'}'
              : 'Emergency'),
          subtitle: const Text('Send or view village SOS alerts'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const EmergencyScreen()),
          ),
        ),
      ),
    );
  }
}

