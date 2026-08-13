/// Help request categories (mirrors the V2 `category` text values).
enum HelpCategory {
  schoolPickup('school_pickup', 'School pickup'),
  schoolDropoff('school_dropoff', 'School dropoff'),
  sportsPractice('sports_practice', 'Sports / practice'),
  doctorAppointment('doctor_appointment', 'Doctor appointment'),
  playdate('playdate', 'Playdate'),
  babysitting('babysitting', 'Babysitting'),
  overnight('overnight', 'Overnight'),
  emergency('emergency', 'Emergency'),
  event('event', 'Event'),
  party('party', 'Party'),
  other('other', 'Other');

  const HelpCategory(this.value, this.label);
  final String value;
  final String label;

  static HelpCategory fromValue(String? v) => HelpCategory.values
      .firstWhere((c) => c.value == v, orElse: () => HelpCategory.other);

  /// Legacy `request_type` enum is limited to babysitting|school-pickup|other.
  String get legacyRequestType {
    switch (this) {
      case HelpCategory.schoolPickup:
      case HelpCategory.schoolDropoff:
        return 'school-pickup';
      case HelpCategory.babysitting:
      case HelpCategory.overnight:
        return 'babysitting';
      default:
        return 'other';
    }
  }
}

/// Help request lifecycle status (mirrors the `help_request_status` enum).
enum HelpStatus {
  open('open', 'Open'),
  claimed('claimed', 'Claimed'),
  confirmed('confirmed', 'Confirmed'),
  inProgress('in_progress', 'On the way'),
  arrived('arrived', 'Arrived'),
  completed('completed', 'Completed'),
  cancelled('cancelled', 'Cancelled'),
  incident('incident', 'Incident');

  const HelpStatus(this.value, this.label);
  final String value;
  final String label;

  static HelpStatus fromValue(String? v) => HelpStatus.values
      .firstWhere((s) => s.value == v, orElse: () => HelpStatus.open);

  bool get isActive =>
      this == claimed ||
      this == confirmed ||
      this == inProgress ||
      this == arrived;
  bool get isTerminal => this == completed || this == cancelled;
}

class HelpRequest {
  const HelpRequest({
    required this.id,
    required this.creatorId,
    required this.title,
    required this.category,
    required this.status,
    required this.scheduledStart,
    this.villageId,
    this.helperId,
    this.description,
    this.scheduledEnd,
    this.pickupAddress,
    this.dropoffAddress,
    this.specialInstructions,
    this.kidIds = const [],
    this.childScheduleBlocks = const [],
    this.parentConfirmedAt,
    this.helperCheckinAt,
    this.arrivedAtDestinationAt,
    this.parentReceiptConfirmedAt,
    this.createdAt,
  });

  final String id;
  final String creatorId;
  final String title;
  final HelpCategory category;
  final HelpStatus status;
  final DateTime scheduledStart;
  final String? villageId;
  final String? helperId;
  final String? description;
  final DateTime? scheduledEnd;
  final String? pickupAddress;
  final String? dropoffAddress;
  final String? specialInstructions;
  final List<String> kidIds;
  final List<ChildScheduleBlock> childScheduleBlocks;
  final DateTime? parentConfirmedAt;
  final DateTime? helperCheckinAt;
  final DateTime? arrivedAtDestinationAt;
  final DateTime? parentReceiptConfirmedAt;
  final DateTime? createdAt;

  bool get isPast =>
      status.isTerminal || scheduledStart.isBefore(DateTime.now());

  static DateTime? _dt(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String)?.toLocal();

