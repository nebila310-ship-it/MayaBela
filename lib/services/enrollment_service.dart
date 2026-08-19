import 'dart:async';

import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/enrollment_persistence_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/app_notification.dart';

class EnrollmentService {
  EnrollmentService._();
  static final instance = EnrollmentService._();

  int _nextLinkId = 3;
  final List<ParentLinkRequest> _parentLinks = [];

  void _seedDemoApprovals() {
    _parentLinks.addAll([
      ParentLinkRequest(
        id: 'PL-1',
        parentUsername: 'parent',
        parentFullName: 'Mr. Bekele',
        studentId: 'STU-1001',
        schoolId: 'TB-001',
        relationship: ParentRelationship.father,
        requestedAt: DateTime.now().subtract(const Duration(days: 30)),
        status: ParentLinkStatus.approved,
        reviewedBy: 'School Admin',
        reviewedAt: DateTime.now().subtract(const Duration(days: 29)),
      ),
      ParentLinkRequest(
        id: 'PL-2',
        parentUsername: 'parent',
        parentFullName: 'Mr. Bekele',
        studentId: 'STU-1002',
        schoolId: 'TB-001',
        relationship: ParentRelationship.father,
        requestedAt: DateTime.now().subtract(const Duration(days: 30)),
        status: ParentLinkStatus.approved,
        reviewedBy: 'School Admin',
        reviewedAt: DateTime.now().subtract(const Duration(days: 29)),
      ),
    ]);
  }

  bool _seeded = false;

  void ensureSeeded() {
    if (_seeded) return;
    _seeded = true;
    if (_parentLinks.isEmpty) {
      _seedDemoApprovals();
    }
  }

  List<ParentLinkRequest> allLinksSnapshot() =>
      List.unmodifiable(_parentLinks);

  int get nextLinkIdCounter => _nextLinkId;

  void replaceLinks(List<ParentLinkRequest> links, {int? nextId}) {
    _parentLinks
      ..clear()
      ..addAll(links);
    if (nextId != null) _nextLinkId = nextId;
    _seeded = true;
  }

  Future<void> _persist({String? syncLinkId}) async {
    await EnrollmentPersistenceService.instance.saveFromEnrollmentService(
      syncLinkId: syncLinkId,
    );
  }

  String? verifyAndCreateParentLink({
    required String schoolId,
    required String studentId,
    required DateTime dateOfBirth,
    required String parentUsername,
    required String parentFullName,
    required ParentRelationship relationship,
    bool hasMedicalCondition = false,
    String? medicalConditionDetails,
    String? otherMedicalInfo,
  }) {
    ensureSeeded();
    if (!StudentRegistryService.instance.verifyStudent(
      schoolId: schoolId,
      studentId: studentId,
      dateOfBirth: dateOfBirth,
    )) {
      return 'student_mismatch';
    }

    final sid = studentId.trim().toUpperCase();
    final existing = _parentLinks.where(
      (link) =>
          link.parentUsername == parentUsername.toLowerCase() &&
          link.studentId == sid &&
          link.status != ParentLinkStatus.rejected,
    );
    if (existing.isNotEmpty) {
      return 'already_linked';
    }

    _parentLinks.add(
      ParentLinkRequest(
        id: 'PL-${_nextLinkId++}',
        parentUsername: parentUsername.toLowerCase(),
        parentFullName: parentFullName,
        studentId: sid,
        schoolId: schoolId.trim().toUpperCase(),
        relationship: relationship,
        requestedAt: DateTime.now(),
        hasMedicalCondition: hasMedicalCondition,
        medicalConditionDetails: medicalConditionDetails?.trim().isEmpty == true
            ? null
            : medicalConditionDetails?.trim(),
        otherMedicalInfo: otherMedicalInfo?.trim().isEmpty == true
            ? null
            : otherMedicalInfo?.trim(),
      ),
    );

    unawaited(_persist());
    return null;
  }

  void _applyMedicalInfoToStudent({
    required String studentId,
    required bool hasMedicalCondition,
    String? medicalConditionDetails,
    String? otherMedicalInfo,
  }) {
    final student = StudentRegistryService.instance.lookupById(studentId);
    if (student == null) return;
    StudentRegistryService.instance.updateStudent(
      student.copyWith(
        hasMedicalCondition: hasMedicalCondition,
        medicalConditionDetails: hasMedicalCondition
            ? medicalConditionDetails?.trim()
            : null,
        otherMedicalInfo: otherMedicalInfo?.trim(),
      ),
    );
  }

