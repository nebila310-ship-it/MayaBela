/// Canonical school-management database models.
///
/// All relationships use IDs — users never connect directly to each other.
/// See [RelationshipResolver] for how parent → teacher access is resolved.
library;

// —— users ——
class UserRecord {
  const UserRecord({
    required this.userId,
    required this.role,
    required this.fullName,
    this.phone,
    this.email,
    this.status = 'active',
    this.createdAt,
  });

  final String userId;
  final String role;
  final String fullName;
  final String? phone;
  final String? email;
  final String status;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'role': role,
        'fullName': fullName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
        'status': status,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  factory UserRecord.fromMap(Map<String, dynamic> map) => UserRecord(
        userId: map['userId'] as String,
        role: map['role'] as String,
        fullName: map['fullName'] as String,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
        status: map['status'] as String? ?? 'active',
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'] as String)
            : null,
      );
}

// —— classes ——
class ClassRecord {
  const ClassRecord({
    required this.classId,
    required this.gradeLevel,
    required this.section,
    required this.className,
    required this.academicYear,
    this.active = true,
  });

  final String classId;
  final String gradeLevel;
  final String section;
  final String className;
  final String academicYear;
  final bool active;

  Map<String, dynamic> toMap() => {
        'classId': classId,
        'gradeLevel': gradeLevel,
        'section': section,
        'className': className,
        'academicYear': academicYear,
        'active': active,
      };

  factory ClassRecord.fromMap(Map<String, dynamic> map) => ClassRecord(
        classId: map['classId'] as String,
        gradeLevel: map['gradeLevel'] as String,
        section: map['section'] as String,
        className: map['className'] as String,
        academicYear: map['academicYear'] as String,
        active: map['active'] as bool? ?? true,
      );
}

// —— students ——
class StudentRecord {
  const StudentRecord({
    required this.studentId,
    required this.firstName,
    required this.lastName,
    required this.classId,
    this.gender,
    this.birthDate,
    this.parentId,
    this.routeId,
    this.admissionNumber,
    this.status = 'active',
    this.hasMedicalCondition = false,
    this.medicalConditionDetails,
    this.otherMedicalInfo,
  });

  final String studentId;
  final String firstName;
  final String lastName;
  final String classId;
  final String? gender;
  final DateTime? birthDate;
  final String? parentId;
  final String? routeId;
  final String? admissionNumber;
  final String status;
  final bool hasMedicalCondition;
  final String? medicalConditionDetails;
  final String? otherMedicalInfo;

  String get fullName => '$firstName $lastName'.trim();

  Map<String, dynamic> toMap() => {
        'studentId': studentId,
        'firstName': firstName,
        'lastName': lastName,
        'classId': classId,
        if (gender != null) 'gender': gender,
        if (birthDate != null) 'birthDate': birthDate!.toIso8601String(),
        if (parentId != null) 'parentId': parentId,
        if (routeId != null) 'routeId': routeId,
        if (admissionNumber != null) 'admissionNumber': admissionNumber,
        'status': status,
        'hasMedicalCondition': hasMedicalCondition,
        if (medicalConditionDetails != null)
          'medicalConditionDetails': medicalConditionDetails,
        if (otherMedicalInfo != null) 'otherMedicalInfo': otherMedicalInfo,
      };

  factory StudentRecord.fromMap(Map<String, dynamic> map) => StudentRecord(
        studentId: map['studentId'] as String,
        firstName: map['firstName'] as String,
        lastName: map['lastName'] as String,
        classId: map['classId'] as String,
        gender: map['gender'] as String?,
        birthDate: map['birthDate'] != null
            ? DateTime.tryParse(map['birthDate'] as String)
            : null,
        parentId: map['parentId'] as String?,
        routeId: map['routeId'] as String?,
        admissionNumber: map['admissionNumber'] as String?,
        status: map['status'] as String? ?? 'active',
        hasMedicalCondition: map['hasMedicalCondition'] as bool? ?? false,
        medicalConditionDetails: map['medicalConditionDetails'] as String?,
        otherMedicalInfo: map['otherMedicalInfo'] as String?,
      );
}

// —— parents ——
class ParentRecord {
  const ParentRecord({
    required this.parentId,
    required this.userId,
    this.fatherName,
    this.motherName,
    this.phone,
    this.email,
  });

