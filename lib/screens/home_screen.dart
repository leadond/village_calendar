import 'package:flutter/material.dart';

import '../src/models/village_event.dart';
import '../src/repositories/events_repository.dart';
import '../src/services/setup_services.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;
  bool _isLoading = true;
  String? _errorMessage;
  List<VillageEvent> _events = const [];

  EventsRepository? get _repository {
    final client = SetupServices.maybeSupabaseClient;
    if (client == null) {
      return null;
    }

    return EventsRepository(client);
  }

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  Future<void> _loadEvents() async {
    final repository = _repository;
    if (repository == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Supabase is not configured for this app run.';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final events = await repository.listEvents();

      if (!mounted) {
        return;
      }

      setState(() {
        _events = events;
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Could not load events. If this is your first run, create the Supabase events table from supabase/events.sql. Details: $error';
      });
    }
  }

  Future<void> _createEvent() async {
    final draft = await showDialog<EventDraft>(
      context: context,
      builder: (context) => const _EventEditorDialog(),
    );

    if (draft == null) {
      return;
    }

    final repository = _repository;
    if (repository == null) {
      _showMessage('Supabase is not configured.');
      return;
    }

    try {
      final event = await repository.createEvent(draft);

      if (!mounted) {
        return;
      }

      setState(() {
        _events = [..._events, event]..sort(_sortByStart);
      });
      _showMessage('Event added.');
    } catch (error) {
      _showMessage('Could not add event: $error');
    }
  }

  Future<void> _deleteEvent(VillageEvent event) async {
    final repository = _repository;
    if (repository == null) {
      _showMessage('Supabase is not configured.');
      return;
    }

    try {
      await repository.deleteEvent(event.id);

      if (!mounted) {
        return;
      }

      setState(() {
        _events = _events.where((item) => item.id != event.id).toList();
      });
      _showMessage('Event deleted.');
    } catch (error) {
      _showMessage('Could not delete event: $error');
    }
  }

  Future<void> _signOut() async {
    await SetupServices.maybeSupabaseClient?.auth.signOut();

    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(context, '/landing', (route) => false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final user = SetupServices.maybeSupabaseClient?.auth.currentUser;
    final todayEvents = _events.where(_isToday).toList();
    final upcomingEvents = _events.where((event) => !_isToday(event)).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Village Pro'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loadEvents,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : IndexedStack(
                index: _selectedIndex,
                children: [
                  _EventsTab(
                    title: 'Today',
                    icon: Icons.today,
                    events: todayEvents,
                    emptyTitle: 'No events today',
                    emptySubtitle: 'Add a village event when plans firm up.',
                    errorMessage: _errorMessage,
                    onRetry: _loadEvents,
                    onDelete: _deleteEvent,
                  ),
                  _EventsTab(
                    title: 'Upcoming',
                    icon: Icons.event_note,
                    events: upcomingEvents,
                    emptyTitle: 'No upcoming events',
                    emptySubtitle: 'Future gatherings will show up here.',
                    errorMessage: _errorMessage,
                    onRetry: _loadEvents,
                    onDelete: _deleteEvent,
                  ),
                  const _GroupsTab(),
                  _SettingsTab(
                    userEmail: user?.email ?? 'Signed-in account',
                    onSignOut: _signOut,
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'home-create-event-fab',
        onPressed: _createEvent,
        icon: const Icon(Icons.add),
        label: const Text('Event'),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
          NavigationDestination(
            icon: Icon(Icons.event_note),
            label: 'Upcoming',
          ),
          NavigationDestination(icon: Icon(Icons.groups), label: 'Groups'),
          NavigationDestination(icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}

class _EventsTab extends StatelessWidget {
  const _EventsTab({
    required this.title,
    required this.icon,
    required this.events,
    required this.emptyTitle,
    required this.emptySubtitle,
    required this.onRetry,
    required this.onDelete,
    this.errorMessage,
  });

  final String title;
  final IconData icon;
  final List<VillageEvent> events;
  final String emptyTitle;
  final String emptySubtitle;
  final String? errorMessage;
  final VoidCallback onRetry;
  final ValueChanged<VillageEvent> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        _SectionHeader(title: title, icon: icon),
        const SizedBox(height: 18),
        if (errorMessage != null)
          _ErrorPanel(message: errorMessage!, onRetry: onRetry)
        else if (events.isEmpty)
          _EmptyPanel(title: emptyTitle, subtitle: emptySubtitle)
        else
          for (final event in events)
            _EventCard(event: event, onDelete: () => onDelete(event)),
      ],
    );
  }
}

class _GroupsTab extends StatelessWidget {
  const _GroupsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: const [
        _SectionHeader(title: 'Groups', icon: Icons.groups),
        SizedBox(height: 18),
        _InfoCard(
          icon: Icons.home_work,
          title: 'Neighbors',
          subtitle: 'Shared household and community events.',
        ),
        _InfoCard(
          icon: Icons.volunteer_activism,
          title: 'Volunteers',
          subtitle: 'Coverage, reminders, and shift planning.',
        ),
        _InfoCard(
          icon: Icons.family_restroom,
          title: 'Families',
          subtitle: 'Family-friendly gatherings and recurring routines.',
        ),
      ],
    );
  }
}