  void _syncParentNameToStudent(ParentLinkRequest link) {
    final parentName = link.parentFullName.trim();
    if (parentName.isEmpty) return;

    final student = StudentRegistryService.instance.lookupById(link.studentId);
    if (student == null) return;

    final updated = switch (link.relationship) {
      ParentRelationship.father => student.copyWith(fatherName: parentName),
      ParentRelationship.mother => student.copyWith(motherName: parentName),
      ParentRelationship.guardian => student.copyWith(guardianName: parentName),
    };
    StudentRegistryService.instance.updateStudent(updated);
  }

  /// Logged-in parent links an additional child (same flow as signup child step).
  String? linkChildForCurrentParent(ParentChildRegistration child) {
    final user = AuthService.currentUser;
    if (user == null || user.roleKey != AuthService.roleParent) {
      return 'not_parent';
    }
    if (user.schoolId == null || user.schoolId!.trim().isEmpty) {
      return 'school_blocked';
    }
    return verifyAndCreateParentLink(
      schoolId: user.schoolId!,
      studentId: child.studentId,
      dateOfBirth: child.dateOfBirth,
      parentUsername: user.username,
      parentFullName: user.fullName ?? 'Parent',
      relationship: child.relationship,
      hasMedicalCondition: child.hasMedicalCondition,
      medicalConditionDetails: child.medicalConditionDetails,
      otherMedicalInfo: child.otherMedicalInfo,
    );
  }

  List<ParentLinkRequest> linksForParent(String username) {
    ensureSeeded();
    final lower = username.toLowerCase();
    return _parentLinks.where((l) => l.parentUsername == lower).toList();
  }

  List<String> approvedStudentIdsForParent(String username) {
    return linksForParent(username)
        .where((l) => l.status == ParentLinkStatus.approved)
        .map((l) => l.studentId)
        .toList();
  }

  bool hasApprovedAccess(String username) {
    return approvedStudentIdsForParent(username).isNotEmpty;
  }

  bool hasPendingOnly(String username) {
    final links = linksForParent(username);
    if (links.isEmpty) return false;
    return links.every((l) => l.status == ParentLinkStatus.pending);
  }

  List<ParentLinkRequest> pendingForSchool(String? schoolId) {
    ensureSeeded();
    if (schoolId == null) return [];
    final id = schoolId.toUpperCase();
    return _parentLinks
        .where(
          (l) => l.schoolId == id && l.status == ParentLinkStatus.pending,
        )
        .toList();
  }

  List<ParentLinkRequest> approvedForSchool(String? schoolId) {
    ensureSeeded();
    if (schoolId == null) return [];
    final id = schoolId.toUpperCase();
    return _parentLinks
        .where(
          (l) => l.schoolId == id && l.status == ParentLinkStatus.approved,
        )
        .toList();
  }

  List<ParentLinkRequest> pendingForHomeroomTeacher() {
    ensureSeeded();
    final homeroomClasses = TeacherAccessService.instance.homeroomClassNames;
    if (homeroomClasses.isEmpty) return [];

    return _parentLinks.where((link) {
      if (link.status != ParentLinkStatus.pending) return false;
      final student = StudentRegistryService.instance.lookupById(link.studentId);
      if (student == null) return false;
      return homeroomClasses.contains(student.className);
    }).toList();
  }

  List<ParentLinkRequest> pendingApprovalsForCurrentUser() {
    final user = AuthService.currentUser;
    if (user == null) return [];
    // Owner, Section Director, Student Affairs (and any manage_parent_links).
    if (user.roleKey == AuthService.roleAdmin ||
        AuthService.hasPermission(SchoolPermissions.manageParentLinks)) {
      final schoolId = AuthService.activeSchoolId ?? user.schoolId;
      return pendingForSchool(schoolId);
    }
    // Homeroom teachers: class-scoped only.
    if (user.roleKey == AuthService.roleTeacher) {
      return pendingForHomeroomTeacher();
    }
    return [];
  }

  List<ParentLinkRequest> allLinksForSchool(String? schoolId) {
    ensureSeeded();
    if (schoolId == null) return [];
    final id = schoolId.trim().toUpperCase();
    return _parentLinks.where((l) => l.schoolId.toUpperCase() == id).toList();
  }

