import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

/// School admin contact shown to parents, teachers, and drivers for help.
class SchoolSupportContact {
  const SchoolSupportContact({
    required this.schoolName,
    this.adminName,
    this.phone,
    this.email,
  });

  final String schoolName;
  final String? adminName;
  final String? phone;
  final String? email;

  bool get hasPhone => phone != null && phone!.trim().isNotEmpty;
  bool get hasEmail => email != null && email!.trim().isNotEmpty;
  bool get hasAnyContact => hasPhone || hasEmail;
}

class SchoolSupportContactService {
  SchoolSupportContactService._();
  static final instance = SchoolSupportContactService._();

  SchoolSupportContact? forSchoolId(String? schoolId) {
    if (schoolId == null || schoolId.trim().isEmpty) return null;
    final school = SchoolRegistryService.instance.lookup(schoolId.trim());
    if (school == null) return null;

    final creds = SchoolAdminCredentialsService.instance;
    final admin = AuthService.adminUserForSchool(school.id);

    return SchoolSupportContact(
      schoolName: school.name,
      adminName: creds.adminNameForSchool(school),
      phone: creds.adminPhoneForSchool(school),
      email: admin?.email?.trim().isNotEmpty == true ? admin!.email!.trim() : null,
    );
  }

  SchoolSupportContact? forActiveSchool() =>
      forSchoolId(AuthService.activeSchoolId);

  bool get showSchoolAdminSupport {
    final role = AuthService.currentUser?.roleKey;
    return role == AuthService.roleParent ||
        role == AuthService.roleTeacher ||
        role == AuthService.roleDriver ||
        role == AuthService.roleAdmin;
  }
}
