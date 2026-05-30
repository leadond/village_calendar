/// A chat message tied to a help request, backed by `public.messages`.
/// The live table has both `content` (NOT NULL) and legacy `body`; we read
/// whichever is present and write both.
class Message {
  const Message({
    required this.id,
    required this.requestId,
    required this.senderId,
    required this.body,
    required this.createdAt,
    this.recipientId,
    this.readAt,
  });

  final String id;
  final String requestId;
  final String senderId;
  final String? recipientId;
  final String body;
  final DateTime createdAt;
  final DateTime? readAt;

  factory Message.fromMap(Map<String, dynamic> map) {
    return Message(
      id: map['id'] as String,
      requestId: map['request_id'] as String,
      senderId: map['sender_id'] as String,
      recipientId: map['recipient_id'] as String?,
      body: (map['content'] ?? map['body'] ?? '') as String,
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      readAt: map['read_at'] == null
          ? null
          : DateTime.tryParse(map['read_at'] as String)?.toLocal(),
    );
  }
}
