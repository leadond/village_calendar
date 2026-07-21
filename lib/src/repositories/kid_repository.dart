import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/kid_profile.dart';

class KidRepository {
  const KidRepository(this._client);

  final SupabaseClient _client;

  static const _bucket = 'kid-photos';
  static const _columns =
      'id, parent_id, village_id, name, nickname, photo_url, date_of_birth, '
      'birthdate, grade, school_name, school, allergies, medical_notes, notes';

  Future<List<KidProfile>> listForParent(String parentId) async {
    final rows = await _client
        .from('kid_profiles')
        .select(_columns)
        .eq('parent_id', parentId)
        .order('name', ascending: true);
    return rows
        .map((r) => KidProfile.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  Future<KidProfile> create(KidDraft draft, {String? villageId}) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const AuthException('You must be signed in.');
    }
    final payload = draft.toColumns()
      ..['parent_id'] = user.id
      ..['village_id'] = villageId;

    final row = await _client
        .from('kid_profiles')
        .insert(payload)
        .select(_columns)
        .single();
    return KidProfile.fromMap(Map<String, dynamic>.from(row));
  }

  Future<KidProfile> update(String id, KidDraft draft) async {
    final row = await _client
        .from('kid_profiles')
        .update(draft.toColumns())
        .eq('id', id)
        .select(_columns)
        .single();
    return KidProfile.fromMap(Map<String, dynamic>.from(row));
  }

  Future<void> delete(String id) async {
    await _client.from('kid_profiles').delete().eq('id', id);
  }

  /// Uploads photo bytes and returns the storage PATH (bucket is private; the
  /// path is stored in kid_profiles.photo_url and resolved to a signed URL for
  /// display).
  Future<String> uploadPhoto({
    required String userId,
    required Uint8List bytes,
    String extension = 'jpg',
  }) async {
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$extension';
    await _client.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            upsert: true,
            contentType: 'image/$extension',
          ),
        );
    return path;
  }

  /// Resolves a stored photo reference (path, or a legacy public URL) to a
  /// short-lived signed URL. Returns null if it can't be signed.
  Future<String?> signedPhotoUrl(String? stored) async {
    if (stored == null || stored.isEmpty) return null;
    var path = stored;
    const marker = '/kid-photos/';
    final idx = stored.indexOf(marker);
    if (idx >= 0) path = stored.substring(idx + marker.length);
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }
}
