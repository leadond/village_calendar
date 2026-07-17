import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/availability_block.dart';

class AvailabilityRepository {
  const AvailabilityRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, user_id, village_id, kind, weekday, specific_date, start_time, end_time, note';

  Future<List<AvailabilityBlock>> forUser(String userId) async {
    final rows = await _client
        .from('availability_blocks')
        .select(_columns)
        .eq('user_id', userId)
        .order('weekday', ascending: true)
        .order('start_time', ascending: true);
    return rows
        .map((r) => AvailabilityBlock.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<List<AvailabilityBlock>> forVillage(String villageId) async {
    final rows = await _client
        .from('availability_blocks')
        .select(_columns)
        .eq('village_id', villageId);
    return rows
        .map((r) => AvailabilityBlock.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<void> add({
    required String villageId,
    required String kind,
    required int startMinutes,
    required int endMinutes,
    int? weekday,
    DateTime? specificDate,
    String? note,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await _client.from('availability_blocks').insert({
      'user_id': user.id,
      'village_id': villageId,
      'kind': kind,
      'weekday': specificDate == null ? weekday : null,
      'specific_date': specificDate == null
          ? null
          : '${specificDate.year.toString().padLeft(4, '0')}-'
              '${specificDate.month.toString().padLeft(2, '0')}-'
              '${specificDate.day.toString().padLeft(2, '0')}',
      'start_time': _fmt(startMinutes),
      'end_time': _fmt(endMinutes),
      'note': note,
    });
  }

  Future<void> delete(String id) async {
    await _client.from('availability_blocks').delete().eq('id', id);
  }

  static String _fmt(int mins) =>
      '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';
}
