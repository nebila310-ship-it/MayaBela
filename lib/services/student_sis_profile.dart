import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/models/student_conduct.dart';
import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';

/// Read-only SIS view assembled from the existing student, grade, care,
/// discipline, club, and transfer stores. Does not persist anything new.
class StudentSisSnapshot {
  const StudentSisSnapshot({
    required this.student,
    required this.academicHistory,
    required this.disciplineCases,
    required this.healthRecords,
    required this.documents,
    required this.clubNames,
    required this.movements,
    this.gojoHours = 0,
    this.conduct,
  });

  final AdminStudentRecord student;
  final List<StudentGradeReport> academicHistory;
  final StudentConductRating? conduct;
  final List<DisciplineCase> disciplineCases;
  final List<HealthRecord> healthRecords;
  final List<StudentDocument> documents;
  final List<String> clubNames;
  final int gojoHours;
  final List<TransferRequest> movements;

  String get groupingSummary {
    final parts = <String>[
      student.className,
      if ((student.house ?? '').trim().isNotEmpty) 'House ${student.house}',
      ...clubNames,
      if (gojoHours > 0) '$gojoHours Gojo hours',
    ];
    return parts.join(' · ');
  }
}

class StudentSisProfile {
  StudentSisProfile._();

  static StudentSisSnapshot? load(String studentId) {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return null;

    final id = student.studentId;
    return StudentSisSnapshot(
      student: student,
      academicHistory:
          SchoolDataService.instance.gradeReportsForStudent(id),
      conduct: SchoolDataService.instance.getStudentConduct(
        className: student.className,
        studentId: id,
      ),
      disciplineCases: DisciplineService.instance.forStudentIds([id]),
      healthRecords: StudentSupportService.instance.healthForStudent(id),
      documents: StudentSupportService.instance.documentsForStudent(id),
      clubNames: DosaService.instance.clubNamesForStudent(id),
      gojoHours: DosaService.instance.gojoHoursForStudent(id),
      movements: TransferWorkflowService.instance.requestsForStudent(id),
    );
  }
}
