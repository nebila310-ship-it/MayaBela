class AdminStaffRecord {
  AdminStaffRecord({
    required this.adminId,
    required this.fullName,
    required this.position,
    required this.department,
    required this.schoolId,
    this.email,
    this.phone,
  });

  final String adminId;
  final String fullName;
  final String position;
  final String department;
  final String schoolId;
  final String? email;
  final String? phone;
}

/// Admins registered by super-admin — replace with API fetch later.
class AdminRegistryService {
  AdminRegistryService._();
  static final instance = AdminRegistryService._();

  final List<AdminStaffRecord> _admins = [
    AdminStaffRecord(
      adminId: 'ADM-1001',
      fullName: 'School Admin',
      position: 'Principal',
      department: 'Administration',
      schoolId: 'TB-001',
      email: 'admin@mayaschool.et',
      phone: '0911000003',
    ),
    AdminStaffRecord(
      adminId: 'ADM-1002',
      fullName: 'Mrs. Selam',
      position: 'Vice Principal',
      department: 'Administration',
      schoolId: 'TB-001',
      email: 'selam@mayaschool.et',
      phone: '0911556677',
    ),
    AdminStaffRecord(
      adminId: 'ADM-1003',
      fullName: 'Mr. Getachew',
      position: 'Finance Officer',
      department: 'Finance',
      schoolId: 'TB-001',
      email: 'getachew@mayaschool.et',
    ),
  ];

  List<AdminStaffRecord> getAllAdmins() => List.unmodifiable(_admins);

  AdminStaffRecord? lookupById(String adminId) {
    final id = adminId.trim().toUpperCase();
    try {
      return _admins.firstWhere((a) => a.adminId == id);
    } catch (_) {
      return null;
    }
  }
}
