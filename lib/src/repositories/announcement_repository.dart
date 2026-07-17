import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/direct_message.dart' show Announcement;

class AnnouncementRepository {
  const AnnouncementRepository(this._client);

  final SupabaseClient _client;

  Stream<List<Announcement>> stream(String villageId) {
    return _client
        .from('village_announcements')
        .stream(primaryKey: ['id'])
        .eq('village_id', villageId)
        .order('created_at', ascending: false)
        .map((rows) => rows
            .map((r) => Announcement.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }

  Future<void> post({
    required String villageId,
    required String title,
    required String message,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await _client.from('village_announcements').insert({
      'village_id': villageId,
      'created_by': user.id,
      'title': title.trim(),
      'message': message.trim(),
    });
  }

  Future<void> delete(String id) async {
    await _client.from('village_announcements').delete().eq('id', id);
  }
}
