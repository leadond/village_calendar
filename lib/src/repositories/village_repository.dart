import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/join_request.dart';
import '../models/village.dart';

class VillageRepository {
  const VillageRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, name, invite_code, admin_id, village_type, avatar_url';

  Future<Village?> fetchVillage(String id) async {
    final row = await _client
        .from('villages')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return Village.fromMap(Map<String, dynamic>.from(row));
  }

  /// Creates a village via RPC: inserts the village, adds the creator as an
  /// admin member, and makes it the active village (atomic, RLS-safe).
  Future<Village> createVillage({
    required String name,
    String villageType = 'family',
  }) async {
    final res = await _client.rpc('create_village', params: {
      'p_name': name.trim(),
      'p_type': villageType,
    });
    return Village.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// All villages the user belongs to (for the switcher), with per-village role.
  Future<List<VillageMembership>> myVillages() async {
    final res = await _client.rpc('my_villages');
    final list = (res as List?) ?? const [];
    return list
        .map((e) => VillageMembership.fromMap(Map<String, dynamic>.from(e)))
        .toList();
  }

  /// Switches which village is active (scopes all data to it).
  Future<void> switchActiveVillage(String villageId) async {
    await _client.rpc('switch_active_village', params: {'p_village': villageId});
  }

  /// Members of the active village, each with their role in this village.
  Future<List<Map<String, dynamic>>> activeVillageMembers() async {
    final res = await _client.rpc('active_village_members');
    final list = (res as List?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  /// Requests to join the village with [inviteCode]. Creates a pending request
  /// for a village admin to approve (membership is NOT granted immediately).
  Future<JoinRequestResult> requestToJoin(String inviteCode) async {
    final code = inviteCode.trim().toUpperCase();
    if (code.isEmpty) return const JoinRequestResult('not_found');

    final res = await _client
        .rpc('request_to_join_village', params: {'p_code': code});
    final map = (res is Map)
        ? Map<String, dynamic>.from(res)
        : const <String, dynamic>{};
    return JoinRequestResult(
      (map['status'] as String?) ?? 'error',
      villageName: map['village_name'] as String?,
    );
  }

  /// The caller's own outstanding pending join request, if any.
  Future<PendingJoin?> myPendingJoin() async {
    final res = await _client.rpc('my_pending_join_request');
    if (res == null) return null;
    final m = Map<String, dynamic>.from(res as Map);
    return PendingJoin(
      requestId: m['request_id'] as String,
      villageId: m['village_id'] as String,
      villageName: m['village_name'] as String,
    );
  }

  /// Pending requests for the admin's village (empty if caller isn't admin).
  Future<List<JoinRequestItem>> pendingJoinRequests() async {
    final res = await _client.rpc('pending_join_requests');
    final list = (res as List?) ?? const [];
    return list.map((e) {
      final m = Map<String, dynamic>.from(e as Map);
      return JoinRequestItem(
        requestId: m['request_id'] as String,
        requesterId: m['requester_id'] as String,
        displayName: (m['display_name'] as String?) ?? '',
        email: (m['email'] as String?) ?? '',
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
    }).toList();
  }

  Future<void> approveJoin(String requestId) async {
    await _client.rpc('approve_join_request', params: {'p_request_id': requestId});
  }

  Future<void> rejectJoin(String requestId) async {
    await _client.rpc('reject_join_request', params: {'p_request_id': requestId});
  }

  /// Requester cancels their own pending request.
  Future<void> cancelMyJoin(String requestId) async {
    await _client.from('village_join_requests').delete().eq('id', requestId);
  }

  // ---- admin (active village) ----
  Future<void> setMemberRole(String userId, String role) async {
    await _client.rpc('set_member_role',
        params: {'p_user': userId, 'p_role': role});
  }

  Future<void> removeMember(String userId) async {
    await _client.rpc('remove_member', params: {'p_user': userId});
  }

  Future<List<Map<String, dynamic>>> activeVillageAudit() async {
    final res = await _client.rpc('active_village_audit');
    final list = (res as List?) ?? const [];
    return list.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
