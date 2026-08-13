/// An in-app notification, backed by `public.notifications`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.createdAt,
    this.readAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isUnread => readAt == null;
  String? get requestId => data['request_id'] as String?;
  String? get alertId => data['alert_id'] as String?;

  factory AppNotification.fromMap(Map<String, dynamic> map) {
    final legacyIsRead = map['is_read'] as bool?;
    final readAtRaw = map['read_at'] as String?;
    return AppNotification(
      id: map['id'] as String,
      type: (map['type'] as String?) ?? 'info',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? (map['message'] as String?) ?? '',
      data: map['data'] is Map
          ? Map<String, dynamic>.from(map['data'] as Map)
          : map['request_id'] != null
              ? <String, dynamic>{'request_id': map['request_id']}
              : const {},
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      readAt: readAtRaw != null
          ? DateTime.tryParse(readAtRaw)?.toLocal()
          : (legacyIsRead == true ? DateTime.now() : null),
    );
  }
}
