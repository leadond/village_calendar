import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/help_request.dart';

class HelpRequestRepository {
  const HelpRequestRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, village_id, creator_id, helper_id, title, description, category, '
      'status, scheduled_start, scheduled_at, scheduled_end, pickup_address, '
      'dropoff_address, special_instructions, kid_ids, parent_confirmed_at, '
      'helper_checkin_at, arrived_at_destination_at, parent_receipt_confirmed_at, '
      'created_at';

  Future<HelpRequest> create(
    HelpRequestDraft draft, {
    required String villageId,
    required String creatorId,
  }) async {
    final payload = draft.toColumns()
      ..['village_id'] = villageId
      ..['creator_id'] = creatorId;

    final row = await _client
        .from('help_requests')
        .insert(payload)
        .select(_columns)
        .single();
    return HelpRequest.fromMap(Map<String, dynamic>.from(row));
  }

  /// Requests created by [userId] in [villageId] (scoped to the active village).
  Future<List<HelpRequest>> myRequests(String userId, String villageId) async {
    final rows = await _client
        .from('help_requests')
        .select(_columns)
        .eq('creator_id', userId)
        .eq('village_id', villageId)
        .order('scheduled_start', ascending: false);
    return _map(rows);
  }

  /// Open requests in [villageId] not created by [userId] (the helper view).
  Future<List<HelpRequest>> availableRequests(
    String villageId,
    String userId,
  ) async {
    final rows = await _client
        .from('help_requests')
        .select(_columns)
        .eq('village_id', villageId)
        .eq('status', 'open')
        .neq('creator_id', userId)
        .order('scheduled_start', ascending: true);
    return _map(rows);
  }

  /// Requests [helperId] has claimed.
  Future<List<HelpRequest>> claimedByMe(String helperId) async {
    final rows = await _client
        .from('help_requests')
        .select(_columns)
        .eq('helper_id', helperId)
        .order('scheduled_start', ascending: true);
    return _map(rows);
  }

  Future<HelpRequest> fetch(String id) async {
    final row = await _client
        .from('help_requests')
        .select(_columns)
        .eq('id', id)
        .single();
    return HelpRequest.fromMap(Map<String, dynamic>.from(row));
  }

  // --- lifecycle ------------------------------------------------------------

  /// Helper claims an open request (RLS-safe RPC).
  Future<void> claim(String id) async {
    await _client.rpc('claim_help_request', params: {'p_request_id': id});
  }

  /// Parent confirms the claim.
  Future<void> confirm(String id) => _update(id, {
        'status': 'confirmed',
        'parent_confirmed_at': _now(),
      });

  /// Helper: on my way.
  Future<void> startTrip(String id) => _update(id, {'status': 'in_progress'});

  /// Helper: arrived at pickup.
  Future<void> arrivePickup(String id) => _update(id, {
        'status': 'arrived',
        'helper_checkin_at': _now(),
      });

  /// Helper: arrived at dropoff/destination.
  Future<void> arriveDropoff(String id) =>
      _update(id, {'arrived_at_destination_at': _now()});

  /// Parent confirms receipt -> completed.
  Future<void> complete(String id) => _update(id, {
        'status': 'completed',
        'parent_receipt_confirmed_at': _now(),
      });

  Future<void> cancel(String id, {String? reason, required String byUserId}) =>
      _update(id, {
        'status': 'cancelled',
        'cancellation_reason': reason,
        'cancelled_by': byUserId,
      });

  Future<void> _update(String id, Map<String, dynamic> patch) async {
    await _client.from('help_requests').update(patch).eq('id', id);
  }

  // --- comments -------------------------------------------------------------

  Stream<List<RequestComment>> commentsStream(String requestId) {
    return _client
        .from('request_comments')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('created_at')
        .map((rows) => rows
            .map((r) => RequestComment.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }

  Future<void> addComment(String requestId, String body) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await _client.from('request_comments').insert({
      'request_id': requestId,
      'author_id': user.id,
      'body': body.trim(),
    });
  }

  List<HelpRequest> _map(List<Map<String, dynamic>> rows) => rows
      .map((r) => HelpRequest.fromMap(Map<String, dynamic>.from(r)))
      .toList();

  static String _now() => DateTime.now().toUtc().toIso8601String();
}
