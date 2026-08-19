import 'package:mayabela/models/school_onboarding_checklist.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

class SchoolOnboardingService {
  SchoolOnboardingService._();
  static final instance = SchoolOnboardingService._();

  SchoolOnboardingChecklist forSchool(SchoolRecord school) {
    EnrollmentService.instance.ensureSeeded();
    final creds = SchoolAdminCredentialsService.instance;
    final hasLogo =
        (school.logoPath?.isNotEmpty == true) || (school.logoUrl?.isNotEmpty == true);
    final hasAdminPhone = creds.adminPhoneForSchool(school)?.trim().isNotEmpty == true;
    final hasPassword = creds.schoolHasPassword(school);
    final studentCount =
        StudentRegistryService.instance.studentsForSchool(school.id).length;
    final parentCount = EnrollmentService.instance
        .approvedForSchool(school.id)
        .length;

    return SchoolOnboardingChecklist(
      schoolId: school.id,
      steps: [
        SchoolOnboardingStep(
          key: 'logo',
          label: 'School logo uploaded',
          done: hasLogo,
        ),
        SchoolOnboardingStep(
          key: 'admin',
          label: 'Admin credentials saved',
          done: hasAdminPhone && hasPassword,
        ),
        SchoolOnboardingStep(
          key: 'students',
          label: 'First student enrolled',
          done: studentCount > 0,
        ),
        SchoolOnboardingStep(
          key: 'parents',
          label: 'First parent linked',
          done: parentCount > 0,
        ),
        SchoolOnboardingStep(
          key: 'live',
          label: 'School is active',
          done: school.isAccessible,
        ),
      ],
    );
  }
}