class _SettingsTab extends StatelessWidget {
  const _SettingsTab({required this.userEmail, required this.onSignOut});

  final String userEmail;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const _SectionHeader(title: 'Settings', icon: Icons.settings),
        const SizedBox(height: 18),
        _InfoCard(icon: Icons.person, title: 'Account', subtitle: userEmail),
        const _InfoCard(
          icon: Icons.notifications,
          title: 'Notifications',
          subtitle:
              'Firebase Messaging is scaffolded and disabled until configured.',
        ),
        const _InfoCard(
          icon: Icons.workspace_premium,
          title: 'Subscriptions',
          subtitle: 'RevenueCat is scaffolded and ready for product setup.',
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onSignOut,
          icon: const Icon(Icons.logout),
          label: const Text('Sign Out'),
        ),
      ],
    );
  }
}

class _EventEditorDialog extends StatefulWidget {
  const _EventEditorDialog();

  @override
  State<_EventEditorDialog> createState() => _EventEditorDialogState();
}

class _EventEditorDialogState extends State<_EventEditorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();

  DateTime _date = DateTime.now();
  TimeOfDay _time = TimeOfDay.now();

  @override
  void dispose() {
    _titleController.dispose();
    _locationController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
    );

    if (picked != null) {
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);

    if (picked != null) {
      setState(() => _time = picked);
    }
  }

  void _submit() {
    final formState = _formKey.currentState;
    if (formState == null || !formState.validate()) {
      return;
    }

    final startsAt = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );

    Navigator.pop(
      context,
      EventDraft(
        title: _titleController.text.trim(),
        location: _emptyToNull(_locationController.text),
        description: _emptyToNull(_descriptionController.text),
        startsAt: startsAt,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add event'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Title',
                    prefixIcon: Icon(Icons.event),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Add an event title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _locationController,
                  decoration: const InputDecoration(
                    labelText: 'Location',
                    prefixIcon: Icon(Icons.place),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    prefixIcon: Icon(Icons.notes),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickDate,
                        icon: const Icon(Icons.calendar_today),
                        label: Text(_formatDate(_date)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _pickTime,
                        icon: const Icon(Icons.schedule),
                        label: Text(_time.format(context)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Save')),
      ],
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event, required this.onDelete});

  final VillageEvent event;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: theme.colorScheme.primaryContainer,
          child: Icon(Icons.calendar_month, color: theme.colorScheme.primary),
        ),
        title: Text(event.title),
        subtitle: Text(
          [
            _formatDateTime(event.startsAt),
            if (event.location != null && event.location!.isNotEmpty)
              event.location!,
            if (event.description != null && event.description!.isNotEmpty)
              event.description!,
          ].join('\n'),
        ),
        isThreeLine: event.description != null && event.description!.isNotEmpty,
        trailing: IconButton(
          tooltip: 'Delete event',
          onPressed: onDelete,
          icon: const Icon(Icons.delete_outline),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: theme.colorScheme.primary),
        title: Text(title),
        subtitle: Text(subtitle),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Text(
          title,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyPanel extends StatelessWidget {
  const _EmptyPanel({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 48),
        child: Column(
          children: [
            Icon(
              Icons.event_available,
              size: 48,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      color: theme.colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Events need setup',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onErrorContainer,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

int _sortByStart(VillageEvent a, VillageEvent b) =>
    a.startsAt.compareTo(b.startsAt);

bool _isToday(VillageEvent event) {
  final now = DateTime.now();
  final startsAt = event.startsAt;
  return startsAt.year == now.year &&
      startsAt.month == now.month &&
      startsAt.day == now.day;
}

String? _emptyToNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) {
    return null;
  }

  return trimmed;
}

String _formatDate(DateTime value) =>
    '${value.month}/${value.day}/${value.year}';

String _formatDateTime(DateTime value) {
  final hour = value.hour == 0
      ? 12
      : value.hour > 12
      ? value.hour - 12
      : value.hour;
  final minute = value.minute.toString().padLeft(2, '0');
  final period = value.hour >= 12 ? 'PM' : 'AM';

  return '${_formatDate(value)} at $hour:$minute $period';
}
