class SchoolOnboardingStep {
  const SchoolOnboardingStep({
    required this.key,
    required this.label,
    required this.done,
  });

  final String key;
  final String label;
  final bool done;
}

class SchoolOnboardingChecklist {
  const SchoolOnboardingChecklist({
    required this.schoolId,
    required this.steps,
  });

  final String schoolId;
  final List<SchoolOnboardingStep> steps;

  int get completedCount => steps.where((s) => s.done).length;
  int get totalCount => steps.length;
  bool get isComplete => completedCount == totalCount;
  double get progress => totalCount == 0 ? 0 : completedCount / totalCount;
}