  List<ParentLinkRequest> allLinksForHomeroomTeacher() {
    ensureSeeded();
    final homeroomClasses = TeacherAccessService.instance.homeroomClassNames;
    if (homeroomClasses.isEmpty) return [];

    return _parentLinks.where((link) {
      final student = StudentRegistryService.instance.lookupById(link.studentId);
      if (student == null) return false;
      return homeroomClasses.contains(student.className);
    }).toList();
  }

  /// Pending first, then approved, then rejected; newest first within each group.
  List<ParentLinkRequest> approvalQueueForCurrentUser() {
    final user = AuthService.currentUser;
    if (user == null) return [];

    final List<ParentLinkRequest> links;
    // School-wide for owner / SD / Student Affairs (manage_parent_links).
    if (user.roleKey == AuthService.roleAdmin ||
        AuthService.hasPermission(SchoolPermissions.manageParentLinks)) {
      links = allLinksForSchool(AuthService.activeSchoolId ?? user.schoolId);
    } else if (user.roleKey == AuthService.roleTeacher) {
      // Homeroom teachers: only their classes.
      links = allLinksForHomeroomTeacher();
    } else {
      return [];
    }

    links.sort((a, b) {
      final statusOrder = _statusSortKey(a.status).compareTo(_statusSortKey(b.status));
      if (statusOrder != 0) return statusOrder;
      return b.requestedAt.compareTo(a.requestedAt);
    });
    return links;
  }

  /// Parent's own links — pending first so outstanding requests stay visible.
  List<ParentLinkRequest> sortedLinksForParent(String username) {
    final links = linksForParent(username);
    links.sort((a, b) {
      final statusOrder = _statusSortKey(a.status).compareTo(_statusSortKey(b.status));
      if (statusOrder != 0) return statusOrder;
      return b.requestedAt.compareTo(a.requestedAt);
    });
    return links;
  }

  int _statusSortKey(ParentLinkStatus status) {
    return switch (status) {
      ParentLinkStatus.pending => 0,
      ParentLinkStatus.approved => 1,
      ParentLinkStatus.rejected => 2,
    };
  }

  int pendingCountForCurrentUser() => pendingApprovalsForCurrentUser().length;

  Future<void> approveLink(String linkId, String reviewerName) async {
    final link = _parentLinks.firstWhere((l) => l.id == linkId);
    link.status = ParentLinkStatus.approved;
    link.reviewedBy = reviewerName;
    link.reviewedAt = DateTime.now();
    _applyMedicalInfoToStudent(
      studentId: link.studentId,
      hasMedicalCondition: link.hasMedicalCondition,
      medicalConditionDetails: link.medicalConditionDetails,
      otherMedicalInfo: link.otherMedicalInfo,
    );
    _syncParentNameToStudent(link);
    await _syncParentUserLinks(link.parentUsername);
    SchoolDataService.instance.syncChildFromRegistry(link.studentId);
    unawaited(
      SchoolAuthCloudService.instance.refreshAccessClaims(
        username: link.parentUsername,
      ),
    );

    final student = StudentRegistryService.instance.lookupById(link.studentId);
    final s = AppLocale.instance.strings;
    NotificationService.instance.push(
      title: s.parentApprovalNotificationTitle,
      body: student != null
          ? s.parentApprovalNotificationBody(student.fullName, link.studentId)
          : s.parentApprovalNotificationBody(link.studentId, link.studentId),
      type: NotificationType.announcement,
      fromRole: AuthService.roleAdmin,
      fromName: reviewerName,
      recipientRole: AuthService.roleParent,
    );
    await _persist(syncLinkId: linkId);
  }

  Future<void> rejectLink(String linkId, String reviewerName) async {
    final link = _parentLinks.firstWhere((l) => l.id == linkId);
    link.status = ParentLinkStatus.rejected;
    link.reviewedBy = reviewerName;
    link.reviewedAt = DateTime.now();
    await _syncParentUserLinks(link.parentUsername);
    await _persist(syncLinkId: linkId);
  }

  Future<void> _syncParentUserLinks(String username) async {
    final approved = approvedStudentIdsForParent(username);
    AuthService.updateParentLinks(username, approved);
    if (SchoolDatabaseService.instance.isInitialized) {
      await SchoolDatabaseService.instance.syncParentEnrollmentForUser(username);
    }
  }

  ParentLinkRequest? findLink(String linkId) {
    ensureSeeded();
    try {
      return _parentLinks.firstWhere((l) => l.id == linkId);
    } catch (_) {
      return null;
    }
  }
}
