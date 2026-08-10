import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/help_request.dart';
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
  final Set<String> _kidIds = {};
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

  Future<void> _draftWithAi() async {
    final roughPrompt = _aiPrompt.text.trim();
    if (roughPrompt.isEmpty) {
      _toast('Add a quick note for AI first.');
      return;
    }

    setState(() => _aiBusy = true);
    try {
      final draft =
          await ref.read(aiAssistantServiceProvider).draftHelpRequest(
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
