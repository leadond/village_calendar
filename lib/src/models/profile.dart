/// App user profile, backed by `public.profiles`.
///
/// The live table is a V1/V2 hybrid: it has both legacy `name` and V2
/// `display_name`, and both `village_id` (V2, used by RLS `current_village_id()`)
/// and `current_village_id`. We standardize on `display_name` + `village_id`.
class Profile {
  const Profile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.role,
    this.villageId,
    this.avatarUrl,
    this.subscriptionTier = 'free',
    this.reliabilityScore = 5.0,
  });

  final String id;
  final String email;
  final String displayName;
  final UserRole role;
  final String? villageId;
  final String? avatarUrl;
  final String subscriptionTier;
  final double reliabilityScore;

  bool get hasVillage => villageId != null && villageId!.isNotEmpty;
  bool get isAdmin => role == UserRole.admin;

  factory Profile.fromMap(Map<String, dynamic> map) {
    final displayName =
        (map['display_name'] as String?)?.trim().isNotEmpty == true
        ? (map['display_name'] as String).trim()
        : (map['name'] as String?)?.trim() ??
              _localPart(map['email'] as String?);

    // The ACTIVE village (current_village_id) drives the whole app; fall back to
    // the legacy single-village column for older rows.
    final active = (map['current_village_id'] as String?) ??
        (map['village_id'] as String?);

    return Profile(
      id: map['id'] as String,
      email: (map['email'] as String?) ?? '',
      displayName: displayName,
      role: UserRole.fromName(map['role'] as String?),
      villageId: active,
      avatarUrl: map['avatar_url'] as String?,
      subscriptionTier: (map['subscription_tier'] as String?) ?? 'free',
      reliabilityScore:
          (map['reliability_score'] as num?)?.toDouble() ?? 5.0,
    );
  }

  Profile copyWith({
    String? displayName,
    UserRole? role,
    String? villageId,
  }) {
    return Profile(
      id: id,
      email: email,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      villageId: villageId ?? this.villageId,
      avatarUrl: avatarUrl,
      subscriptionTier: subscriptionTier,
      reliabilityScore: reliabilityScore,
    );
  }

  static String _localPart(String? email) {
    if (email == null || email.isEmpty) return 'Member';
    final at = email.indexOf('@');
    return at > 0 ? email.substring(0, at) : email;
  }
}

/// Mirrors the `public.user_role` Postgres enum.
enum UserRole {
  parent,
  helper,
  admin,
  guest;

  static UserRole fromName(String? value) {
    switch (value) {
      case 'helper':
        return UserRole.helper;
      case 'admin':
        return UserRole.admin;
      case 'guest':
        return UserRole.guest;
      case 'parent':
      default:
        return UserRole.parent;
    }
  }

  String get label {
    switch (this) {
      case UserRole.parent:
        return 'Parent';
      case UserRole.helper:
        return 'Helper';
      case UserRole.admin:
        return 'Admin';
      case UserRole.guest:
        return 'Guest';
    }
  }

  String get description {
    switch (this) {
      case UserRole.parent:
        return 'Create help requests and manage your kids.';
      case UserRole.helper:
        return 'Claim requests and help out around the village.';
      case UserRole.admin:
        return 'Run the village and manage members.';
      case UserRole.guest:
        return 'View activity with limited access.';
    }
  }
}
