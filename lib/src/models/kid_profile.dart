/// A child profile, backed by `public.kid_profiles`.
///
/// The live table is a V1/V2 hybrid, so we read legacy + V2 columns and write
/// both where they overlap (school_name/school, date_of_birth/birthdate).
class KidProfile {
  const KidProfile({
    required this.id,
    required this.parentId,
    required this.name,
    this.villageId,
    this.nickname,
    this.photoUrl,
    this.dateOfBirth,
    this.grade,
    this.school,
    this.allergies = const [],
    this.medicalNotes,
    this.notes,
  });

  final String id;
  final String parentId;
  final String name;
  final String? villageId;
  final String? nickname;
  final String? photoUrl;
  final DateTime? dateOfBirth;
  final String? grade;
  final String? school;
  final List<String> allergies;
  final String? medicalNotes;
  final String? notes;

  int? get ageYears {
    if (dateOfBirth == null) return null;
    final now = DateTime.now();
    var age = now.year - dateOfBirth!.year;
    if (now.month < dateOfBirth!.month ||
        (now.month == dateOfBirth!.month && now.day < dateOfBirth!.day)) {
      age--;
    }
    return age < 0 ? null : age;
  }

  factory KidProfile.fromMap(Map<String, dynamic> map) {
    final dobRaw = (map['date_of_birth'] ?? map['birthdate']) as String?;
    final allergiesRaw = map['allergies'];
    final allergies = <String>[];
    if (allergiesRaw is List) {
      for (final a in allergiesRaw) {
        if (a is String && a.trim().isNotEmpty) allergies.add(a.trim());
      }
    }

    return KidProfile(
      id: map['id'] as String,
      parentId: map['parent_id'] as String,
      name: (map['name'] as String?) ?? '',
      villageId: map['village_id'] as String?,
      nickname: map['nickname'] as String?,
      photoUrl: map['photo_url'] as String?,
      dateOfBirth: dobRaw == null ? null : DateTime.tryParse(dobRaw),
      grade: map['grade'] as String?,
      school: (map['school_name'] ?? map['school']) as String?,
      allergies: allergies,
      medicalNotes: map['medical_notes'] as String?,
      notes: map['notes'] as String?,
    );
  }
}

/// Editable fields for creating / updating a kid.
class KidDraft {
  KidDraft({
    required this.name,
    this.nickname,
    this.photoUrl,
    this.dateOfBirth,
    this.grade,
    this.school,
    this.allergies = const [],
    this.medicalNotes,
    this.notes,
  });

  String name;
  String? nickname;
  String? photoUrl;
  DateTime? dateOfBirth;
  String? grade;
  String? school;
  List<String> allergies;
  String? medicalNotes;
  String? notes;

  /// Column map written to Supabase. Mirrors legacy + V2 columns.
  Map<String, dynamic> toColumns() {
    final dob = dateOfBirth == null
        ? null
        : '${dateOfBirth!.year.toString().padLeft(4, '0')}-'
            '${dateOfBirth!.month.toString().padLeft(2, '0')}-'
            '${dateOfBirth!.day.toString().padLeft(2, '0')}';
    return {
      'name': name.trim(),
      'nickname': _nz(nickname),
      'photo_url': _nz(photoUrl),
      'date_of_birth': dob,
      'birthdate': dob,
      'grade': _nz(grade),
      'school_name': _nz(school),
      'school': _nz(school),
      'allergies': allergies,
      'medical_notes': _nz(medicalNotes),
      'notes': _nz(notes),
    };
  }

  static String? _nz(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();
}
