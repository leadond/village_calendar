import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/help_request.dart';
import '../models/message.dart';

class MessageRepository {
  const MessageRepository(this._client);

  final SupabaseClient _client;

  /// Threads = requests in the active village where the user is the creator or
  /// the assigned helper (i.e. there's a counterpart to chat with).
  Future<List<HelpRequest>> threads(String villageId, String userId) async {
    final rows = await _client
        .from('help_requests')
        .select()
        .eq('village_id', villageId)
        .not('helper_id', 'is', null)
        .or('creator_id.eq.$userId,helper_id.eq.$userId')
        .order('scheduled_start', ascending: false);
    return rows
        .map((r) => HelpRequest.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Stream<List<Message>> stream(String requestId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .map((rows) => rows
            .map((r) => Message.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }

  Future<void> send({
    required String requestId,
    required String? recipientId,
    required String text,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await _client.from('messages').insert({
      'request_id': requestId,
      'sender_id': user.id,
      'recipient_id': recipientId,
      'content': text.trim(),
      'body': text.trim(),
    });
  }
}