  final String parentId;
  final String userId;
  final String? fatherName;
  final String? motherName;
  final String? phone;
  final String? email;

  Map<String, dynamic> toMap() => {
        'parentId': parentId,
        'userId': userId,
        if (fatherName != null) 'fatherName': fatherName,
        if (motherName != null) 'motherName': motherName,
        if (phone != null) 'phone': phone,
        if (email != null) 'email': email,
      };

  factory ParentRecord.fromMap(Map<String, dynamic> map) => ParentRecord(
        parentId: map['parentId'] as String,
        userId: map['userId'] as String,
        fatherName: map['fatherName'] as String?,
        motherName: map['motherName'] as String?,
        phone: map['phone'] as String?,
        email: map['email'] as String?,
      );
}

// —— parent_student_links ——
class ParentStudentLink {
  const ParentStudentLink({
    required this.linkId,
    required this.parentId,
    required this.studentId,
  });

  final String linkId;
  final String parentId;
  final String studentId;

  Map<String, dynamic> toMap() => {
        'linkId': linkId,
        'parentId': parentId,
        'studentId': studentId,
      };

  factory ParentStudentLink.fromMap(Map<String, dynamic> map) =>
      ParentStudentLink(
        linkId: map['linkId'] as String,
        parentId: map['parentId'] as String,
        studentId: map['studentId'] as String,
      );
}

// —— teachers ——
class TeacherRecord {
  const TeacherRecord({
    required this.teacherId,
    required this.userId,
    this.employeeNumber,
    this.specialization,
    this.status = 'active',
  });

  final String teacherId;
  final String userId;
  final String? employeeNumber;
  final String? specialization;
  final String status;

  Map<String, dynamic> toMap() => {
        'teacherId': teacherId,
        'userId': userId,
        if (employeeNumber != null) 'employeeNumber': employeeNumber,
        if (specialization != null) 'specialization': specialization,
        'status': status,
      };

  factory TeacherRecord.fromMap(Map<String, dynamic> map) => TeacherRecord(
        teacherId: map['teacherId'] as String,
        userId: map['userId'] as String,
        employeeNumber: map['employeeNumber'] as String?,
        specialization: map['specialization'] as String?,
        status: map['status'] as String? ?? 'active',
      );
}

// —— teacher_assignments ——
class TeacherAssignment {
  const TeacherAssignment({
    required this.assignmentId,
    required this.teacherId,
    required this.classId,
    required this.subjectName,
  });

  final String assignmentId;
  final String teacherId;
  final String classId;
  final String subjectName;

  Map<String, dynamic> toMap() => {
        'assignmentId': assignmentId,
        'teacherId': teacherId,
        'classId': classId,
        'subjectName': subjectName,
      };

  factory TeacherAssignment.fromMap(Map<String, dynamic> map) =>
      TeacherAssignment(
        assignmentId: map['assignmentId'] as String,
        teacherId: map['teacherId'] as String,
        classId: map['classId'] as String,
        subjectName: map['subjectName'] as String,
      );
}

// —— drivers ——
class DriverRecord {
  const DriverRecord({
    required this.driverId,
    required this.userId,
    this.licenseNumber,
    this.phone,
    this.status = 'active',
  });

  final String driverId;
  final String userId;
  final String? licenseNumber;
  final String? phone;
  final String status;

  Map<String, dynamic> toMap() => {
        'driverId': driverId,
        'userId': userId,
        if (licenseNumber != null) 'licenseNumber': licenseNumber,
        if (phone != null) 'phone': phone,
        'status': status,
      };

  factory DriverRecord.fromMap(Map<String, dynamic> map) => DriverRecord(
        driverId: map['driverId'] as String,
        userId: map['userId'] as String,
        licenseNumber: map['licenseNumber'] as String?,
        phone: map['phone'] as String?,
        status: map['status'] as String? ?? 'active',
      );
}

// —— routes ——
class RouteRecord {
  const RouteRecord({
    required this.routeId,
    required this.routeName,
    required this.busNumber,
    required this.driverId,
  });

  final String routeId;
  final String routeName;
  final String busNumber;
  final String driverId;

  Map<String, dynamic> toMap() => {
        'routeId': routeId,
        'routeName': routeName,
        'busNumber': busNumber,
        'driverId': driverId,
      };

  factory RouteRecord.fromMap(Map<String, dynamic> map) => RouteRecord(
        routeId: map['routeId'] as String,
        routeName: map['routeName'] as String,
        busNumber: map['busNumber'] as String,
        driverId: map['driverId'] as String,
      );
}

