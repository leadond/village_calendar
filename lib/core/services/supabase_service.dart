import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient _client;

  SupabaseService({required SupabaseClient client}) : _client = client;

  SupabaseClient get client => _client;
}
