import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
import '../../state/providers.dart';

class CreateRequestScreen extends ConsumerStatefulWidget {
  const CreateRequestScreen({super.key});

  @override
  ConsumerState<CreateRequestScreen> createState() =>
      _CreateRequestScreenState();
}

class _CreateRequestScreenState extends ConsumerState<CreateRequestScreen> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _pickup = TextEditingController();
  final _dropoff = TextEditingController();
  final _instructions = TextEditingController();

  HelpCategory _category = HelpCategory.schoolPickup;
  DateTime _when = DateTime.now().add(const Duration(hours: 1));
  final Set<String> _kidIds = {};
  bool _busy = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _pickup,
      _dropoff,
      _instructions,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickWhen() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_when),
    );
    if (time == null) return;
    setState(() {
      _when = DateTime(date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty) {
      _toast('Please enter a title.');
      return;
    }
    final profile = ref.read(currentProfileProvider).value;
    if (profile == null || !profile.hasVillage) {
      _toast('You must be in a village.');
      return;
    }
    setState(() => _busy = true);
    try {
      final draft = HelpRequestDraft(
        title: _title.text,
        category: _category,
        scheduledStart: _when,
        description: _description.text,
        pickupAddress: _pickup.text,
        dropoffAddress: _dropoff.text,
        specialInstructions: _instructions.text,
        kidIds: _kidIds.toList(),
      );
      await ref.read(helpRequestRepositoryProvider).create(
            draft,
            villageId: profile.villageId!,
            creatorId: profile.id,
          );
      ref.invalidate(myRequestsProvider);
      ref.invalidate(availableRequestsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Could not create request: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final kids = ref.watch(myKidsProvider).value ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _field(_title, 'Title *', Icons.title,
                cap: TextCapitalization.sentences),
            const SizedBox(height: 12),
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final c in HelpCategory.values)
                  ChoiceChip(
                    label: Text(c.label),
                    selected: _category == c,
                    onSelected:
                        _busy ? null : (_) => setState(() => _category = c),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event),
              title: const Text('When'),
              subtitle: Text(DateFormat('EEE, MMM d · h:mm a').format(_when)),
              trailing: TextButton(
                onPressed: _busy ? null : _pickWhen,
                child: const Text('Change'),
              ),
            ),
            if (kids.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('Kids', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final k in kids)
                    FilterChip(
                      label: Text(k.name),
                      selected: _kidIds.contains(k.id),
                      onSelected: _busy
                          ? null
                          : (sel) => setState(() {
                                if (sel) {
                                  _kidIds.add(k.id);
                                } else {
                                  _kidIds.remove(k.id);
                                }
                              }),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            _field(_description, 'Description', Icons.notes, lines: 2),
            const SizedBox(height: 12),
            _field(_pickup, 'Pickup address', Icons.my_location),
            const SizedBox(height: 12),
            _field(_dropoff, 'Dropoff address', Icons.location_on_outlined),
            const SizedBox(height: 12),
            _field(_instructions, 'Special instructions',
                Icons.info_outline, lines: 2),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _submit,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Create request'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    int lines = 1,
    TextCapitalization cap = TextCapitalization.none,
  }) {
    return TextField(
      controller: c,
      maxLines: lines,
      textCapitalization: cap,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        border: const OutlineInputBorder(),
      ),
    );
  }
}
