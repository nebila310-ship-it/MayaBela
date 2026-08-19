enum SchoolLifecycleStatus {
  active,
  inactive,
  suspended;

  static SchoolLifecycleStatus parse(String? value) {
    return SchoolLifecycleStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => SchoolLifecycleStatus.active,
    );
  }
}

/// Why a school cannot sign in right now (null = OK).
enum SchoolAccessBlock {
  notFound,
  inactive,
  suspended,
  expired;
}
