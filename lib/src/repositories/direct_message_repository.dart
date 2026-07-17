import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/direct_message.dart';

class DirectMessageRepository {
  const DirectMessageRepository(this._client);

  final SupabaseClient _client;

  /// Stream of ALL direct messages the user can see in [villageId]. RLS already
  /// limits this to conversations the user is part of; callers filter by peer.
  Stream<List<DirectMessage>> streamAll(String villageId) {
    return _client
        .from('direct_messages')
        .stream(primaryKey: ['id'])
        .eq('village_id', villageId)
        .order('created_at')
        .map((rows) => rows
            .map((r) => DirectMessage.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }

  Future<void> send({
    required String villageId,
    required String recipientId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await _client.from('direct_messages').insert({
      'village_id': villageId,
      'sender_id': user.id,
      'recipient_id': recipientId,
      'body': body.trim(),
    });
  }

  Future<void> markRead(String id) async {
    await _client
        .from('direct_messages')
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}
