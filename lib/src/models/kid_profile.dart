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
    this.careStartMinutes,
    this.careEndMinutes,
    this.careWeekdays = const [1, 2, 3, 4, 5],
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

  /// School/daycare window (minutes from midnight) + weekdays (1=Mon..7=Sun,
  /// matching DateTime.weekday). Used to auto-generate coverage requests.
  final int? careStartMinutes;
  final int? careEndMinutes;
  final List<int> careWeekdays;

  bool get hasCareWindow =>
      careStartMinutes != null && careEndMinutes != null;

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

    final weekdaysRaw = map['care_weekdays'];
    final careWeekdays = <int>[];
    if (weekdaysRaw is List) {
      for (final w in weekdaysRaw) {
        if (w is int) careWeekdays.add(w);
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
      careStartMinutes: _parseTime(map['care_start_time'] as String?),
      careEndMinutes: _parseTime(map['care_end_time'] as String?),
      careWeekdays:
          careWeekdays.isEmpty ? const [1, 2, 3, 4, 5] : careWeekdays,
    );
  }

  static int? _parseTime(String? t) {
    if (t == null || t.isEmpty) return null;
    final parts = t.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    return h * 60 + m;
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
    this.careStartMinutes,
    this.careEndMinutes,
    this.careWeekdays = const [1, 2, 3, 4, 5],
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
  int? careStartMinutes;
  int? careEndMinutes;
  List<int> careWeekdays;

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
      'care_start_time': _fmtMins(careStartMinutes),
      'care_end_time': _fmtMins(careEndMinutes),
      'care_weekdays': careWeekdays,
    };
  }

  static String? _nz(String? v) =>
      (v == null || v.trim().isEmpty) ? null : v.trim();

  static String? _fmtMins(int? mins) => mins == null
      ? null
      : '${(mins ~/ 60).toString().padLeft(2, '0')}:${(mins % 60).toString().padLeft(2, '0')}';
}
