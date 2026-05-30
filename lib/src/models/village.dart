/// A village, backed by `public.villages`.
class Village {
  const Village({
    required this.id,
    required this.name,
    required this.inviteCode,
    this.adminId,
    this.villageType = 'family',
    this.avatarUrl,
  });

  final String id;
  final String name;
  final String inviteCode;
  final String? adminId;
  final String villageType;
  final String? avatarUrl;

  factory Village.fromMap(Map<String, dynamic> map) {
    return Village(
      id: map['id'] as String,
      name: (map['name'] as String?) ?? 'Village',
      inviteCode: (map['invite_code'] as String?) ?? '',
      adminId: map['admin_id'] as String?,
      villageType: (map['village_type'] as String?) ?? 'family',
      avatarUrl: map['avatar_url'] as String?,
    );
  }
}

/// Mirrors the `public.village_type` Postgres enum.
const List<String> kVillageTypes = <String>[
  'family',
  'sports',
  'school',
  'work',
  'other',
];

/// One of the user's village memberships (for the switcher), with the role they
/// hold in that specific village.
class VillageMembership {
  const VillageMembership({
    required this.villageId,
    required this.name,
    required this.inviteCode,
    required this.role,
    required this.isActive,
  });

  final String villageId;
  final String name;
  final String inviteCode;
  final String role; // user_role text
  final bool isActive;

  factory VillageMembership.fromMap(Map<String, dynamic> map) {
    return VillageMembership(
      villageId: map['village_id'] as String,
      name: (map['name'] as String?) ?? 'Village',
      inviteCode: (map['invite_code'] as String?) ?? '',
      role: (map['role'] as String?) ?? 'parent',
      isActive: (map['is_active'] as bool?) ?? false,
    );
  }
}