// —— transport_assignments ——
class TransportAssignment {
  const TransportAssignment({
    required this.assignmentId,
    required this.studentId,
    required this.routeId,
    this.pickupLocation,
  });

  final String assignmentId;
  final String studentId;
  final String routeId;
  final String? pickupLocation;

  Map<String, dynamic> toMap() => {
        'assignmentId': assignmentId,
        'studentId': studentId,
        'routeId': routeId,
        if (pickupLocation != null) 'pickupLocation': pickupLocation,
      };

  factory TransportAssignment.fromMap(Map<String, dynamic> map) =>
      TransportAssignment(
        assignmentId: map['assignmentId'] as String,
        studentId: map['studentId'] as String,
        routeId: map['routeId'] as String,
        pickupLocation: map['pickupLocation'] as String?,
      );
}

// —— attendance ——
class AttendanceRecord {
  const AttendanceRecord({
    required this.attendanceId,
    required this.studentId,
    required this.classId,
    required this.date,
    required this.status,
    required this.recordedByTeacherId,
  });

  final String attendanceId;
  final String studentId;
  final String classId;
  final DateTime date;
  final String status;
  final String recordedByTeacherId;

  Map<String, dynamic> toMap() => {
        'attendanceId': attendanceId,
        'studentId': studentId,
        'classId': classId,
        'date': date.toIso8601String(),
        'status': status,
        'recordedByTeacherId': recordedByTeacherId,
      };

  factory AttendanceRecord.fromMap(Map<String, dynamic> map) =>
      AttendanceRecord(
        attendanceId: map['attendanceId'] as String,
        studentId: map['studentId'] as String,
        classId: map['classId'] as String,
        date: DateTime.parse(map['date'] as String),
        status: map['status'] as String,
        recordedByTeacherId: map['recordedByTeacherId'] as String,
      );
}

// —— grades ——
class GradeRecord {
  const GradeRecord({
    required this.gradeId,
    required this.studentId,
    required this.classId,
    required this.subjectName,
    required this.score,
    required this.teacherId,
    required this.term,
  });

  final String gradeId;
  final String studentId;
  final String classId;
  final String subjectName;
  final double score;
  final String teacherId;
  final String term;

  Map<String, dynamic> toMap() => {
        'gradeId': gradeId,
        'studentId': studentId,
        'classId': classId,
        'subjectName': subjectName,
        'score': score,
        'teacherId': teacherId,
        'term': term,
      };

  factory GradeRecord.fromMap(Map<String, dynamic> map) => GradeRecord(
        gradeId: map['gradeId'] as String,
        studentId: map['studentId'] as String,
        classId: map['classId'] as String,
        subjectName: map['subjectName'] as String,
        score: (map['score'] as num).toDouble(),
        teacherId: map['teacherId'] as String,
        term: map['term'] as String,
      );
}

// —— announcements ——
class AnnouncementAudience {
  AnnouncementAudience._();

  static const all = 'all';
  static const teachers = 'teachers';
  static const parents = 'parents';
  static const drivers = 'drivers';
  static const classAudience = 'class';
}

class AnnouncementRecord {
  const AnnouncementRecord({
    required this.announcementId,
    required this.title,
    required this.message,
    required this.targetAudience,
    required this.createdBy,
    this.targetClassId,
    this.createdAt,
  });

  final String announcementId;
  final String title;
  final String message;
  final String targetAudience;
  final String createdBy;
  final String? targetClassId;
  final DateTime? createdAt;

  Map<String, dynamic> toMap() => {
        'announcementId': announcementId,
        'title': title,
        'message': message,
        'targetAudience': targetAudience,
        'createdBy': createdBy,
        if (targetClassId != null) 'targetClassId': targetClassId,
        if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
      };

  factory AnnouncementRecord.fromMap(Map<String, dynamic> map) =>
      AnnouncementRecord(
        announcementId: map['announcementId'] as String,
        title: map['title'] as String,
        message: map['message'] as String,
        targetAudience: map['targetAudience'] as String,
        createdBy: map['createdBy'] as String,
        targetClassId: map['targetClassId'] as String?,
        createdAt: map['createdAt'] != null
            ? DateTime.tryParse(map['createdAt'] as String)
            : null,
      );
}
