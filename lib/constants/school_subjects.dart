/// Catalog of school subjects with stable IDs for teacher assignments.
class SchoolSubject {
  const SchoolSubject({required this.id, required this.name});

  final String id;
  final String name;
}

/// Common school subjects including kindergarten.
abstract final class SchoolSubjects {
  static const catalog = <SchoolSubject>[
    SchoolSubject(id: 'SUB-AMH', name: 'Amharic'),
    SchoolSubject(id: 'SUB-ENG', name: 'English'),
    SchoolSubject(id: 'SUB-MATH', name: 'Mathematics'),
    SchoolSubject(id: 'SUB-SCI', name: 'Science'),
    SchoolSubject(id: 'SUB-SOC', name: 'Social Studies'),
    SchoolSubject(id: 'SUB-CIV', name: 'Civics & Ethical Education'),
    SchoolSubject(id: 'SUB-PE', name: 'Physical Education'),
    SchoolSubject(id: 'SUB-ART', name: 'Art'),
    SchoolSubject(id: 'SUB-MUS', name: 'Music'),
    SchoolSubject(id: 'SUB-ICT', name: 'ICT / Computer'),
    SchoolSubject(id: 'SUB-ENV', name: 'Environmental Science'),
    SchoolSubject(id: 'SUB-HLT', name: 'Health Education'),
    SchoolSubject(id: 'SUB-AOR', name: 'Afaan Oromo'),
    SchoolSubject(id: 'SUB-KG-PL', name: 'KG - Play & Learning'),
    SchoolSubject(id: 'SUB-KG-LIT', name: 'KG - Early Literacy'),
    SchoolSubject(id: 'SUB-KG-NUM', name: 'KG - Early Numeracy'),
    SchoolSubject(id: 'SUB-KG-AC', name: 'KG - Art & Craft'),
    SchoolSubject(id: 'SUB-KG-MM', name: 'KG - Music & Movement'),
    SchoolSubject(id: 'SUB-KG-SS', name: 'KG - Social Skills'),
  ];

  static List<String> get all => catalog.map((s) => s.name).toList();

  static const addCustomOption = '__add_subject__';

  static String? idForName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return null;
    for (final subject in catalog) {
      if (subject.name.toLowerCase() == trimmed.toLowerCase()) {
        return subject.id;
      }
    }
    return null;
  }

  static String nameForId(String id) {
    final upper = id.trim().toUpperCase();
    for (final subject in catalog) {
      if (subject.id.toUpperCase() == upper) return subject.name;
    }
    return id;
  }

  /// Stable ID for catalog or custom subject names.
  static String resolveSubjectId(String name) {
    return idForName(name) ?? _customIdForName(name);
  }

  static String _customIdForName(String name) {
    final slug = name
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '-')
        .replaceAll(RegExp(r'-+'), '-')
        .replaceAll(RegExp(r'^-|-$'), '');
    final body = slug.isEmpty ? 'CUSTOM' : slug.substring(0, slug.length.clamp(0, 24));
    return 'SUB-C-$body';
  }
}
