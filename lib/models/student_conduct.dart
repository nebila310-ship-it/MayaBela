enum StudentConductRating {
  excellent,
  satisfactory,
  needsAttention,
}

extension StudentConductRatingX on StudentConductRating {
  String storageKey() {
    switch (this) {
      case StudentConductRating.excellent:
        return 'excellent';
      case StudentConductRating.satisfactory:
        return 'satisfactory';
      case StudentConductRating.needsAttention:
        return 'needs_attention';
    }
  }

  static StudentConductRating? fromStorageKey(String? key) {
    switch (key) {
      case 'excellent':
        return StudentConductRating.excellent;
      case 'satisfactory':
        return StudentConductRating.satisfactory;
      case 'needs_attention':
        return StudentConductRating.needsAttention;
      default:
        return null;
    }
  }
}
