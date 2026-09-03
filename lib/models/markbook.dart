/// Weighted markbook categories, assessment marks, and term-report math.
///
/// Existing [SubjectGrade.score] remains the subject final (legacy single
/// mark or computed from [AssessmentMark]s). Approval, parent visibility,
/// and cloud sync are unchanged.
class AssessmentCategory {
  const AssessmentCategory({
    required this.id,
    required this.label,
    required this.weightPercent,
  });

  final String id;
  final String label;
  final double weightPercent;

  AssessmentCategory copyWith({
    String? id,
    String? label,
    double? weightPercent,
  }) {
    return AssessmentCategory(
      id: id ?? this.id,
      label: label ?? this.label,
      weightPercent: weightPercent ?? this.weightPercent,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'label': label,
        'weightPercent': weightPercent,
      };

  factory AssessmentCategory.fromMap(Map<String, dynamic> map) {
    return AssessmentCategory(
      id: (map['id'] as String? ?? '').trim(),
      label: (map['label'] as String? ?? '').trim(),
      weightPercent: (map['weightPercent'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AssessmentMark {
  AssessmentMark({
    required this.categoryId,
    required this.label,
    required this.weightPercent,
    this.score,
    this.maxScore = 100,
    this.enteredAt,
  });

  final String categoryId;
  String label;
  double weightPercent;
  double? score;
  double maxScore;
  DateTime? enteredAt;

  bool get isEntered => score != null;

  double get percentage {
    if (score == null || maxScore == 0) return 0;
    return (score! / maxScore) * 100;
  }

  AssessmentMark copy() {
    return AssessmentMark(
      categoryId: categoryId,
      label: label,
      weightPercent: weightPercent,
      score: score,
      maxScore: maxScore,
      enteredAt: enteredAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'categoryId': categoryId,
        'label': label,
        'weightPercent': weightPercent,
        if (score != null) 'score': score,
        'maxScore': maxScore,
        if (enteredAt != null) 'enteredAt': enteredAt!.toIso8601String(),
      };

  factory AssessmentMark.fromMap(Map<String, dynamic> map) {
    return AssessmentMark(
      categoryId: map['categoryId'] as String? ?? '',
      label: map['label'] as String? ?? '',
      weightPercent: (map['weightPercent'] as num?)?.toDouble() ?? 0,
      score: (map['score'] as num?)?.toDouble(),
      maxScore: (map['maxScore'] as num?)?.toDouble() ?? 100,
      enteredAt: map['enteredAt'] != null
          ? DateTime.tryParse(map['enteredAt'] as String)
          : null,
    );
  }
}

class MarkbookSettings {
  const MarkbookSettings({
    this.categories = const [],
    this.missingCountsAsZero = false,
    this.defaultTerm = 'Term 1',
  });

  /// School-wide assessment categories. Weights should sum to 100.
  final List<AssessmentCategory> categories;

  /// When true, a missing category counts as 0. When false, remaining
  /// weights are renormalized so the live standing is among entered marks.
  final bool missingCountsAsZero;

  final String defaultTerm;

  static const liaDefaults = MarkbookSettings(
    categories: [
      AssessmentCategory(id: 'homework', label: 'Homework', weightPercent: 10),
      AssessmentCategory(id: 'quiz', label: 'Quizzes', weightPercent: 15),
      AssessmentCategory(id: 'classwork', label: 'Classwork', weightPercent: 15),
      AssessmentCategory(id: 'midterm', label: 'Midterm', weightPercent: 25),
      AssessmentCategory(id: 'final', label: 'Final exam', weightPercent: 35),
    ],
  );

  bool get isEnabled => categories.isNotEmpty;

  double get weightTotal =>
      categories.fold(0, (sum, c) => sum + c.weightPercent);

  bool get weightsValid => (weightTotal - 100).abs() < 0.05;

  String? get weightError {
    if (categories.isEmpty) return null;
    if (weightsValid) return null;
    return 'Category weights must add up to 100% (currently ${weightTotal.toStringAsFixed(1)}%).';
  }

  MarkbookSettings copyWith({
    List<AssessmentCategory>? categories,
    bool? missingCountsAsZero,
    String? defaultTerm,
  }) {
    return MarkbookSettings(
      categories: categories ?? this.categories,
      missingCountsAsZero: missingCountsAsZero ?? this.missingCountsAsZero,
      defaultTerm: defaultTerm ?? this.defaultTerm,
    );
  }

  Map<String, dynamic> toMap() => {
        'categories': categories.map((c) => c.toMap()).toList(),
        'missingCountsAsZero': missingCountsAsZero,
        'defaultTerm': defaultTerm,
      };

  factory MarkbookSettings.fromMap(Map<String, dynamic>? map) {
    if (map == null || map.isEmpty) return MarkbookSettings.liaDefaults;
    final raw = map['categories'] as List?;
    final cats = raw == null
        ? MarkbookSettings.liaDefaults.categories
        : raw
            .whereType<Map>()
            .map((e) => AssessmentCategory.fromMap(Map<String, dynamic>.from(e)))
            .where((c) => c.id.isNotEmpty)
            .toList();
    return MarkbookSettings(
      categories: cats,
      missingCountsAsZero: map['missingCountsAsZero'] as bool? ?? false,
      defaultTerm: (map['defaultTerm'] as String?)?.trim().isNotEmpty == true
          ? (map['defaultTerm'] as String).trim()
          : 'Term 1',
    );
  }
}

class StudentAttendanceSnapshot {
  const StudentAttendanceSnapshot({
    this.present = 0,
    this.late = 0,
    this.absent = 0,
  });

  final int present;
  final int late;
  final int absent;

  int get sessions => present + late + absent;

  double get rate => sessions == 0 ? 0 : present / sessions;

  Map<String, dynamic> toMap() => {
        'present': present,
        'late': late,
        'absent': absent,
      };

  factory StudentAttendanceSnapshot.fromCounts({
    int? present,
    int? late,
    int? absent,
  }) {
    return StudentAttendanceSnapshot(
      present: present ?? 0,
      late: late ?? 0,
      absent: absent ?? 0,
    );
  }
}

/// Pure markbook math — no Flutter / service dependencies.
abstract final class MarkbookMath {
  /// Weighted percentage 0–100. Missing marks are either 0 or dropped
  /// (remaining weights renormalized) depending on [missingCountsAsZero].
  static double weightedPercentage(
    List<AssessmentMark> marks, {
    bool missingCountsAsZero = false,
  }) {
    if (marks.isEmpty) return 0;
    var weighted = 0.0;
    var usedWeight = 0.0;
    for (final mark in marks) {
      final weight = mark.weightPercent;
      if (weight <= 0) continue;
      if (mark.score == null) {
        if (!missingCountsAsZero) continue;
        usedWeight += weight;
        continue;
      }
      usedWeight += weight;
      weighted += mark.percentage * weight;
    }
    if (usedWeight <= 0) return 0;
    return weighted / usedWeight;
  }

  static bool isComplete(List<AssessmentMark> marks) {
    if (marks.isEmpty) return false;
    return marks.every((m) => m.isEntered);
  }

  static double gpaPoints(String letter) {
    return switch (letter) {
      'A' => 4.0,
      'B' => 3.0,
      'C' => 2.0,
      'D' => 1.0,
      _ => 0.0,
    };
  }

  static String letterFromPercentage(double percentage) {
    if (percentage >= 90) return 'A';
    if (percentage >= 80) return 'B';
    if (percentage >= 70) return 'C';
    if (percentage >= 60) return 'D';
    return 'F';
  }
}
