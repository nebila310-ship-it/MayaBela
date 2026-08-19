import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/school_class.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_account_service.dart';

/// Live student profile fields for the portal profile screen.
class StudentPortalProfile {
  const StudentPortalProfile({
    required this.fullName,
    required this.studentId,
    required this.schoolId,
    required this.schoolName,
    required this.grade,
    required this.className,
    required this.section,
    required this.rollNumber,
    this.schoolLogoPath,
    this.schoolLogoUrl,
    this.photoPath,
    this.gender,
    this.dateOfBirth,
    this.portalUsername,
    this.portalStatus,
    this.homeroomTeacher,
    this.attendanceRate,
  });

  final String fullName;
  final String studentId;
  final String schoolId;
  final String schoolName;
  final String grade;
  final String className;
  final String section;
  final String rollNumber;
  final String? schoolLogoPath;
  final String? schoolLogoUrl;
  final String? photoPath;
  final String? gender;
  final DateTime? dateOfBirth;
  final String? portalUsername;
  final String? portalStatus;
  final String? homeroomTeacher;
  final double? attendanceRate;

  bool get hasSchoolLogo {
    if (schoolLogoUrl != null && schoolLogoUrl!.trim().isNotEmpty) return true;
    if (kIsWeb) return false;
    return schoolLogoPath != null &&
        schoolLogoPath!.trim().isNotEmpty &&
        File(schoolLogoPath!).existsSync();
  }

  bool get hasPhoto {
    if (kIsWeb) return false;
    return photoPath != null &&
        photoPath!.trim().isNotEmpty &&
        File(photoPath!).existsSync();
  }
}

abstract final class StudentProfileService {
  static StudentPortalProfile? profileForCurrentUser() {
    final user = AuthService.currentUser;
    if (user?.roleKey != AuthService.roleStudent) return null;

    final record = StudentAccountService.instance.recordForCurrentUser();
    if (record == null) return null;

    final school = SchoolRegistryService.instance.lookup(record.schoolId);
    final schoolName = AppLocale.instance.strings.schoolName(record.schoolId);
    final child = SchoolDataService.instance.getChildById(record.studentId);
    final section = child?.displaySection.isNotEmpty == true
        ? child!.displaySection
        : ChildProfile.sectionFromClassName(record.className);

    return StudentPortalProfile(
      fullName: record.fullName,
      studentId: record.studentId,
      schoolId: record.schoolId,
      schoolName: schoolName,
      grade: record.grade,
      className: record.className,
      section: section,
      rollNumber: rollNumberFor(record.studentId),
      schoolLogoPath: school?.logoPath,
      schoolLogoUrl: school?.logoUrl,
      photoPath: record.photoPath,
      gender: record.gender,
      dateOfBirth: record.dateOfBirth,
      portalUsername: record.loginUsername,
      portalStatus: record.portalAccountStatus.name,
      homeroomTeacher: child?.teacher,
      attendanceRate: child?.attendanceRate,
    );
  }

  static String rollNumberFor(String studentId) {
    final digits = studentId.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 3) return digits.substring(digits.length - 3);
    return studentId.trim().toUpperCase();
  }
}
