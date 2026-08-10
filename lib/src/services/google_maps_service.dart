import 'dart:convert';

import 'package:http/http.dart' as http;

import 'setup_services.dart';

class PlaceSuggestion {
  const PlaceSuggestion({
    required this.primaryText,
    required this.fullText,
    this.secondaryText,
    this.placeId,
  });

  final String primaryText;
  final String fullText;
  final String? secondaryText;
  final String? placeId;

  @override
  String toString() => fullText;
}

class GeocodedLocation {
  const GeocodedLocation({
    required this.formattedAddress,
    required this.latitude,
    required this.longitude,
  });

  final String formattedAddress;
  final double latitude;
  final double longitude;
}

class RouteEstimate {
  const RouteEstimate({
    required this.distanceMeters,
    required this.duration,
  });

  final int distanceMeters;
  final Duration duration;

  String get distanceLabel {
    final miles = distanceMeters / 1609.344;
    if (miles < 0.1) {
      return '$distanceMeters m';
    }
    return '${miles.toStringAsFixed(miles >= 10 ? 0 : 1)} mi';
  }

  String get durationLabel {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${duration.inMinutes} min';
  }
}

class GoogleMapsService {
  const GoogleMapsService();

  static const _placesAutocompleteEndpoint =
      'https://places.googleapis.com/v1/places:autocomplete';
  static const _routesEndpoint =
      'https://routes.googleapis.com/directions/v2:computeRoutes';

  bool get isConfigured => AppConfig.hasGoogleMapsKey;

  Future<List<PlaceSuggestion>> autocompleteAddress(
    String query, {
    String? sessionToken,
  }) async {
    if (!isConfigured) return const [];

    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];

    final response = await http.post(
      Uri.parse(_placesAutocompleteEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
        'X-Goog-FieldMask':
            'suggestions.placePrediction.placeId,'
            'suggestions.placePrediction.text.text,'
            'suggestions.placePrediction.structuredFormat.mainText.text,'
            'suggestions.placePrediction.structuredFormat.secondaryText.text',
      },
      body: jsonEncode({
        'input': trimmed,
        if (sessionToken != null && sessionToken.isNotEmpty)
          'sessionToken': sessionToken,
        'includedPrimaryTypes': const ['street_address', 'school'],
      }),
    );

    if (response.statusCode != 200) {
      throw StateError(_extractMessage(response.body, 'Address search failed.'));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final suggestions = (decoded['suggestions'] as List?)
            ?.whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .toList() ??
        const [];

    return suggestions
        .map((entry) {
          final prediction = entry['placePrediction'];
          if (prediction is! Map) return null;
          final data = Map<String, dynamic>.from(prediction);
          final structured = data['structuredFormat'];
          final structuredMap = structured is Map
              ? Map<String, dynamic>.from(structured)
              : const <String, dynamic>{};
          final mainTextMap = structuredMap['mainText'] is Map
              ? Map<String, dynamic>.from(structuredMap['mainText'] as Map)
              : const <String, dynamic>{};
          final secondaryTextMap = structuredMap['secondaryText'] is Map
              ? Map<String, dynamic>.from(
                  structuredMap['secondaryText'] as Map,
                )
              : const <String, dynamic>{};
          final textMap = data['text'] is Map
              ? Map<String, dynamic>.from(data['text'] as Map)
              : const <String, dynamic>{};
          final fullText = (textMap['text'] as String?)?.trim() ?? '';
          if (fullText.isEmpty) return null;
          return PlaceSuggestion(
            primaryText:
                (mainTextMap['text'] as String?)?.trim().isNotEmpty == true
                    ? (mainTextMap['text'] as String).trim()
                    : fullText,
            secondaryText: (secondaryTextMap['text'] as String?)?.trim(),
            fullText: fullText,
            placeId: (data['placeId'] as String?)?.trim(),
          );
        })
        .whereType<PlaceSuggestion>()
        .toList();
  }

  Future<GeocodedLocation?> geocodeAddress(String address) async {
    if (!isConfigured) return null;

    final trimmed = address.trim();
    if (trimmed.isEmpty) return null;

    final response = await http.get(
      Uri.https('maps.googleapis.com', '/maps/api/geocode/json', {
        'address': trimmed,
        'key': AppConfig.googleMapsApiKey,
      }),
    );

    if (response.statusCode != 200) {
      throw StateError(_extractMessage(response.body, 'Address lookup failed.'));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (decoded['results'] as List?)?.whereType<Map>().toList() ??
        const [];
    if (results.isEmpty) return null;

    final first = Map<String, dynamic>.from(results.first);
    final geometry = first['geometry'];
    if (geometry is! Map) return null;
    final location = geometry['location'];
    if (location is! Map) return null;

    return GeocodedLocation(
      formattedAddress:
          (first['formatted_address'] as String?)?.trim() ?? trimmed,
      latitude: (location['lat'] as num?)?.toDouble() ?? 0,
      longitude: (location['lng'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<RouteEstimate?> estimateRoute({
    required String originAddress,
    required String destinationAddress,
  }) async {
    if (!isConfigured) return null;

    final origin = await geocodeAddress(originAddress);
    final destination = await geocodeAddress(destinationAddress);
    if (origin == null || destination == null) return null;

    final response = await http.post(
      Uri.parse(_routesEndpoint),
      headers: {
        'Content-Type': 'application/json',
        'X-Goog-Api-Key': AppConfig.googleMapsApiKey,
        'X-Goog-FieldMask': 'routes.duration,routes.distanceMeters',
      },
      body: jsonEncode({
        'origin': {
          'location': {
            'latLng': {
              'latitude': origin.latitude,
              'longitude': origin.longitude,
            },
          },
        },
        'destination': {
          'location': {
            'latLng': {
              'latitude': destination.latitude,
              'longitude': destination.longitude,
            },
          },
        },
        'travelMode': 'DRIVE',
        'routingPreference': 'TRAFFIC_AWARE',
      }),
    );

    if (response.statusCode != 200) {
      throw StateError(_extractMessage(response.body, 'Route estimate failed.'));
    }

    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final routes =
        (decoded['routes'] as List?)?.whereType<Map>().toList() ?? const [];
    if (routes.isEmpty) return null;

    final route = Map<String, dynamic>.from(routes.first);
    final durationText = (route['duration'] as String?) ?? '0s';
    final distanceMeters = (route['distanceMeters'] as num?)?.toInt() ?? 0;

    return RouteEstimate(
      distanceMeters: distanceMeters,
      duration: _parseDuration(durationText),
    );
  }

  Duration _parseDuration(String value) {
    final cleaned = value.trim().replaceAll('s', '');
    final seconds = double.tryParse(cleaned) ?? 0;
    return Duration(milliseconds: (seconds * 1000).round());
  }

  String _extractMessage(String raw, String fallback) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) {
          final message = error['message'];
          if (message is String && message.trim().isNotEmpty) {
            return message;
          }
        }
        final status = decoded['status'];
        if (status is String && status.trim().isNotEmpty) {
          return status;
        }
      }
    } catch (_) {
      // Fall through to the generic fallback below.
    }
    return fallback;
  }
}
