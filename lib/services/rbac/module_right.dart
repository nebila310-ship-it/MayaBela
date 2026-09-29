/// Per-module authority a school owner can grant to a staff role.
enum ModuleRight {
  /// Module is hidden; the role cannot open it.
  none,

  /// Module is visible but mutating actions stay disabled.
  read,

  /// Module is visible and the role may change data inside it.
  edit;

  bool get canView => this != ModuleRight.none;
  bool get canManage => this == ModuleRight.edit;

  static ModuleRight parse(Object? raw) {
    switch (raw?.toString().trim().toLowerCase()) {
      case 'read':
      case 'view':
        return ModuleRight.read;
      case 'edit':
      case 'manage':
      case 'write':
        return ModuleRight.edit;
      default:
        return ModuleRight.none;
    }
  }
}

/// Roll-up of child module rights for a sidebar section.
enum SectionRight {
  none,
  read,
  edit,
  partial;

  static SectionRight fromChildren(Iterable<ModuleRight> rights) {
    final unique = rights.toSet();
    if (unique.isEmpty) return SectionRight.none;
    if (unique.length > 1) return SectionRight.partial;
    switch (unique.single) {
      case ModuleRight.none:
        return SectionRight.none;
      case ModuleRight.read:
        return SectionRight.read;
      case ModuleRight.edit:
        return SectionRight.edit;
    }
  }
}
