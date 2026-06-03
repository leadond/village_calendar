import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/emergency_alert.dart';

class EmergencyRepository {
  const EmergencyRepository(this._client);

  final SupabaseClient _client;

  Future<void> create({
    required String villageId,
    required EmergencyType type,
    String? message,
    double? lat,
    double? lng,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await _client.from('emergency_alerts').insert({
      'sender_id': user.id,
      'village_id': villageId,
      'alert_type': type.value,
      'message': message,
      'lat': lat,
      'lng': lng,
    });
  }

  /// Live alerts for the active village (newest first).
  Stream<List<EmergencyAlert>> stream(String villageId) {
    return _client
        .from('emergency_alerts')
        .stream(primaryKey: ['id'])
        .eq('village_id', villageId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => EmergencyAlert.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }

  Future<void> resolve(String id, {bool falseAlarm = false}) async {
    final user = _client.auth.currentUser;
    await _client.from('emergency_alerts').update({
      'status': falseAlarm ? 'cancelled' : 'resolved',
      'resolved_by': user?.id,
      'resolved_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }
}
