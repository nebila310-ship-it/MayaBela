class SchoolOnboardingStep {
  const SchoolOnboardingStep({
    required this.key,
    required this.label,
    required this.done,
    this.parameter = '',
    this.phaseKey = '',
  });

  final String key;
  final String label;
  final bool done;

  /// How this item is measured (the scoring parameter).
  final String parameter;
  final String phaseKey;
}

class SchoolScorePhase {
  const SchoolScorePhase({
    required this.key,
    required this.title,
    required this.summary,
    required this.steps,
  });

  final String key;
  final String title;
  final String summary;
  final List<SchoolOnboardingStep> steps;

  int get completedCount => steps.where((s) => s.done).length;
  int get totalCount => steps.length;
  int get percent =>
      totalCount == 0 ? 0 : ((completedCount / totalCount) * 100).round();
}

class SchoolOnboardingChecklist {
  const SchoolOnboardingChecklist({
    required this.schoolId,
    required this.steps,
    this.phases = const [],
  });

  final String schoolId;
  final List<SchoolOnboardingStep> steps;
  final List<SchoolScorePhase> phases;

  int get completedCount => steps.where((s) => s.done).length;
  int get totalCount => steps.length;
  bool get isComplete => totalCount > 0 && completedCount == totalCount;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;

  /// 0–100 readiness score across create-school → go-live.
  int get scorePercent => (progress * 100).round();

  String get scoreBand {
    final score = scorePercent;
    if (score >= 85) return 'Ready';
    if (score >= 60) return 'Operating';
    if (score >= 30) return 'Building';
    return 'Starting';
  }
}
