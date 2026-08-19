import 'package:mayabela/services/admin_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Billable headcount and staff snapshot for platform owner (students = billing unit).
class SchoolEnrollmentMetrics {
  const SchoolEnrollmentMetrics({
    required this.schoolId,
    required this.schoolName,
    required this.billableStudents,
    required this.inactiveStudents,
    required this.teachers,
    required this.admins,
    required this.drivers,
    required this.gradeBreakdown,
    this.contractedSeats,
    this.ratePerStudentMonthEtb = defaultEtbPerStudentMonth,
    this.minimumMonthlyEtb = defaultMinimumMonthlyEtb,
  });

  final String schoolId;
  final String schoolName;
  final int billableStudents;
  final int inactiveStudents;
  final int teachers;
  final int admins;
  final int drivers;
  final Map<String, int> gradeBreakdown;
  final int? contractedSeats;
  final int ratePerStudentMonthEtb;
  final int minimumMonthlyEtb;

  int get totalStaff => teachers + admins + drivers;

  bool get hasSeatOverage =>
      contractedSeats != null && billableStudents > contractedSeats!;

  int get seatOverage =>
      hasSeatOverage ? billableStudents - contractedSeats! : 0;

  static const int defaultEtbPerStudentMonth = 8;
  static const int defaultMinimumMonthlyEtb = 500;

  int get estimatedMonthlyBillEtb {
    if (billableStudents == 0) return 0;
    final raw = billableStudents * ratePerStudentMonthEtb;
    return raw < minimumMonthlyEtb ? minimumMonthlyEtb : raw;
  }

  String get billingTierLabel {
    final n = billableStudents;
    if (n == 0) return 'No enrolled students';
    if (n <= 50) return 'Starter (1–50 students)';
    if (n <= 200) return 'Growth (51–200 students)';
    if (n <= 500) return 'Standard (201–500 students)';
    if (n <= 1000) return 'Large (501–1,000 students)';
    return 'Enterprise (1,000+ students)';
  }
}

class SchoolEnrollmentMetricsService {
  SchoolEnrollmentMetricsService._();
  static final instance = SchoolEnrollmentMetricsService._();

  final _students = StudentRegistryService.instance;
  final _teachers = TeacherRegistryService.instance;
  final _admins = AdminRegistryService.instance;
  final _drivers = DriverRegistryService.instance;
  final _schools = SchoolRegistryService.instance;

  SchoolEnrollmentMetrics forSchool(String schoolId) {
    final id = schoolId.trim().toUpperCase();
    final school = _schools.lookup(id);
    final active = _students.studentsForSchool(id);
    final inactive = _students.inactiveStudentsForSchool(id);

    final gradeBreakdown = <String, int>{};
    for (final s in active) {
      gradeBreakdown[s.grade] = (gradeBreakdown[s.grade] ?? 0) + 1;
    }

    return SchoolEnrollmentMetrics(
      schoolId: id,
      schoolName: school?.name ?? id,
      billableStudents: active.length,
      inactiveStudents: inactive.length,
      teachers: _teachers.teachersForSchool(id).length,
      admins: _adminsForSchool(id),
      drivers: _driversForSchool(id),
      gradeBreakdown: gradeBreakdown,
      contractedSeats: school?.contractedSeats,
      ratePerStudentMonthEtb:
          school?.ratePerStudentMonthEtb ?? SchoolEnrollmentMetrics.defaultEtbPerStudentMonth,
      minimumMonthlyEtb:
          school?.minimumMonthlyEtb ?? SchoolEnrollmentMetrics.defaultMinimumMonthlyEtb,
    );
  }

  int _adminsForSchool(String schoolId) {
    return _admins
        .getAllAdmins()
        .where((a) => a.schoolId.toUpperCase() == schoolId)
        .length;
  }

  int _driversForSchool(String schoolId) {
    return _drivers
        .getAllDrivers()
        .where((d) => d.schoolId.toUpperCase() == schoolId)
        .length;
  }

  /// Sum of billable students across all registered schools.
  int platformBillableStudentTotal() {
    var total = 0;
    for (final school in _schools.getAllSchools()) {
      total += _students.studentsForSchool(school.id).length;
    }
    return total;
  }

  int estimatedPlatformMonthlyRevenueEtb() {
    var total = 0;
    for (final school in _schools.getAllSchools()) {
      total += forSchool(school.id).estimatedMonthlyBillEtb;
    }
    return total;
  }

  static String formatCount(int n) {
    if (n < 1000) return '$n';
    final s = n.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(',');
      buf.write(s[i]);
    }
    return buf.toString();
  }
}
