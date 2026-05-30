class VillageEvent {
  const VillageEvent({
    required this.id,
    required this.title,
    required this.startsAt,
    required this.createdBy,
    this.description,
    this.location,
    this.endsAt,
  });

  final String id;
  final String title;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
  final String createdBy;

  factory VillageEvent.fromJson(Map<String, dynamic> json) {
    return VillageEvent(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      location: json['location'] as String?,
      startsAt: DateTime.parse(json['starts_at'] as String).toLocal(),
      endsAt: json['ends_at'] == null
          ? null
          : DateTime.parse(json['ends_at'] as String).toLocal(),
      createdBy: json['created_by'] as String,
    );
  }
}

class EventDraft {
  const EventDraft({
    required this.title,
    required this.startsAt,
    this.description,
    this.location,
    this.endsAt,
  });

  final String title;
  final String? description;
  final String? location;
  final DateTime startsAt;
  final DateTime? endsAt;
}
