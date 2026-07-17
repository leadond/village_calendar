/// A recurring-weekly or date-specific availability/work block, backed by
/// `public.availability_blocks`.
class AvailabilityBlock {
  const AvailabilityBlock({
    required this.id,
    required this.userId,
    required this.villageId,
    required this.kind, // work | available | unavailable
    required this.startMinutes,
    required this.endMinutes,
    this.weekday, // 0=Sun..6=Sat (recurring)
    this.specificDate, // one-off (overrides weekday)
    this.note,
  });

  final String id;
  final String userId;
  final String villageId;
  final String kind;
  final int startMinutes;
  final int endMinutes;
  final int? weekday;
  final DateTime? specificDate;
  final String? note;

  bool get isRecurring => specificDate == null;

  /// True if this block applies on [date].
  bool appliesOn(DateTime date) {
    if (specificDate != null) {
      return specificDate!.year == date.year &&
          specificDate!.month == date.month &&
          specificDate!.day == date.day;
    }
    // Dart weekday: Mon=1..Sun=7; DB weekday: Sun=0..Sat=6.
    final dbWeekday = date.weekday % 7;
    return weekday == dbWeekday;
  }

  static int _parseTime(String? t) {
    if (t == null || t.isEmpty) return 0;
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
  }

  static String fmtMinutes(int mins) {
    final h24 = mins ~/ 60;
    final m = mins % 60;
    final ampm = h24 >= 12 ? 'PM' : 'AM';
    var h = h24 % 12;
    if (h == 0) h = 12;
    return '$h:${m.toString().padLeft(2, '0')} $ampm';
  }

  String get label => '${fmtMinutes(startMinutes)} – ${fmtMinutes(endMinutes)}';

  factory AvailabilityBlock.fromMap(Map<String, dynamic> map) {
    final sd = map['specific_date'] as String?;
    return AvailabilityBlock(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      villageId: map['village_id'] as String,
      kind: (map['kind'] as String?) ?? 'available',
      startMinutes: _parseTime(map['start_time'] as String?),
      endMinutes: _parseTime(map['end_time'] as String?),
      weekday: map['weekday'] as int?,
      specificDate: sd == null ? null : DateTime.tryParse(sd),
      note: map['note'] as String?,
    );
  }
}

const List<String> kWeekdayNames = [
  'Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat',
];
