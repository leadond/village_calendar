import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/village_event.dart';

class EventsRepository {
  const EventsRepository(this._client);

  final SupabaseClient _client;

  Future<List<VillageEvent>> listEvents() async {
    final rows = await _client
        .from('events')
        .select()
        .order('starts_at', ascending: true);

    return rows
        .map((row) => VillageEvent.fromJson(Map<String, dynamic>.from(row)))
        .toList();
  }

  Future<VillageEvent> createEvent(EventDraft draft) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('You must be signed in to create events.');
    }

    final payload = <String, dynamic>{
      'title': draft.title,
      'description': draft.description,
      'location': draft.location,
      'starts_at': draft.startsAt.toUtc().toIso8601String(),
      'ends_at': draft.endsAt?.toUtc().toIso8601String(),
      'created_by': user.id,
    };

    final row = await _client.from('events').insert(payload).select().single();

    return VillageEvent.fromJson(Map<String, dynamic>.from(row));
  }

  Future<void> deleteEvent(String id) async {
    await _client.from('events').delete().eq('id', id);
  }
}
