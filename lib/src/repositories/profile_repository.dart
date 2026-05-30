import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/profile.dart';

class ProfileRepository {
  const ProfileRepository(this._client);

  final SupabaseClient _client;

  static const _columns =
      'id, email, display_name, name, role, village_id, current_village_id, '
      'avatar_url, subscription_tier, reliability_score';

  /// Loads a single profile by id. Returns null if it does not exist yet.
  Future<Profile?> fetchProfile(String id) async {
    final row = await _client
        .from('profiles')
        .select(_columns)
        .eq('id', id)
        .maybeSingle();

    if (row == null) return null;
    return Profile.fromMap(Map<String, dynamic>.from(row));
  }

  /// Updates the signed-in user's display name and role.
  Future<Profile> updateProfile({
    required String id,
    String? displayName,
    UserRole? role,
  }) async {
    final payload = <String, dynamic>{};
    if (displayName != null) {
      payload['display_name'] = displayName;
      payload['name'] = displayName; // keep legacy column in sync
    }
    if (role != null) {
      payload['role'] = role.name;
    }

    final row = await _client
        .from('profiles')
        .update(payload)
        .eq('id', id)
        .select(_columns)
        .single();

    return Profile.fromMap(Map<String, dynamic>.from(row));
  }

  /// Sets (or clears) the user's active village.
  Future<void> setVillage({required String id, required String? villageId}) {
    return _client
        .from('profiles')
        .update({'village_id': villageId, 'current_village_id': villageId})
        .eq('id', id);
  }
}
