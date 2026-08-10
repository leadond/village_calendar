import 'dart:convert';

import '../models/help_request.dart';
import 'setup_services.dart';

class AiAssistantService {
  const AiAssistantService();

  Future<HelpRequestDraft> draftHelpRequest(String prompt) async {
    final client = SetupServices.maybeSupabaseClient;
    if (client == null) {
      throw StateError(
        'Supabase is not configured, so AI drafting is unavailable.',
      );
    }

    final response = await client.functions.invoke(
      'ai-assistant',
      body: {
        'taskType': 'draft_help_request',
        'prompt': prompt,
      },
    );

    if (response.status != 200) {
      throw StateError(_extractErrorMessage(response.data));
    }

    final payload = _normalizeMap(response.data);
    if (payload == null) {
      throw StateError('Unexpected AI response payload.');
    }

    final draft = payload['draft'];
    final draftMap = _normalizeMap(draft);
    if (draftMap == null) {
      throw StateError('AI did not return a valid request draft.');
    }

    final category = HelpCategory.fromValue(draftMap['category'] as String?);
    return HelpRequestDraft(
      title: (draftMap['title'] as String? ?? '').trim(),
      category: category,
      scheduledStart: DateTime.now().add(const Duration(hours: 1)),
      description: (draftMap['description'] as String?)?.trim(),
      pickupAddress: (draftMap['pickupAddress'] as String?)?.trim(),
      dropoffAddress: (draftMap['dropoffAddress'] as String?)?.trim(),
      specialInstructions: (draftMap['specialInstructions'] as String?)?.trim(),
    );
  }

  Future<Map<String, String>> improveAnnouncement({
    required String title,
    required String message,
  }) async {
    final client = SetupServices.maybeSupabaseClient;
    if (client == null) {
      throw StateError(
        'Supabase is not configured, so AI announcement help is unavailable.',
      );
    }

    final response = await client.functions.invoke(
      'ai-assistant',
      body: {
        'taskType': 'improve_announcement',
        'title': title,
        'message': message,
      },
    );

    if (response.status != 200) {
      throw StateError(_extractErrorMessage(response.data));
    }

    final payload = _normalizeMap(response.data);
    if (payload == null) {
      throw StateError('Unexpected AI response payload.');
    }

    final draft = payload['draft'];
    final draftMap = _normalizeMap(draft);
    if (draftMap == null) {
      throw StateError('AI did not return a valid announcement draft.');
    }

    return {
      'title': (draftMap['title'] as String? ?? '').trim(),
      'message': (draftMap['message'] as String? ?? '').trim(),
    };
  }

  String _extractErrorMessage(dynamic data) {
    final payload = _normalizeMap(data);
    if (payload != null) {
      final message = payload['message'];
      if (message is String && message.trim().isNotEmpty) {
        return message;
      }

      final error = payload['error'];
      if (error is String && error.trim().isNotEmpty) {
        return error;
      }
    }

    if (data is String && data.trim().isNotEmpty) {
      return data;
    }

    return 'The AI assistant request failed.';
  }

  Map<String, dynamic>? _normalizeMap(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return value.map(
        (key, entryValue) => MapEntry(key.toString(), entryValue),
      );
    }

    if (value is String && value.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
        if (decoded is Map) {
          return decoded.map(
            (key, entryValue) => MapEntry(key.toString(), entryValue),
          );
        }
      } catch (_) {
        return null;
      }
    }

    return null;
  }
}
