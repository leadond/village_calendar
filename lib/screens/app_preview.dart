import 'package:flutter/material.dart';

class AppPreviewScreen extends StatefulWidget {
  const AppPreviewScreen({super.key});

  @override
  State<AppPreviewScreen> createState() => _AppPreviewScreenState();
}

class _AppPreviewScreenState extends State<AppPreviewScreen> {
  int _selectedIndex = 0;

  static const _tabs = [
    _PreviewTab(
      label: 'Home',
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
    ),
    _PreviewTab(
      label: 'Requests',
      icon: Icons.handshake_outlined,
      selectedIcon: Icons.handshake,
    ),
    _PreviewTab(
      label: 'Kids',
      icon: Icons.child_care_outlined,
      selectedIcon: Icons.child_care,
    ),
    _PreviewTab(
      label: 'Village',
      icon: Icons.groups_outlined,
      selectedIcon: Icons.groups,
    ),
    _PreviewTab(
      label: 'Profile',
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pages = [
      const _PreviewHomeTab(),
      const _PreviewRequestsTab(),
      const _PreviewKidsTab(),
      const _PreviewVillageTab(),
      const _PreviewProfileTab(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Village Pro Preview'),
      ),
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: [
          for (final tab in _tabs)
            NavigationDestination(
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon),
              label: tab.label,
            ),
        ],
      ),
    );
  }
}

class _PreviewTab {
  const _PreviewTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
  });

  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

class _PreviewHomeTab extends StatelessWidget {
  const _PreviewHomeTab();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primaryContainer,
                theme.colorScheme.surface,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Welcome back, Tia',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'This preview shows the primary app surfaces even before the live backend is fully connected.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: const [
                  _MetricChip(label: 'Open requests', value: '4'),
                  _MetricChip(label: 'Unread messages', value: '12'),
                  _MetricChip(label: 'Active drivers', value: '3'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const _PreviewSectionTitle('Today'),
        const _PreviewCard(
          title: 'School pickup rotation',
          subtitle: '2:45 PM - Maya pickup is assigned to Jordan.',
          icon: Icons.school_outlined,
        ),
        const _PreviewCard(
          title: 'Emergency contact drill',
          subtitle: 'One village-wide alert scheduled for 6:00 PM.',
          icon: Icons.sos_outlined,
        ),
      ],
    );
  }
}

class _PreviewRequestsTab extends StatelessWidget {
  const _PreviewRequestsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _PreviewSectionTitle('Request Board'),
        _PreviewCard(
          title: 'After-school pickup',
          subtitle: 'Need pickup at 3:15 PM from Cedar Elementary.',
          icon: Icons.directions_car_outlined,
        ),
        _PreviewCard(
          title: 'Practice dropoff',
          subtitle: 'Soccer dropoff Thursday at 5:30 PM.',
          icon: Icons.sports_soccer_outlined,
        ),
        _PreviewCard(
          title: 'Babysitting coverage',
          subtitle: 'Saturday 7:00 PM to 10:00 PM.',
          icon: Icons.nightlife_outlined,
        ),
      ],
    );
  }
}

class _PreviewKidsTab extends StatelessWidget {
  const _PreviewKidsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _PreviewSectionTitle('Kid Profiles'),
        _PreviewCard(
          title: 'Maya Johnson',
          subtitle: 'Cedar Elementary • Allergies noted • Pickup tag 2419',
          icon: Icons.face_3_outlined,
        ),
        _PreviewCard(
          title: 'Noah Johnson',
          subtitle: 'Little Oaks Preschool • Emergency meds on file',
          icon: Icons.face_4_outlined,
        ),
      ],
    );
  }
}

class _PreviewVillageTab extends StatelessWidget {
  const _PreviewVillageTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _PreviewSectionTitle('Village'),
        _PreviewCard(
          title: 'Northside Parents Circle',
          subtitle: '18 members • 6 active families • Invite code NSPRING',
          icon: Icons.holiday_village_outlined,
        ),
        _PreviewCard(
          title: 'Pending approvals',
          subtitle: '2 join requests are waiting for admin review.',
          icon: Icons.approval_outlined,
        ),
      ],
    );
  }
}

class _PreviewProfileTab extends StatelessWidget {
  const _PreviewProfileTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: const [
        _PreviewSectionTitle('Profile'),
        _PreviewCard(
          title: 'Account tier',
          subtitle: 'Premium preview with subscriptions, messaging, and routing surfaces.',
          icon: Icons.workspace_premium_outlined,
        ),
        _PreviewCard(
          title: 'Notification controls',
          subtitle: 'Push alerts, reminder windows, and emergency broadcast preferences.',
          icon: Icons.notifications_active_outlined,
        ),
      ],
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label),
        ],
      ),
    );
  }
}

class _PreviewSectionTitle extends StatelessWidget {
  const _PreviewSectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Icon(icon),
        title: Text(title),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(subtitle),
        ),
      ),
    );
  }
}
