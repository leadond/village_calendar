/// A GPS breadcrumb for a trip, backed by `public.gps_breadcrumbs`.
class Breadcrumb {
  const Breadcrumb({
    required this.lat,
    required this.lng,
    required this.ts,
    this.accuracy,
    this.speed,
    this.heading,
  });

  final double lat;
  final double lng;
  final DateTime ts;
  final double? accuracy;
  final double? speed;
  final double? heading;

  factory Breadcrumb.fromMap(Map<String, dynamic> map) {
    return Breadcrumb(
      lat: (map['lat'] as num).toDouble(),
      lng: (map['lng'] as num).toDouble(),
      ts: DateTime.tryParse(map['ts'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      accuracy: (map['accuracy'] as num?)?.toDouble(),
      speed: (map['speed'] as num?)?.toDouble(),
      heading: (map['heading'] as num?)?.toDouble(),
    );
  }
}
