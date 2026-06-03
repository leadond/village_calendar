/// Mirrors the `public.emergency_alert_type` enum.
enum EmergencyType {
  helpNeeded('help_needed', 'Help needed', '🆘'),
  medical('medical', 'Medical', '➕'),
  medicalEmergency('medical_emergency', 'Medical emergency', '🚑'),
  safety('safety', 'Safety', '⚠️'),
  safetyConcern('safety_concern', 'Safety concern', '⚠️');

  const EmergencyType(this.value, this.label, this.emoji);
  final String value;
  final String label;
  final String emoji;

  static EmergencyType fromValue(String? v) =>
      EmergencyType.values.firstWhere((e) => e.value == v,
          orElse: () => EmergencyType.helpNeeded);
}

class EmergencyAlert {
  const EmergencyAlert({
    required this.id,
    required this.senderId,
    required this.type,
    required this.status,
    required this.createdAt,
    this.villageId,
    this.message,
    this.lat,
    this.lng,
    this.resolvedAt,
  });

  final String id;
  final String senderId;
  final EmergencyType type;
  final String status; // active | resolved | cancelled
  final DateTime createdAt;
  final String? villageId;
  final String? message;
  final double? lat;
  final double? lng;
  final DateTime? resolvedAt;

  bool get isActive => status == 'active';

  factory EmergencyAlert.fromMap(Map<String, dynamic> map) {
    return EmergencyAlert(
      id: map['id'] as String,
      senderId: map['sender_id'] as String,
      type: EmergencyType.fromValue(map['alert_type'] as String?),
      status: (map['status'] as String?) ?? 'active',
      createdAt:
          DateTime.tryParse(map['created_at'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      villageId: map['village_id'] as String?,
      message: map['message'] as String?,
      lat: (map['lat'] as num?)?.toDouble(),
      lng: (map['lng'] as num?)?.toDouble(),
      resolvedAt: map['resolved_at'] == null
          ? null
          : DateTime.tryParse(map['resolved_at'] as String)?.toLocal(),
    );
  }
}