  factory HelpRequest.fromMap(Map<String, dynamic> map) {
    return HelpRequest(
      id: map['id'] as String,
      creatorId: map['creator_id'] as String,
      title: (map['title'] as String?) ?? '',
      category: HelpCategory.fromValue(map['category'] as String?),
      status: HelpStatus.fromValue(map['status'] as String?),
      scheduledStart: _dt(map['scheduled_start']) ??
          _dt(map['scheduled_at']) ??
          DateTime.now(),
      villageId: map['village_id'] as String?,
      helperId: map['helper_id'] as String?,
      description: map['description'] as String?,
      scheduledEnd: _dt(map['scheduled_end']),
      pickupAddress: map['pickup_address'] as String?,
      dropoffAddress: map['dropoff_address'] as String?,
      specialInstructions: map['special_instructions'] as String?,
      kidIds:
          (map['kid_ids'] as List?)?.whereType<String>().toList() ?? const [],
      childScheduleBlocks: ChildScheduleBlock.listFromDynamic(
        map['child_schedule_blocks'],
      ),
      parentConfirmedAt: _dt(map['parent_confirmed_at']),
      helperCheckinAt: _dt(map['helper_checkin_at']),
      arrivedAtDestinationAt: _dt(map['arrived_at_destination_at']),
      parentReceiptConfirmedAt: _dt(map['parent_receipt_confirmed_at']),
      createdAt: _dt(map['created_at']),
    );
  }
}

class HelpRequestDraft {
  HelpRequestDraft({
    required this.title,
    required this.category,
    required this.scheduledStart,
    this.scheduledEnd,
    this.description,
    this.pickupAddress,
    this.dropoffAddress,
    this.specialInstructions,
    this.kidIds = const [],
    this.childScheduleBlocks = const [],
  });

  String title;
  HelpCategory category;
  DateTime scheduledStart;
  DateTime? scheduledEnd;
  String? description;
  String? pickupAddress;
  String? dropoffAddress;
  String? specialInstructions;
  List<String> kidIds;
  List<ChildScheduleBlock> childScheduleBlocks;

  Map<String, dynamic> toColumns() {
    final iso = scheduledStart.toUtc().toIso8601String();
    final endIso = scheduledEnd?.toUtc().toIso8601String();
    return {
      'title': title.trim(),
      'category': category.value,
      'request_type': category.legacyRequestType, // legacy NOT NULL enum
      'scheduled_at': iso, // legacy NOT NULL
      'scheduled_start': iso,
      'scheduled_end': endIso,
      'description': _nz(description),
      'pickup_address': _nz(pickupAddress),
      'dropoff_address': _nz(dropoffAddress),
      'special_instructions': _nz(specialInstructions),
      'kid_ids': kidIds,
      'child_schedule_blocks':
          childScheduleBlocks.map((block) => block.toColumns()).toList(),
    };
  }

  static String? _nz(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}

class ChildScheduleBlock {
  const ChildScheduleBlock({
    required this.kidId,
    required this.need,
    required this.start,
    required this.end,
  });

  final String kidId;
  final String need;
  final DateTime start;
  final DateTime end;

  factory ChildScheduleBlock.fromMap(Map<String, dynamic> map) {
    return ChildScheduleBlock(
      kidId: (map['kid_id'] as String?) ?? '',
      need: (map['need'] as String?) ?? '',
      start: DateTime.parse(map['start'] as String).toLocal(),
      end: DateTime.parse(map['end'] as String).toLocal(),
    );
  }

  static List<ChildScheduleBlock> listFromDynamic(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((item) => ChildScheduleBlock.fromMap(
              Map<String, dynamic>.from(item),
            ))
        .where((block) => block.kidId.isNotEmpty)
        .toList();
  }

  Map<String, dynamic> toColumns() {
    return {
      'kid_id': kidId,
      'need': need.trim(),
      'start': start.toUtc().toIso8601String(),
      'end': end.toUtc().toIso8601String(),
    };
  }
}

class RequestComment {
  const RequestComment({
    required this.id,
    required this.requestId,
    required this.authorId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String requestId;
  final String authorId;
  final String body;
  final DateTime createdAt;

  factory RequestComment.fromMap(Map<String, dynamic> map) {
    return RequestComment(
      id: map['id'] as String,
      requestId: map['request_id'] as String,
      authorId: map['author_id'] as String,
      body: (map['body'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}
