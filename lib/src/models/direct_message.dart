/// A 1:1 message between two villagers, backed by `public.direct_messages`.
class DirectMessage {
  const DirectMessage({
    required this.id,
    required this.villageId,
    required this.senderId,
    required this.recipientId,
    required this.body,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String villageId;
  final String senderId;
  final String recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  /// The other participant relative to [me].
  String otherParty(String me) => senderId == me ? recipientId : senderId;

  factory DirectMessage.fromMap(Map<String, dynamic> map) {
    return DirectMessage(
      id: map['id'] as String,
      villageId: map['village_id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String,
      body: (map['body'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      readAt: map['read_at'] == null
          ? null
          : DateTime.tryParse(map['read_at'] as String)?.toLocal(),
    );
  }
}

/// A broadcast announcement, backed by `public.village_announcements`.
class Announcement {
  const Announcement({
    required this.id,
    required this.villageId,
    required this.createdBy,
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String id;
  final String villageId;
  final String createdBy;
  final String title;
  final String message;
  final DateTime createdAt;

  factory Announcement.fromMap(Map<String, dynamic> map) {
    return Announcement(
      id: map['id'] as String,
      villageId: map['village_id'] as String,
      createdBy: map['created_by'] as String,
      title: (map['title'] as String?) ?? '',
      message: (map['message'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
    );
  }
}
