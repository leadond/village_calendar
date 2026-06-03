import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/app_notification.dart';

class NotificationRepository {
  const NotificationRepository(this._client);

  final SupabaseClient _client;

  Stream<List<AppNotification>> stream(String userId) {
    return _client
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('recipient_id', userId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => AppNotification.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }

  Future<void> markRead(String id) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }

  Future<void> markAllRead(String userId) async {
    await _client
        .from('notifications')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('recipient_id', userId)
        .isFilter('read_at', null);
  }

  /// Saves the device's FCM token so the backend can push to this user.
  Future<void> savePushToken(String userId, String token) async {
    await _client
        .from('profiles')
        .update({'push_token': token}).eq('id', userId);
  }

  Future<Map<String, dynamic>> getSettings(String userId) async {
    final row = await _client
        .from('notification_settings')
        .select()
        .eq('profile_id', userId)
        .maybeSingle();
    return row == null ? <String, dynamic>{} : Map<String, dynamic>.from(row);
  }

  Future<void> updateSettings(String userId, Map<String, dynamic> patch) async {
    await _client
        .from('notification_settings')
        .update(patch)
        .eq('profile_id', userId);
  }
}
