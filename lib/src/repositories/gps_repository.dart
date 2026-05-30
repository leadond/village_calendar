import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/breadcrumb.dart';

class GpsRepository {
  const GpsRepository(this._client);

  final SupabaseClient _client;

  /// Helper writes a breadcrumb for an active trip.
  Future<void> insertBreadcrumb({
    required String requestId,
    required double lat,
    required double lng,
    double? accuracy,
    double? speed,
    double? heading,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw const AuthException('You must be signed in.');
    await _client.from('gps_breadcrumbs').insert({
      'request_id': requestId,
      'helper_id': user.id,
      'lat': lat,
      'lng': lng,
      'accuracy': accuracy,
      'speed': speed,
      'heading': heading,
    });
  }

  /// Live breadcrumb trail for a request (parent watches the helper).
  Stream<List<Breadcrumb>> stream(String requestId) {
    return _client
        .from('gps_breadcrumbs')
        .stream(primaryKey: ['id'])
        .eq('request_id', requestId)
        .order('ts')
        .map((rows) => rows
            .map((r) => Breadcrumb.fromMap(Map<String, dynamic>.from(r)))
            .toList());
  }
}
