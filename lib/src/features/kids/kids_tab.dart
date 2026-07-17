import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../models/kid_profile.dart';
import '../../state/providers.dart';

class KidsTab extends ConsumerWidget {
  const KidsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kidsAsync = ref.watch(myKidsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kids'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.invalidate(myKidsProvider),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const KidEditScreen()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Add kid'),
      ),
      body: kidsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Could not load kids.\n$e')),
        data: (kids) {
          if (kids.isEmpty) {
            return const _EmptyKids();
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(myKidsProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: kids.length,
              itemBuilder: (context, i) {
                final k = kids[i];
                final subtitleParts = <String>[
                  if (k.ageYears != null) '${k.ageYears} yrs',
                  if (k.grade != null && k.grade!.isNotEmpty) 'Grade ${k.grade}',
                  if (k.school != null && k.school!.isNotEmpty) k.school!,
                ];
                return Card(
                  child: ListTile(
                    leading: _KidAvatar(kid: k),
                    title: Text(k.nickname?.isNotEmpty == true
                        ? '${k.name} (${k.nickname})'
                        : k.name),
                    subtitle: subtitleParts.isEmpty
                        ? null
                        : Text(subtitleParts.join(' · ')),
                    trailing: k.allergies.isNotEmpty
                        ? Tooltip(
                            message: 'Allergies: ${k.allergies.join(', ')}',
                            child: const Icon(Icons.warning_amber,
                                color: Colors.orange),
                          )
                        : const Icon(Icons.chevron_right),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => KidEditScreen(kid: k)),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _KidAvatar extends StatelessWidget {
  const _KidAvatar({required this.kid});
  final KidProfile kid;

  @override
  Widget build(BuildContext context) {
    if (kid.photoUrl != null && kid.photoUrl!.isNotEmpty) {
      return CircleAvatar(backgroundImage: NetworkImage(kid.photoUrl!));
    }
    return CircleAvatar(
      child: Text(kid.name.isNotEmpty ? kid.name[0].toUpperCase() : '?'),
    );
  }
}

class _EmptyKids extends StatelessWidget {
  const _EmptyKids();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Icon(Icons.child_care, size: 48),
          SizedBox(height: 12),
          Text('No kids yet. Tap "Add kid" to create one.'),
        ],
      ),
    );
  }
}

class KidEditScreen extends ConsumerStatefulWidget {
  const KidEditScreen({super.key, this.kid});

  final KidProfile? kid;

  @override
  ConsumerState<KidEditScreen> createState() => _KidEditScreenState();
}

class _KidEditScreenState extends ConsumerState<KidEditScreen> {
  final _name = TextEditingController();
  final _nickname = TextEditingController();
  final _grade = TextEditingController();
  final _school = TextEditingController();
  final _allergies = TextEditingController();
  final _medical = TextEditingController();
  final _notes = TextEditingController();

  DateTime? _dob;
  String? _existingPhotoUrl;
  Uint8List? _newPhotoBytes;
  String _newPhotoExt = 'jpg';
  bool _busy = false;

  TimeOfDay? _careStart;
  TimeOfDay? _careEnd;
  Set<int> _careWeekdays = {1, 2, 3, 4, 5}; // 1=Mon..7=Sun

  bool get _isEdit => widget.kid != null;

  static TimeOfDay? _todFromMinutes(int? m) =>
      m == null ? null : TimeOfDay(hour: m ~/ 60, minute: m % 60);

  @override
  void initState() {
    super.initState();
    final k = widget.kid;
    if (k != null) {
      _name.text = k.name;
      _nickname.text = k.nickname ?? '';
      _grade.text = k.grade ?? '';
      _school.text = k.school ?? '';
      _allergies.text = k.allergies.join(', ');
      _medical.text = k.medicalNotes ?? '';
      _notes.text = k.notes ?? '';
      _dob = k.dateOfBirth;
      _existingPhotoUrl = k.photoUrl;
      _careStart = _todFromMinutes(k.careStartMinutes);
      _careEnd = _todFromMinutes(k.careEndMinutes);
      if (k.careWeekdays.isNotEmpty) _careWeekdays = k.careWeekdays.toSet();
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _nickname,
      _grade,
      _school,
      _allergies,
      _medical,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickPhoto() async {
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      final name = picked.name.toLowerCase();
      final ext = name.contains('.') ? name.split('.').last : 'jpg';
      setState(() {
        _newPhotoBytes = bytes;
        _newPhotoExt = (ext == 'png' || ext == 'webp') ? ext : 'jpg';
      });
    } catch (e) {
      _toast('Could not pick image: $e');
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _toast('Please enter a name.');
      return;
    }
    setState(() => _busy = true);
    try {
      final repo = ref.read(kidRepositoryProvider);
      final userId = ref.read(currentUserProvider)?.id;

      var photoUrl = _existingPhotoUrl;
      if (_newPhotoBytes != null && userId != null) {
        photoUrl = await repo.uploadPhoto(
          userId: userId,
          bytes: _newPhotoBytes!,
          extension: _newPhotoExt,
        );
      }

      final draft = KidDraft(
        name: _name.text,
        nickname: _nickname.text,
        photoUrl: photoUrl,
        dateOfBirth: _dob,
        grade: _grade.text,
        school: _school.text,
        allergies: _allergies.text
            .split(',')
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty)
            .toList(),
        medicalNotes: _medical.text,
        notes: _notes.text,
        careStartMinutes:
            _careStart == null ? null : _careStart!.hour * 60 + _careStart!.minute,
        careEndMinutes:
            _careEnd == null ? null : _careEnd!.hour * 60 + _careEnd!.minute,
        careWeekdays: _careWeekdays.toList()..sort(),
      );

      if (_isEdit) {
        await repo.update(widget.kid!.id, draft);
      } else {
        final villageId = ref.read(currentProfileProvider).value?.villageId;
        await repo.create(draft, villageId: villageId);
      }
      ref.invalidate(myKidsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Could not save: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete kid?'),
        content: Text('Remove ${widget.kid!.name}? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    setState(() => _busy = true);
    try {
      await ref.read(kidRepositoryProvider).delete(widget.kid!.id);
      ref.invalidate(myKidsProvider);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      _toast('Could not delete: $e');
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String m) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit kid' : 'Add kid'),
        actions: [
          if (_isEdit)
            IconButton(
              tooltip: 'Delete',
              icon: const Icon(Icons.delete_outline),
              onPressed: _busy ? null : _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(child: _photoPicker()),
            const SizedBox(height: 16),
            _field(_name, 'Name *', Icons.person_outline,
                cap: TextCapitalization.words),
            _field(_nickname, 'Nickname', Icons.tag,
                cap: TextCapitalization.words),
            _dobField(),
            _field(_grade, 'Grade', Icons.school_outlined),
            _field(_school, 'School', Icons.location_city_outlined,
                cap: TextCapitalization.words),
            _field(_allergies, 'Allergies (comma separated)',
                Icons.warning_amber_outlined),
            _field(_medical, 'Medical notes', Icons.medical_information_outlined,
                lines: 2),
            _field(_notes, 'Other notes', Icons.notes, lines: 2),
            const SizedBox(height: 8),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text('School / daycare hours',
                  style: Theme.of(context).textTheme.titleSmall),
            ),
            const Text(
              'Used to auto-create sitter requests for the gaps around your '
              'work schedule.',
              style: TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.login, size: 18),
                    label: Text(_careStart == null
                        ? 'Drop-off / opens'
                        : 'Opens ${_careStart!.format(context)}'),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime: _careStart ??
                            const TimeOfDay(hour: 8, minute: 0),
                        helpText: 'School/daycare opens',
                      );
                      if (t != null) setState(() => _careStart = t);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.logout, size: 18),
                    label: Text(_careEnd == null
                        ? 'Pickup / ends'
                        : 'Ends ${_careEnd!.format(context)}'),
                    onPressed: () async {
                      final t = await showTimePicker(
                        context: context,
                        initialTime:
                            _careEnd ?? const TimeOfDay(hour: 15, minute: 0),
                        helpText: 'School/daycare ends',
                      );
                      if (t != null) setState(() => _careEnd = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (var wd = 1; wd <= 7; wd++)
                  FilterChip(
                    label: Text(const ['', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri',
                        'Sat', 'Sun'][wd]),
                    selected: _careWeekdays.contains(wd),
                    onSelected: (sel) => setState(() {
                      if (sel) {
                        _careWeekdays.add(wd);
                      } else {
                        _careWeekdays.remove(wd);
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy ? null : _save,
              child: _busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(_isEdit ? 'Save changes' : 'Add kid'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _photoPicker() {
    ImageProvider? img;
    if (_newPhotoBytes != null) {
      img = MemoryImage(_newPhotoBytes!);
    } else if (_existingPhotoUrl != null && _existingPhotoUrl!.isNotEmpty) {
      img = NetworkImage(_existingPhotoUrl!);
    }
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundImage: img,
          child: img == null ? const Icon(Icons.add_a_photo, size: 28) : null,
        ),
        TextButton.icon(
          onPressed: _busy ? null : _pickPhoto,
          icon: const Icon(Icons.image_outlined),
          label: Text(img == null ? 'Add photo' : 'Change photo'),
        ),
      ],
    );
  }

  Widget _dobField() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: _busy
            ? null
            : () async {
                final now = DateTime.now();
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _dob ?? DateTime(now.year - 6),
                  firstDate: DateTime(now.year - 25),
                  lastDate: now,
                );
                if (picked != null) setState(() => _dob = picked);
              },
        child: InputDecorator(
          decoration: const InputDecoration(
            labelText: 'Date of birth',
            prefixIcon: Icon(Icons.cake_outlined),
            border: OutlineInputBorder(),
          ),
          child: Text(
            _dob == null ? 'Not set' : DateFormat.yMMMd().format(_dob!),
          ),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        textCapitalization: cap,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }
}
