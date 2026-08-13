import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
import '../../models/kid_profile.dart';
import '../../services/google_maps_service.dart';
import '../../services/setup_services.dart';
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
  final _aiPrompt = TextEditingController();

  HelpCategory _category = HelpCategory.schoolPickup;
  DateTime _when = DateTime.now().add(const Duration(hours: 1));
  DateTime? _until;
  final Set<String> _kidIds = {};
  final List<ChildScheduleBlock> _childBlocks = [];
  bool _busy = false;
  bool _aiBusy = false;

  @override
  void dispose() {
    for (final c in [
      _title,
      _description,
      _pickup,
      _dropoff,
      _instructions,
      _aiPrompt,
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
      _until ??= _when.add(const Duration(hours: 1));
    });
  }

  Future<void> _pickUntil() async {
    final base = _until ?? _when.add(const Duration(hours: 1));
    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: _when,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
    );
    if (time == null) return;
    final end =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (end.isBefore(_when)) {
      _toast('End time must be after the start time.');
      return;
    }
    setState(() => _until = end);
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
      final blocks = List<ChildScheduleBlock>.from(_childBlocks);
      final blockStart = blocks.isEmpty
          ? _when
          : blocks
              .map((block) => block.start)
              .reduce((a, b) => a.isBefore(b) ? a : b);
      final blockEnd = blocks.isEmpty
          ? _until
          : blocks
              .map((block) => block.end)
              .reduce((a, b) => a.isAfter(b) ? a : b);
      final kidIds = blocks.isNotEmpty
          ? blocks.map((block) => block.kidId).toSet().toList()
          : _kidIds.toList();
      final draft = HelpRequestDraft(
        title: _title.text,
        category: _category,
        scheduledStart: blockStart,
        scheduledEnd: blockEnd,
        description: _description.text,
        pickupAddress: _pickup.text,
        dropoffAddress: _dropoff.text,
        specialInstructions: _instructions.text,
        kidIds: kidIds,
        childScheduleBlocks: blocks,
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

  Future<void> _draftWithAi() async {
    final roughPrompt = _aiPrompt.text.trim();
    if (roughPrompt.isEmpty) {
      _toast('Add a quick note for AI first.');
      return;
    }

    setState(() => _aiBusy = true);
    try {
      final draft = await ref.read(aiAssistantServiceProvider).draftHelpRequest(
            roughPrompt,
          );
      if (!mounted) return;
      setState(() {
        _title.text = draft.title;
        _category = draft.category;
        _description.text = draft.description ?? '';
        _pickup.text = draft.pickupAddress ?? '';
        _dropoff.text = draft.dropoffAddress ?? '';
        _instructions.text = draft.specialInstructions ?? '';
      });
      _toast('AI draft applied. Review and adjust before sending.');
    } catch (e) {
      _toast('AI draft failed: $e');
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    final kids = ref.watch(myKidsProvider).value ?? const [];
    final mapsService = ref.read(googleMapsServiceProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('New request')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Draft with AI',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Describe the request in plain English and AI will fill the form for you.',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _aiPrompt,
                      minLines: 2,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText:
                            'Example: Need someone to pick up Maya from Cedar Elementary tomorrow at 3:15 and bring her to soccer practice by 4:00.',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: (_busy || _aiBusy) ? null : _draftWithAi,
                      icon: _aiBusy
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: const Text('Draft Request with AI'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
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
              title: const Text('Request start'),
              subtitle: Text(DateFormat('EEE, MMM d · h:mm a').format(_when)),
              trailing: TextButton(
                onPressed: _busy ? null : _pickWhen,
                child: const Text('Change'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Request end'),
              subtitle: Text(
                _until == null
                    ? 'Optional'
                    : DateFormat('EEE, MMM d · h:mm a').format(_until!),
              ),
              trailing: TextButton(
                onPressed: _busy ? null : _pickUntil,
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
                                  _childBlocks.removeWhere(
                                    (block) => block.kidId == k.id,
                                  );
                                }
                              }),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              _ChildScheduleBlocksCard(
                kids: kids.where((kid) => _kidIds.contains(kid.id)).toList(),
                blocks: _childBlocks,
                enabled: !_busy,
                onAdd: _kidIds.isEmpty
                    ? null
                    : () async {
                        final block = await showDialog<ChildScheduleBlock>(
                          context: context,
                          builder: (_) => _ChildBlockDialog(
                            kids: kids
                                .where((kid) => _kidIds.contains(kid.id))
                                .toList(),
                            initialStart: _when,
                            initialEnd:
                                _until ?? _when.add(const Duration(hours: 1)),
                          ),
                        );
                        if (block != null) {
                          setState(() => _childBlocks.add(block));
                        }
                      },
                onEdit: (index) async {
                  final block = await showDialog<ChildScheduleBlock>(
                    context: context,
                    builder: (_) => _ChildBlockDialog(
                      kids: kids
                          .where((kid) => _kidIds.contains(kid.id))
                          .toList(),
                      existing: _childBlocks[index],
                      initialStart: _when,
                      initialEnd: _until ?? _when.add(const Duration(hours: 1)),
                    ),
                  );
                  if (block != null) {
                    setState(() => _childBlocks[index] = block);
                  }
                },
                onDelete: (index) {
                  setState(() => _childBlocks.removeAt(index));
                },
              ),
            ],
            const SizedBox(height: 12),
            _field(_description, 'Description', Icons.notes, lines: 2),
            const SizedBox(height: 12),
            _AddressAutocompleteField(
              controller: _pickup,
              label: 'Pickup address',
              icon: Icons.my_location,
              enabled: !_busy,
              service: mapsService,
            ),
            const SizedBox(height: 12),
            _AddressAutocompleteField(
              controller: _dropoff,
              label: 'Dropoff address',
              icon: Icons.location_on_outlined,
              enabled: !_busy,
              service: mapsService,
            ),
            if (!AppConfig.hasGoogleMapsKey) ...[
              const SizedBox(height: 8),
              Text(
                'Add GOOGLE_MAPS_API_KEY to .env to enable smart address search and route suggestions.',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
            const SizedBox(height: 12),
            _field(_instructions, 'Special instructions', Icons.info_outline,
                lines: 2),
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

class _ChildScheduleBlocksCard extends StatelessWidget {
  const _ChildScheduleBlocksCard({
    required this.kids,
    required this.blocks,
    required this.enabled,
    required this.onAdd,
    required this.onEdit,
    required this.onDelete,
  });

  final List<KidProfile> kids;
  final List<ChildScheduleBlock> blocks;
  final bool enabled;
  final VoidCallback? onAdd;
  final ValueChanged<int> onEdit;
  final ValueChanged<int> onDelete;

  @override
  Widget build(BuildContext context) {
    String kidName(String kidId) {
      for (final kid in kids) {
        if (kid.id == kidId) return kid.name;
      }
      return 'Child';
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Child schedule blocks',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                FilledButton.tonalIcon(
                  onPressed: enabled ? onAdd : null,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Use this when different children need help at different times in the same request.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            if (blocks.isEmpty)
              Text(
                'No child-specific blocks yet. The request-level schedule will be used for everyone.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            for (var i = 0; i < blocks.length; i++)
              Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  title: Text(kidName(blocks[i].kidId)),
                  subtitle: Text(
                    '${blocks[i].need}\n'
                    '${DateFormat('EEE, MMM d · h:mm a').format(blocks[i].start)}'
                    ' - ${DateFormat('h:mm a').format(blocks[i].end)}',
                  ),
                  isThreeLine: true,
                  trailing: Wrap(
                    spacing: 4,
                    children: [
                      IconButton(
                        onPressed: enabled ? () => onEdit(i) : null,
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: 'Edit block',
                      ),
                      IconButton(
                        onPressed: enabled ? () => onDelete(i) : null,
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Delete block',
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
}

class _ChildBlockDialog extends StatefulWidget {
  const _ChildBlockDialog({
    required this.kids,
    required this.initialStart,
    required this.initialEnd,
    this.existing,
  });

  final List<KidProfile> kids;
  final DateTime initialStart;
  final DateTime initialEnd;
  final ChildScheduleBlock? existing;

  @override
  State<_ChildBlockDialog> createState() => _ChildBlockDialogState();
}

class _ChildBlockDialogState extends State<_ChildBlockDialog> {
  late String _kidId = widget.existing?.kidId ??
      (widget.kids.isNotEmpty ? widget.kids.first.id : '');
  late DateTime _start = widget.existing?.start ?? widget.initialStart;
  late DateTime _end = widget.existing?.end ?? widget.initialEnd;
  late final TextEditingController _need =
      TextEditingController(text: widget.existing?.need ?? '');

  @override
  void dispose() {
    _need.dispose();
    super.dispose();
  }

  Future<void> _pickStart() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_start),
    );
    if (time == null) return;
    setState(() {
      _start =
          DateTime(date.year, date.month, date.day, time.hour, time.minute);
      if (_end.isBefore(_start)) {
        _end = _start.add(const Duration(hours: 1));
      }
    });
  }

  Future<void> _pickEnd() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _end,
      firstDate: _start,
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_end),
    );
    if (time == null) return;
    final nextEnd =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    if (nextEnd.isBefore(_start)) return;
    setState(() => _end = nextEnd);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.existing == null ? 'Add child block' : 'Edit child block'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<String>(
              initialValue: _kidId.isEmpty ? null : _kidId,
              decoration: const InputDecoration(
                labelText: 'Child',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final kid in widget.kids)
                  DropdownMenuItem<String>(
                    value: kid.id,
                    child: Text(kid.name),
                  ),
              ],
              onChanged: (value) {
                if (value == null) return;
                setState(() => _kidId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _need,
              decoration: const InputDecoration(
                labelText: 'Need',
                hintText: 'Pickup from school and bring to practice',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_arrow_outlined),
              title: const Text('Start'),
              subtitle: Text(DateFormat('EEE, MMM d · h:mm a').format(_start)),
              trailing: TextButton(
                onPressed: _pickStart,
                child: const Text('Change'),
              ),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop_outlined),
              title: const Text('End'),
              subtitle: Text(DateFormat('EEE, MMM d · h:mm a').format(_end)),
              trailing: TextButton(
                onPressed: _pickEnd,
                child: const Text('Change'),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            if (_kidId.isEmpty || _need.text.trim().isEmpty) return;
            Navigator.of(context).pop(
              ChildScheduleBlock(
                kidId: _kidId,
                need: _need.text.trim(),
                start: _start,
                end: _end,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _AddressAutocompleteField extends StatefulWidget {
  const _AddressAutocompleteField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.service,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final GoogleMapsService service;

  @override
  State<_AddressAutocompleteField> createState() =>
      _AddressAutocompleteFieldState();
}

class _AddressAutocompleteFieldState extends State<_AddressAutocompleteField> {
  late final FocusNode _focusNode;
  String _sessionToken = _newSessionToken();

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        _sessionToken = _newSessionToken();
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RawAutocomplete<PlaceSuggestion>(
      textEditingController: widget.controller,
      focusNode: _focusNode,
      optionsBuilder: (value) async {
        if (!widget.enabled || !widget.service.isConfigured) {
          return const <PlaceSuggestion>[];
        }
        try {
          return await widget.service.autocompleteAddress(
            value.text,
            sessionToken: _sessionToken,
          );
        } catch (_) {
          return const <PlaceSuggestion>[];
        }
      },
      displayStringForOption: (option) => option.fullText,
      onSelected: (selection) {
        widget.controller.text = selection.fullText;
        _sessionToken = _newSessionToken();
      },
      fieldViewBuilder: (context, controller, focusNode, onSubmitted) {
        return TextField(
          controller: controller,
          focusNode: focusNode,
          enabled: widget.enabled,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: widget.label,
            prefixIcon: Icon(widget.icon),
            suffixIcon: widget.service.isConfigured
                ? const Icon(Icons.auto_awesome, size: 18)
                : null,
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => onSubmitted(),
        );
      },
      optionsViewBuilder: (context, onSelected, options) {
        final list = options.toList();
        if (list.isEmpty) {
          return const SizedBox.shrink();
        }
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 6,
            borderRadius: BorderRadius.circular(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720, maxHeight: 240),
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                shrinkWrap: true,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final option = list[index];
                  return ListTile(
                    dense: true,
                    leading: const Icon(Icons.place_outlined),
                    title: Text(option.primaryText),
                    subtitle: option.secondaryText == null
                        ? null
                        : Text(option.secondaryText!),
                    onTap: () => onSelected(option),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  static String _newSessionToken() =>
      DateTime.now().microsecondsSinceEpoch.toString();
}
