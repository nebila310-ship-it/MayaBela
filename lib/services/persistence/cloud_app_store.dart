import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/cloud/cloud_sync_flags.dart';
import 'package:mayabela/services/cloud/sync_cursor_store.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/class_timetable.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/models/cloud/app_data_maps.dart';
import 'package:mayabela/models/cloud/conversation_document.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/models/platform_audit_entry.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/models/procurement_models.dart';
import 'package:mayabela/models/bus_record.dart';
import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/models/leave_request.dart';
import 'package:mayabela/models/admission_application.dart';
import 'package:mayabela/models/exam_models.dart';
import 'package:mayabela/models/lesson_plan_models.dart';
import 'package:mayabela/models/curriculum_models.dart';
import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/models/dosa_models.dart';
import 'package:mayabela/models/qa_monitor_models.dart';
import 'package:mayabela/models/golive_models.dart';
import 'package:mayabela/models/digital_ops_models.dart';
import 'package:mayabela/models/qa_finding.dart';
import 'package:mayabela/models/school_audit_entry.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';
import 'package:mayabela/services/cloud/school_account_ids.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/cloud_sync_progress_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/persistence/auth_persistence_service.dart';
import 'package:mayabela/services/persistence/driver_persistence_service.dart';
import 'package:mayabela/services/persistence/employee_persistence_service.dart';
import 'package:mayabela/services/employee_registry_service.dart';
import 'package:mayabela/services/persistence/enrollment_persistence_service.dart';
import 'package:mayabela/services/persistence/grade_persistence_service.dart';
import 'package:mayabela/services/grade_audit_service.dart';
import 'package:mayabela/services/persistence/grade_audit_persistence_service.dart';
import 'package:mayabela/services/persistence/homework_persistence_service.dart';
import 'package:mayabela/services/persistence/inventory_persistence_service.dart';
import 'package:mayabela/services/persistence/procurement_persistence_service.dart';
import 'package:mayabela/services/persistence/transfer_persistence_service.dart';
import 'package:mayabela/services/persistence/discipline_persistence_service.dart';
import 'package:mayabela/services/persistence/leave_request_persistence_service.dart';
import 'package:mayabela/services/persistence/admission_persistence_service.dart';
import 'package:mayabela/services/persistence/qa_findings_persistence_service.dart';
import 'package:mayabela/services/persistence/bus_persistence_service.dart';
import 'package:mayabela/services/persistence/school_audit_persistence_service.dart';
import 'package:mayabela/services/procurement_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/leave_request_service.dart';
import 'package:mayabela/services/admission_service.dart';
import 'package:mayabela/services/exam_service.dart';
import 'package:mayabela/services/persistence/exam_persistence_service.dart';
import 'package:mayabela/services/lesson_plan_service.dart';
import 'package:mayabela/services/persistence/lesson_plan_persistence_service.dart';
import 'package:mayabela/services/curriculum_service.dart';
import 'package:mayabela/services/persistence/curriculum_persistence_service.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/services/persistence/student_support_persistence_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/persistence/dosa_persistence_service.dart';
import 'package:mayabela/services/persistence/qa_monitor_persistence_service.dart';
import 'package:mayabela/services/persistence/golive_persistence_service.dart';
import 'package:mayabela/services/persistence/digital_ops_persistence_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/digital_ops_service.dart';
import 'package:mayabela/services/qa_findings_service.dart';
import 'package:mayabela/services/transfer_workflow_service.dart';
import 'package:mayabela/services/bus_registry_service.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/services/material_purchase_service.dart';
import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/models/material_purchase_models.dart';
import 'package:mayabela/services/persistence/learning_materials_persistence_service.dart';
import 'package:mayabela/services/persistence/material_purchase_persistence_service.dart';
import 'package:mayabela/services/persistence/daily_activity_persistence_service.dart';
import 'package:mayabela/services/persistence/message_persistence_service.dart';
import 'package:mayabela/services/persistence/platform_audit_persistence_service.dart';
import 'package:mayabela/services/persistence/school_content_persistence_service.dart';
import 'package:mayabela/services/persistence/school_registry_persistence_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/persistence/timetable_persistence_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/staff_registry_notifier.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/timetable_service.dart';
import 'package:mayabela/utils/startup_profiler.dart';

/// Syncs app data between local services and Firestore.
class CloudAppStore {
  CloudAppStore._();
  static final instance = CloudAppStore._();

  static Future<void>? _pullChain;

  final DocumentStore _crud = DocumentStore();

  bool get available =>
      CloudSyncFlags.enabled && SupabaseBootstrap.isInitialized;

  Future<T> _serializedPull<T>(Future<T> Function() action) {
    final generation = AuthService.sessionGeneration;
    final previous = (_pullChain ?? Future<void>.value())
        .catchError((_) => null);
    late final Future<T> run;
    run = previous.then((_) {
      if (!AuthService.isLiveGeneration(generation)) {
        return Future<T>.error(
          StateError('Skipped cloud pull for ended session'),
        );
      }
      return action();
    }).whenComplete(() {
      if (identical(_pullChain, run)) {
        _pullChain = null;
      }
    });
    _pullChain = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<void> _prepareCloudRead() async {
    if (!available) return;
    if (AuthService.currentUser == null) {
      throw StateError(
        'School cloud sign-in required. Sign in again to sync.',
      );
    }
    final generation = AuthService.sessionGeneration;
    final authed = await SupabaseBootstrap.ensureReadyForFirestore();
    if (!AuthService.isLiveGeneration(generation)) {
      throw StateError('Skipped cloud read for ended session');
    }
    if (!authed) {
      throw StateError(
        SupabaseBootstrap.lastAuthError ??
            'School cloud sign-in required. Sign in again to sync.',
      );
    }
  }

  Future<List<Map<String, dynamic>>> _schoolRead(
    String collection, {
    String? whereInField,
    List<String>? whereInValues,
    String? arrayContainsAnyField,
    List<String>? arrayContainsAnyValues,
    Map<String, Object?> equals = const {},
    DateTime? updatedSince,
  }) async {
    try {
      return await _crud.readBySchool(
        collection,
        schoolId: AuthService.activeSchoolId,
        whereInField: whereInField,
        whereInValues: whereInValues,
        arrayContainsAnyField: arrayContainsAnyField,
        arrayContainsAnyValues: arrayContainsAnyValues,
        equals: equals,
        updatedSince: updatedSince,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudAppStore] read $collection failed: $e');
      }
      return const [];
    }
  }

  /// EDUABA CloudSyncEngine — flush write-behind outbox each tick.
  Future<void> flushOutboxForSyncEngine() async {
    if (!available) return;
    await uploadLocalLeftoversToCloud();
  }

  /// EDUABA CloudSyncEngine — cheap delta probe, then collection-scoped apply.
  ///
  /// First boot (no cursor): full role download once.
  /// Later ticks: probe collections with `updated_at > cursor` and re-pull
  /// only the collections that have new rows. A GPS ping no longer downloads
  /// the whole school.
  Future<bool> pullRoleDeltaForSyncEngine({
    required List<String> collections,
  }) async {
    if (!available) return false;
    await _prepareCloudRead();
    final cursors = SyncCursorStore.instance;
    await cursors.ensureLoaded();

    if (cursors.cursorFor(SyncCursorStore.bootCursorKey) == null) {
      await _pullCurrentRolePack();
      await cursors.markRoleBoot(collections);
      return true;
    }

    final changed = <String>[];
    for (final collection in collections) {
      final raw = cursors.cursorFor(collection);
      final since = raw == null ? null : DateTime.tryParse(raw);
      final rows = await _schoolRead(collection, updatedSince: since);
      if (rows.isEmpty) continue;
      changed.add(collection);
    }

    if (changed.isEmpty) return false;

    await pullMappedCollections(changed);
    final now = DateTime.now().toUtc();
    for (final collection in changed) {
      await cursors.setCursor(collection, now);
    }
    return true;
  }

  /// Apply only the named collections (realtime / targeted refresh).
  Future<void> pullMappedCollections(Iterable<String> collections) {
    return _serializedPull(() async {
      if (!available) return;
      await _prepareCloudRead();
      await _applyMappedCollections(collections);
    });
  }

  Future<void> _applyMappedCollections(Iterable<String> collections) async {
    final seen = <String>{};
    for (final collection in collections) {
      final key = _pullGroupKey(collection);
      if (key == null || !seen.add(key)) continue;
      await _runPullGroup(key);
    }
  }

  @visibleForTesting
  String? pullGroupKeyForTest(String collection) => _pullGroupKey(collection);

  @visibleForTesting
  bool classReadsAreSchoolWideForTest() => !AuthService.usesScopedCloudReads;

  @visibleForTesting
  bool studentIdReadsAreSchoolWideForTest() {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return false;
    }
    if (role == AuthService.roleTeacher) {
      return !AuthService.usesScopedCloudReads;
    }
    return true;
  }

  String? _pullGroupKey(String collection) {
    switch (collection) {
      case AppCollections.conversations:
        return 'conversations';
      case AppCollections.appNotifications:
        return 'notifications';
      case AppCollections.attendanceSessions:
        return 'attendance';
      case AppCollections.gradeReports:
        return 'grades';
      case AppCollections.busLivePositions:
        return 'bus_gps';
      case AppCollections.transportPassengerStatus:
        return 'passenger_status';
      case AppCollections.transportScans:
        return 'transport_scans';
      case AppCollections.parentLinkRequests:
        return 'parent_links';
      case AppCollections.studentRegistry:
        return 'students';
      case AppCollections.teacherRegistry:
        return 'teachers';
      case AppCollections.driverRegistry:
        return 'drivers';
      case AppCollections.employeeRegistry:
        return 'employees';
      case AppCollections.studentMedical:
        return 'medical';
      case AppCollections.schoolRegistry:
        return 'school_registry';
      case AppCollections.gradeAuditLog:
        return 'grade_audit';
      case AppCollections.homework:
        return 'homework';
      case AppCollections.dailyActivities:
        return 'daily_activities';
      case AppCollections.announcements:
        return 'announcements';
      case AppCollections.learningMaterials:
        return 'learning_materials';
      case AppCollections.calendarEvents:
        return 'calendar';
      case AppCollections.galleryPosts:
        return 'gallery';
      case AppCollections.classTimetables:
        return 'timetables';
      case AppCollections.fees:
        return 'fees';
      case AppCollections.buses:
        return 'buses';
      case AppCollections.disciplineCases:
        return 'discipline';
      case AppCollections.leaveRequests:
        return 'leave';
      case AppCollections.qaFindings:
        return 'qa_findings';
      case AppCollections.admissionApplications:
        return 'admissions';
      case AppCollections.examQuestions:
      case AppCollections.examPapers:
      case AppCollections.examAttempts:
        return 'exam_bank';
      case AppCollections.lessonPlans:
        return 'lesson_plans';
      case AppCollections.curriculumUnits:
      case AppCollections.curriculumFeedback:
      case AppCollections.lessonPlanReviews:
      case AppCollections.teacherEvaluations:
      case AppCollections.academicMeetings:
        return 'curriculum';
      case AppCollections.healthRecords:
      case AppCollections.counselingRecords:
      case AppCollections.iepPlans:
      case AppCollections.collegeGuidance:
      case AppCollections.supportRequests:
      case AppCollections.safeguardingCases:
        return 'student_support';
      case AppCollections.extracurricularClubs:
      case AppCollections.clubMemberships:
      case AppCollections.scholarships:
      case AppCollections.grievances:
      case AppCollections.internships:
      case AppCollections.dosaMeetings:
        return 'dosa';
      case AppCollections.teachingObservations:
      case AppCollections.academicAudits:
      case AppCollections.qaSurveys:
      case AppCollections.qaSurveyResponses:
      case AppCollections.actionResearch:
        return 'qa_monitor';
      case AppCollections.mfaEnrollments:
      case AppCollections.privacyConsents:
      case AppCollections.dataRightsRequests:
      case AppCollections.schoolBackups:
        return 'golive';
      case AppCollections.ictDevices:
      case AppCollections.ictWeeklyReviews:
        return 'digital_ops';
      case AppCollections.inventoryItems:
      case AppCollections.classroomInventory:
      case AppCollections.stockTransactions:
      case AppCollections.studentIssuedItems:
      case AppCollections.assets:
      case AppCollections.suppliers:
      case AppCollections.maintenanceReports:
        return 'inventory';
      case AppCollections.purchaseRequests:
        return 'procurement';
      case AppCollections.materialPurchaseRequests:
        return 'material_purchases';
      case AppCollections.transferRequests:
        return 'transfers';
      case AppCollections.schoolAuditLog:
        return 'school_audit';
      case AppCollections.authAccounts:
        return 'auth_accounts';
      default:
        return null;
    }
  }

  Future<void> _runPullGroup(String key) async {
    switch (key) {
      case 'conversations':
        await _pullConversations();
      case 'notifications':
        await _pullAppNotifications();
      case 'attendance':
        await _pullAttendanceSessions();
      case 'grades':
        await _pullGradeReports();
      case 'bus_gps':
        await _pullBusLivePositions();
      case 'passenger_status':
        await _pullTransportPassengerStatus();
      case 'transport_scans':
        await _pullTransportScans();
      case 'parent_links':
        await _pullParentLinks();
      case 'students':
        await _pullStudentRegistry();
      case 'teachers':
        await _pullTeacherRegistry();
      case 'drivers':
        await _pullDriverRegistry();
      case 'employees':
        await _pullEmployeeRegistry();
      case 'medical':
        await _pullStudentMedical();
      case 'school_registry':
        await _pullSchoolRegistry();
      case 'grade_audit':
        await _pullGradeAuditLog();
      case 'homework':
        await _pullHomework();
      case 'daily_activities':
        await _pullDailyActivities();
      case 'announcements':
        await _pullAnnouncements();
      case 'learning_materials':
        await _pullLearningMaterials();
      case 'calendar':
        await _pullCalendarEvents();
      case 'gallery':
        await _pullGalleryPosts();
      case 'timetables':
        await _pullClassTimetables();
      case 'fees':
        await _pullFees();
      case 'buses':
        await _pullBuses();
      case 'discipline':
        await _pullDisciplineCases();
      case 'leave':
        await _pullLeaveRequests();
      case 'qa_findings':
        await _pullQaFindings();
      case 'admissions':
        await _pullAdmissionApplications();
      case 'exam_bank':
        await _pullExamBank();
      case 'lesson_plans':
        await _pullLessonPlans();
      case 'curriculum':
        await _pullCurriculumOffice();
      case 'student_support':
        await _pullStudentSupport();
      case 'dosa':
        await _pullDosa();
      case 'qa_monitor':
        await _pullQaMonitor();
      case 'golive':
        await _pullGoLive();
      case 'digital_ops':
        await _pullDigitalOps();
      case 'inventory':
        await _pullInventory();
      case 'procurement':
        await _pullProcurement();
      case 'material_purchases':
        await _pullMaterialPurchases();
      case 'transfers':
        await _pullTransferRequests();
      case 'school_audit':
        await _pullSchoolAudit();
      case 'auth_accounts':
        await _pullAuthAccounts();
    }
  }

  Future<void> _pullCurrentRolePack() async {
    final role = AuthService.currentUser?.roleKey;
    switch (role) {
      case AuthService.roleAdmin:
        await pullForAdminSession();
      case AuthService.roleTeacher:
        await pullForTeacherSession();
      case AuthService.roleParent:
        await pullForParentSession();
      case AuthService.roleDriver:
        await pullForDriverSession();
      case AuthService.roleStudent:
        await pullForStudentSession();
      default:
        break;
    }
  }

  List<String> _localStudentIdsForTeacherScope() {
    final classes = AuthService.accessClassNamesForSync();
    if (classes.isEmpty) return const [];
    return StudentRegistryService.instance
        .registrySnapshot()
        .where(
          (s) => classes.any(
            (c) => StudentRegistryService.classNamesMatch(c, s.className),
          ),
        )
        .map((s) => s.studentId)
        .toList();
  }

  /// Parent keeps linked-student scope. Staff/admin always get school-wide
  /// students so integration sync works across roles and browsers.
  Future<List<Map<String, dynamic>>> _scopedStudentRead(String collection) {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return _schoolRead(
        collection,
        whereInField: 'studentId',
        whereInValues: AuthService.activeLinkedStudentIds(),
      );
    }
    // Admin + teacher/staff: full school directory (clear sync route).
    return _schoolRead(collection);
  }

  /// Parent / student stay linked-id scoped. Classroom teachers stay on
  /// assigned classes. Office desks with [AuthService.mayReadAllSchoolData]
  /// read the whole school (same rule as JWT RLS).
  Future<List<Map<String, dynamic>>> _scopedStudentIdRead(String collection) {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return _schoolRead(
        collection,
        whereInField: 'studentId',
        whereInValues: AuthService.activeLinkedStudentIds(),
      );
    }
    if (role == AuthService.roleTeacher && AuthService.usesScopedCloudReads) {
      return _schoolRead(
        collection,
        whereInField: 'studentId',
        whereInValues: _localStudentIdsForTeacherScope(),
      );
    }
    return _schoolRead(collection);
  }

  Future<List<Map<String, dynamic>>> _scopedClassRead(String collection) {
    if (!AuthService.usesScopedCloudReads) {
      return _schoolRead(collection);
    }
    return _schoolRead(
      collection,
      whereInField: 'className',
      whereInValues: AuthService.cloudClassNameQueryValues(),
    );
  }

  void _trackStep(bool track, String message) {
    if (track) CloudSyncProgressService.instance.step(message);
  }

  /// Pull all cloud data into local services (cloud wins on conflict).
  Future<void> pullIntoLocalServices({bool trackProgress = false}) {
    return _serializedPull(() async {
    if (!available) return;
    _trackStep(trackProgress, 'Connecting to cloud…');
    await _prepareCloudRead();
    if (AuthService.usesScopedCloudReads) {
      try {
        await SchoolAuthCloudService.instance.refreshAccessClaims();
      } catch (_) {}
    }

    _trackStep(trackProgress, 'Loading accounts…');
    await Future.wait([
      _pullAuthAccounts(),
      _pullParentLinks(),
    ]);
    // Students before class-scoped content so parent class names resolve.
    _trackStep(trackProgress, 'Loading students & staff…');
    await _pullTeacherRegistry();
    await Future.wait([
      _pullStudentRegistry(),
      _pullDriverRegistry(),
      _pullEmployeeRegistry(),
      _pullSchoolRegistry(),
    ]);
    await _pullStudentMedical();
    _trackStep(trackProgress, 'Loading grades & homework…');
    await Future.wait([
      _pullGradeReports(),
      _pullHomework(),
      _pullLearningMaterials(),
      _pullLessonPlans(),
      _pullCurriculumOffice(),
      _pullStudentSupport(),
      _pullDosa(),
      _pullQaMonitor(),
      _pullGoLive(),
      _pullDigitalOps(),
      _pullGradeAuditLog(),
      _pullDailyActivities(),
      _pullConversations(),
    ]);
    _trackStep(trackProgress, 'Loading announcements & fees…');
    await Future.wait([
      _pullAnnouncements(),
      _pullAttendanceSessions(),
      _pullFees(),
      _pullCalendarEvents(),
      _pullClassTimetables(),
      _pullGalleryPosts(),
      _pullQrScans(),
      _pullInventory(),
      _pullPlatformAudit(),
    ]);
    _trackStep(trackProgress, 'Loading transport…');
    await pullTransportStateIntoServices();
    _trackStep(trackProgress, 'Finalizing…');
    await AuthService.persistRegistryLoginAccounts();
    StaffRegistryNotifier.instance.notifyChanged();
    SchoolContentSyncService.instance.markDataChanged();
    });
  }

  /// Pre-login bootstrap — credentials are verified server-side; no password pull.
  Future<void> pullLoginBootstrapData() async {
    // Intentionally empty: schoolLogin Cloud Function authenticates users.
    // Pulling auth accounts before login is no longer permitted by security rules.
  }

  /// Push local registries to Firestore so other devices can pull them.
  Future<void> pushRegistriesToCloud() async {
    if (!available) return;
    await _prepareCloudRead();

    await pushAllSchools();

    final students = StudentRegistryService.instance.registrySnapshot();
    if (students.isNotEmpty) {
      await _pushSafe(() => _crud.writeBatch(
            collection: AppCollections.studentRegistry,
            items: students.map((s) => s.toMap()).toList(),
            docIdFor: (item) => item['studentId'] as String,
          ));
    }

    final teachers = TeacherRegistryService.instance.registrySnapshot();
    if (teachers.isNotEmpty) {
      await _pushSafe(() => _crud.writeBatch(
            collection: AppCollections.teacherRegistry,
            items: teachers.map((t) => t.toMap()).toList(),
            docIdFor: (item) => item['teacherId'] as String,
          ));
    }

    final drivers = DriverRegistryService.instance.registrySnapshot();
    if (drivers.isNotEmpty) {
      await _pushSafe(() => _crud.writeBatch(
            collection: AppCollections.driverRegistry,
            items: drivers.map((d) => d.toMap()).toList(),
            docIdFor: (item) => item['driverId'] as String,
          ));
    }

    final employees = EmployeeRegistryService.instance.registrySnapshot();
    if (employees.isNotEmpty) {
      await _pushSafe(() => _crud.writeBatch(
            collection: AppCollections.employeeRegistry,
            items: employees.map((e) => e.toMap()).toList(),
            docIdFor: (item) => item['employeeId'] as String,
          ));
    }

    await AuthService.persistRegistryLoginAccounts();
  }

  /// Upload all local school data to Firestore (for cross-device sync).
  Future<void> pushFullLocalStateToCloud() async {
    if (!available) return;
    await _prepareCloudRead();

    await pushRegistriesToCloud();

    final links = EnrollmentService.instance.allLinksSnapshot();
    if (links.isNotEmpty) {
      await _pushSafe(() => _crud.writeBatch(
            collection: AppCollections.parentLinkRequests,
            items: links.map((l) => l.toMap()).toList(),
            docIdFor: (item) => item['id'] as String,
          ));
    }

    await pushAllGradeReports();
    await pushAllHomework();
    await pushAllLearningMaterials();
    await pushAllGradeAuditEntries();
    await pushAllDailyActivities();
    await pushAllConversations();
    await pushAllSchoolContent();
    await pushAllInventory();
    await pushAllProcurement();
    await pushAllTransferRequests();
    await pushAllBuses();
    await pushAllSchoolAudit();
    await pushAllMaterialPurchases();
    await pushAllDisciplineCases();
    await pushAllLeaveRequests();
    await pushAllQaFindings();
    await pushAllAdmissionApplications();
    await pushAllExamBank();
    await pushAllLessonPlans();
    await pushAllCurriculumOffice();
    await pushAllStudentSupport();
    await pushAllDosa();
    await pushAllQaMonitor();
    await pushAllGoLive();
    await pushAllDigitalOps();
  }

  /// Upload queued document mutations; full snapshot only when still needed.
  Future<void> uploadLocalLeftoversToCloud() async {
    await CloudOutboxService.instance.ensureLoaded();
    if (!available) {
      return;
    }
    if (!CloudOutboxService.instance.hasPending) return;
    if (!await SchoolAuthCloudService.instance.ensureValidSchoolJwt()) {
      if (kDebugMode) {
        debugPrint('[CloudAppStore] upload skipped: no school JWT');
      }
      return;
    }

    try {
      await _prepareCloudRead();
      await _flushQueuedMutations();
      if (CloudOutboxService.instance.hasFullPush) {
        await CloudOutboxService.instance.clearFullPush();
        await pushFullLocalStateToCloud();
      }
    } catch (e) {
      final text = e.toString().toLowerCase();
      final authFail = text.contains('sub claim') ||
          text.contains('jwt') ||
          text.contains('denied') ||
          text.contains('sign in');
      if (!authFail) {
        await CloudOutboxService.instance.markFullPushNeeded(
          reason: 'upload failed: $e',
        );
      }
      rethrow;
    }
  }

  static const _registryCollections = {
    AppCollections.studentRegistry,
    AppCollections.teacherRegistry,
    AppCollections.driverRegistry,
    AppCollections.employeeRegistry,
  };

  Future<void> _flushQueuedMutations() async {
    final items = CloudOutboxService.instance.snapshotMutations();
    if (items.isEmpty) return;
    CloudOutboxService.instance.setFlushing(true);
    try {
      final byRegistry = <String, List<CloudOutboxMutation>>{};
      for (final m in items) {
        if (m.op == 'delete') {
          try {
            await _crud.deleteDoc(collection: m.collection, docId: m.docId);
            await CloudOutboxService.instance.ack(m.collection, m.docId);
          } catch (e) {
            if (kDebugMode) {
              debugPrint('[CloudAppStore] outbox delete failed ${m.docId}: $e');
            }
          }
          continue;
        }
        if (_registryCollections.contains(m.collection) && m.data != null) {
          byRegistry.putIfAbsent(m.collection, () => []).add(m);
          continue;
        }
        if (m.data == null) {
          await CloudOutboxService.instance.ack(m.collection, m.docId);
          continue;
        }
        try {
          await _crud.createOrUpdate(
            collection: m.collection,
            docId: m.docId,
            data: m.data!,
          );
          await CloudOutboxService.instance.ack(m.collection, m.docId);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('[CloudAppStore] outbox upsert failed ${m.docId}: $e');
          }
        }
      }

      final schoolId = AuthService.activeSchoolId?.trim().toUpperCase() ?? '';
      for (final entry in byRegistry.entries) {
        if (schoolId.isEmpty) break;
        final records = entry.value
            .map((m) => m.data)
            .whereType<Map<String, dynamic>>()
            .toList();
        if (records.isEmpty) continue;
        final r = await SchoolAuthCloudService.instance.upsertRegistryBatch(
          collection: entry.key,
          schoolId: schoolId,
          records: records,
        );
        if (r.ok) {
          for (final m in entry.value) {
            await CloudOutboxService.instance.ack(m.collection, m.docId);
          }
        } else if (kDebugMode) {
          debugPrint(
            '[CloudAppStore] outbox registry ${entry.key}: '
            '${r.errorMessage ?? r.errorCode}',
          );
        }
      }
    } finally {
      CloudOutboxService.instance.setFlushing(false);
    }
  }

  /// Upsert all students/teachers for the active school via service-role edge.
  Future<void> publishActiveSchoolDirectories() async {
    final schoolId = AuthService.activeSchoolId?.trim().toUpperCase();
    if (schoolId == null || schoolId.isEmpty || !available) return;

    final students = StudentRegistryService.instance
        .studentsForSchool(schoolId)
        .map((s) => s.toMap())
        .toList();
    if (students.isNotEmpty) {
      final r = await SchoolAuthCloudService.instance.upsertRegistryBatch(
        collection: AppCollections.studentRegistry,
        schoolId: schoolId,
        records: students,
      );
      if (!r.ok) {
        await CloudOutboxService.instance.markFullPushNeeded(
          reason: 'student batch: ${r.errorMessage ?? r.errorCode}',
        );
        throw StateError(
          r.errorMessage ?? 'Student directory upload failed (${r.errorCode})',
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[CloudAppStore] uploaded ${students.length} students → cloud',
        );
      }
    }

    final teachers = TeacherRegistryService.instance
        .teachersForSchool(schoolId)
        .map(
          (t) => Map<String, dynamic>.from(t.toMap())
            ..remove('initialPassword'),
        )
        .toList();
    if (teachers.isNotEmpty) {
      final r = await SchoolAuthCloudService.instance.upsertRegistryBatch(
        collection: AppCollections.teacherRegistry,
        schoolId: schoolId,
        records: teachers,
      );
      if (!r.ok) {
        await CloudOutboxService.instance.markFullPushNeeded(
          reason: 'teacher batch: ${r.errorMessage ?? r.errorCode}',
        );
        throw StateError(
          r.errorMessage ?? 'Teacher directory upload failed (${r.errorCode})',
        );
      }
      if (kDebugMode) {
        debugPrint(
          '[CloudAppStore] uploaded ${teachers.length} teachers → cloud',
        );
      }
    }
  }

  /// Push only local students/teachers that are not yet in the cloud for this school.
  Future<void> _pushMissingLocalRegistriesToCloud() async {
    final schoolId = AuthService.activeSchoolId?.trim().toUpperCase();
    if (schoolId == null || schoolId.isEmpty) return;

    final cloudStudents = await _schoolRead(AppCollections.studentRegistry);
    final cloudStudentIds = cloudStudents
        .map((m) => '${m['studentId'] ?? m['_docId'] ?? ''}'.trim().toUpperCase())
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final student
        in StudentRegistryService.instance.studentsForSchool(schoolId)) {
      if (cloudStudentIds.contains(student.studentId.toUpperCase())) continue;
      await pushStudentRegistryRecord(student);
    }

    final cloudTeachers = await _schoolRead(AppCollections.teacherRegistry);
    final cloudTeacherIds = cloudTeachers
        .map((m) => '${m['teacherId'] ?? m['_docId'] ?? ''}'.trim().toUpperCase())
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final teacher
        in TeacherRegistryService.instance.teachersForSchool(schoolId)) {
      if (cloudTeacherIds.contains(teacher.teacherId.toUpperCase())) continue;
      await pushTeacherRegistryRecord(teacher);
    }
  }

  /// Upload queued offline writes, then clear the outbox on success.
  Future<void> flushOutboxToCloud() => uploadLocalLeftoversToCloud();

  Future<void> pullIntoLocalServicesWithTimeout([
    Duration timeout = const Duration(seconds: 20),
    bool trackProgress = false,
  ]) async {
    if (!available) return;
    try {
      await StartupProfiler.track(
        'firestore.pullIntoLocalServices',
        () => pullIntoLocalServices(trackProgress: trackProgress).timeout(timeout),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[CloudAppStore] pullIntoLocalServices timed out/failed: $e');
      }
      if (trackProgress) {
        CloudSyncProgressService.instance.fail('Could not load all school data');
      }
    }
  }

  /// Pull enrollment, student registry, and school content for a parent session.
  Future<void> pullForParentSession() {
    return _serializedPull(() async {
      if (!available) return;
      await _prepareCloudRead();
      await _pullParentLinks();
      await _pullStudentRegistry();
      await _pullAuthAccounts();
      await _pullDriverRegistry();
      await _pullTeacherRegistry();
      await Future.wait([
        _pullDailyActivities(),
        _pullHomework(),
        _pullLearningMaterials(),
        _pullGradeReports(),
        _pullSchoolRegistry(),
        _pullGradeAuditLog(),
        _pullAnnouncements(),
        _pullCalendarEvents(),
        _pullClassTimetables(),
        _pullAttendanceSessions(),
        _pullFees(),
        _pullGalleryPosts(),
        _pullMaterialPurchases(),
        _pullDisciplineCases(),
        _pullLeaveRequests(),
        _pullConversations(),
        _pullAppNotifications(),
        _pullCurriculumOffice(),
        _pullLessonPlans(),
        _pullStudentSupport(),
        _pullDosa(),
        _pullQaMonitor(),
        _pullGoLive(),
      ]);
      await pullTransportStateIntoServices();
    });
  }

  /// Teacher: students, approvals, and content they create or parents see.
  Future<void> pullForTeacherSession() {
    return _serializedPull(() async {
      if (!available) return;
      await _prepareCloudRead();
      if (AuthService.usesScopedCloudReads) {
        try {
          await SchoolAuthCloudService.instance.refreshAccessClaims();
        } catch (_) {}
      }
      // Teachers first so class assignments exist before any class-scoped reads.
      await _pullTeacherRegistry();
      await Future.wait([
        _pullStudentRegistry(),
        _pullParentLinks(),
        _pullDriverRegistry(),
      ]);
      await Future.wait([
        _pullGradeReports(),
        _pullHomework(),
        _pullLearningMaterials(),
        _pullSchoolRegistry(),
        _pullGradeAuditLog(),
        _pullDailyActivities(),
        _pullAnnouncements(),
        _pullCalendarEvents(),
        _pullClassTimetables(),
        _pullAttendanceSessions(),
        _pullFees(),
        _pullGalleryPosts(),
        _pullMaterialPurchases(),
        _pullDisciplineCases(),
        _pullLeaveRequests(),
        _pullQaFindings(),
        _pullAdmissionApplications(),
        _pullExamBank(),
        _pullLessonPlans(),
        _pullCurriculumOffice(),
        _pullStudentSupport(),
        _pullDosa(),
        _pullQaMonitor(),
        _pullGoLive(),
        _pullDigitalOps(),
        _pullInventory(),
        _pullProcurement(),
        _pullConversations(),
        _pullAppNotifications(),
      ]);
      await pullTransportStateIntoServices();
    });
  }

  /// Admin: registries, enrollment queue, and school-wide content.
  Future<void> pullForAdminSession({bool trackProgress = false}) {
    return _serializedPull(() async {
      if (!available) return;
      _trackStep(trackProgress, 'Connecting to cloud…');
      await _prepareCloudRead();
      _trackStep(trackProgress, 'Loading accounts…');
      await _pullAuthAccounts();
      await _pullParentLinks();
      _trackStep(trackProgress, 'Loading students & staff…');
      await Future.wait([
        _pullStudentRegistry(),
        _pullTeacherRegistry(),
        _pullDriverRegistry(),
        _pullEmployeeRegistry(),
        _pullStudentMedical(),
      ]);
      _trackStep(trackProgress, 'Loading grades & homework…');
      await Future.wait([
        _pullGradeReports(),
        _pullHomework(),
        _pullLearningMaterials(),
        _pullSchoolRegistry(),
        _pullGradeAuditLog(),
        _pullDailyActivities(),
      ]);
      _trackStep(trackProgress, 'Loading fees & inventory…');
      await Future.wait([
        _pullAnnouncements(),
        _pullAttendanceSessions(),
        _pullFees(),
        _pullCalendarEvents(),
        _pullClassTimetables(),
        _pullGalleryPosts(),
        _pullInventory(),
        _pullProcurement(),
        _pullTransferRequests(),
        _pullBuses(),
        _pullSchoolAudit(),
        _pullMaterialPurchases(),
        _pullDisciplineCases(),
        _pullLeaveRequests(),
        _pullQaFindings(),
        _pullAdmissionApplications(),
        _pullExamBank(),
        _pullLessonPlans(),
        _pullCurriculumOffice(),
        _pullStudentSupport(),
        _pullDosa(),
        _pullQaMonitor(),
        _pullGoLive(),
        _pullDigitalOps(),
        _pullConversations(),
        _pullAppNotifications(),
      ]);
      _trackStep(trackProgress, 'Loading transport…');
      await pullTransportStateIntoServices();
      _trackStep(trackProgress, 'Finalizing…');
    });
  }

  /// Driver: roster assignments and student transport flags.
  Future<void> pullForDriverSession() {
    return _serializedPull(() async {
      if (!available) return;
      await _prepareCloudRead();
      await Future.wait([
        _pullDriverRegistry(),
        _pullStudentRegistry(),
        _pullConversations(),
        _pullAppNotifications(),
      ]);
      await pullTransportStateIntoServices();
    });
  }

  /// Student: class content from homeroom teacher and school-wide updates.
  Future<void> pullForStudentSession() {
    return _serializedPull(() async {
      if (!available) return;
      await _prepareCloudRead();
      if (AuthService.usesScopedCloudReads) {
        try {
          await SchoolAuthCloudService.instance.refreshAccessClaims();
        } catch (_) {}
      }
      await Future.wait([
        _pullStudentRegistry(),
        _pullTeacherRegistry(),
        _pullSchoolRegistry(),
      ]);
      await Future.wait([
        _pullHomework(),
        _pullLearningMaterials(),
        _pullGradeReports(),
        _pullDailyActivities(),
        _pullAnnouncements(),
        _pullCalendarEvents(),
        _pullClassTimetables(),
        _pullAttendanceSessions(),
        _pullConversations(),
        _pullAppNotifications(),
        _pullMaterialPurchases(),
        _pullExamBank(),
        _pullLessonPlans(),
        _pullCurriculumOffice(),
        _pullStudentSupport(),
        _pullDosa(),
        _pullQaMonitor(),
        _pullGoLive(),
      ]);
      await pullTransportStateIntoServices();
    });
  }

  /// Targeted inventory refresh (realtime listeners).
  Future<void> pullInventoryIntoService() async {
    if (!available) return;
    await _prepareCloudRead();
    await _pullInventory();
  }

  Future<void> _pushSafe(
    Future<void> Function() action, {
    bool rethrowOnError = false,
    bool immediate = false,
  }) async {
    // Any intended cloud write while offline/unavailable is queued for later
    // flush (students, teachers, grades, announcements, calendar, etc.).
    if (!available) {
      if (rethrowOnError) {
        throw StateError(
          CloudSyncFlags.enabled
              ? 'Cloud not available — sign in again and wait for Ready.'
              : 'Cloud sync is disabled.',
        );
      }
      return;
    }

    // Refresh claims when missing. Do not block an explicit Send on a
    // false-negative claims check — the JWT may still be valid for RLS.
    if (!await SchoolAuthCloudService.hasSchoolClaims()) {
      final ok = await SchoolAuthCloudService.instance.ensureValidSchoolJwt();
      if (!ok && !immediate) {
        if (rethrowOnError) {
          throw StateError(
            'Cloud session expired — sign out, sign in as Admin, wait for Ready.',
          );
        }
        return;
      }
    }

    var deviceLooksOffline = false;
    try {
      final links = await Connectivity().checkConnectivity();
      deviceLooksOffline = links.isEmpty ||
          links.every((r) => r == ConnectivityResult.none);
    } catch (_) {
      // Connectivity plugin failures should not block an attempted push.
    }

    if (deviceLooksOffline && !immediate) {
      await CloudOutboxService.instance.markFullPushNeeded(
        reason: 'device offline',
      );
      // Flutter web often mis-reports connectivity as "none" while online.
      // Still attempt the write there; only skip the network call on mobile
      // unless the caller asked for an immediate user-triggered upload.
      if (!kIsWeb) {
        if (rethrowOnError) {
          throw StateError(
            'Offline — saved on this device; will upload when online.',
          );
        }
        return;
      }
    }

    try {
      await action().timeout(const Duration(seconds: 45));
    } catch (e) {
      await CloudOutboxService.instance.markFullPushNeeded(
        reason: e.toString(),
      );
      if (kDebugMode) {
        debugPrint('[CloudAppStore] push failed: $e');
      }
      if (rethrowOnError) rethrow;
    }
  }

  // —— CRUD: Auth ——

  Future<void> pushAuthUser(RegisteredUser user) async {
    // Never write password fields from the client. Secrets go through Cloud Functions.
    final plain = user.password.trim();
    final shouldSetSecret = plain.isNotEmpty &&
        !plain.startsWith('sha256:') &&
        plain != AuthService.passwordRedactedMarker;
    final schoolId = (user.schoolId ?? AuthService.activeSchoolId ?? '')
        .trim()
        .toUpperCase();
    final docId = schoolAccountDocId(schoolId, user.username);

    if (shouldSetSecret && schoolId.isNotEmpty) {
      if (plain.length < AuthService.minPasswordLength) {
        if (kDebugMode) {
          debugPrint(
            '[CloudAppStore] skip secret upsert: password shorter than '
            '${AuthService.minPasswordLength}',
          );
        }
        await _pushSafe(() => _crud.createOrUpdate(
              collection: AppCollections.authAccounts,
              docId: docId,
              data: {
                'username': user.username,
                'roleKey': user.roleKey,
                if (user.email != null) 'email': user.email,
                if (user.phone != null) 'phone': user.phone,
                'schoolId': schoolId,
                if (user.fullName != null) 'fullName': user.fullName,
                'linkedStudentIds': user.linkedStudentIds,
                if (user.linkedTeacherId != null)
                  'linkedTeacherId': user.linkedTeacherId,
                if (user.linkedAdminId != null) 'linkedAdminId': user.linkedAdminId,
                if (user.linkedDriverId != null)
                  'linkedDriverId': user.linkedDriverId,
                if (user.linkedStudentId != null)
                  'linkedStudentId': user.linkedStudentId,
                'mustChangePassword': user.mustChangePassword,
              },
            ));
        return;
      }
      await SchoolAuthCloudService.instance.upsertAccount(
        user: user,
        password: plain,
      );
      return;
    }

    // Prefer edge upsert when we have a school — keeps school-scoped doc ids.
    if (schoolId.isNotEmpty && SchoolAuthCloudService.instance.isAvailable) {
      final toUpsert = (user.schoolId ?? '').trim().isEmpty
          ? RegisteredUser(
              username: user.username,
              password: user.password,
              roleKey: user.roleKey,
              email: user.email,
              phone: user.phone,
              schoolId: schoolId,
              fullName: user.fullName,
              linkedStudentIds: user.linkedStudentIds,
              linkedTeacherId: user.linkedTeacherId,
              linkedAdminId: user.linkedAdminId,
              linkedDriverId: user.linkedDriverId,
              linkedStudentId: user.linkedStudentId,
              mustChangePassword: user.mustChangePassword,
              staffRoles: user.staffRoles,
              staffPermissions: user.staffPermissions,
            )
          : user;
      final cloud = await SchoolAuthCloudService.instance.upsertAccount(
        user: toUpsert,
      );
      if (cloud.ok) return;
    }

    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.authAccounts,
          docId: docId,
          data: {
            'username': user.username,
            'roleKey': user.roleKey,
            if (user.email != null) 'email': user.email,
            if (user.phone != null) 'phone': user.phone,
            if (schoolId.isNotEmpty) 'schoolId': schoolId,
            if (user.fullName != null) 'fullName': user.fullName,
            'linkedStudentIds': user.linkedStudentIds,
            if (user.linkedTeacherId != null)
              'linkedTeacherId': user.linkedTeacherId,
            if (user.linkedAdminId != null) 'linkedAdminId': user.linkedAdminId,
            if (user.linkedDriverId != null)
              'linkedDriverId': user.linkedDriverId,
            if (user.linkedStudentId != null)
              'linkedStudentId': user.linkedStudentId,
            'mustChangePassword': user.mustChangePassword,
            // staffRoles is intentionally omitted: the write-guard treats a
            // missing key as "no change", so ordinary profile syncs can never
            // wipe role grants. Grants flow through StaffRoleService only.
          },
        ));
  }

  Future<void> deleteAuthUser(String username, {String? schoolId}) async {
    final sid = (schoolId ?? AuthService.activeSchoolId ?? '').trim();
    final ids = <String>{
      username.trim().toLowerCase(),
      if (sid.isNotEmpty) schoolAccountDocId(sid, username),
    };
    for (final id in ids) {
      await _pushSafe(() => _crud.deleteDoc(
            collection: AppCollections.authAccounts,
            docId: id,
          ));
    }
  }

  // —— CRUD: Parent links ——

  Future<void> pushParentLink(ParentLinkRequest link) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.parentLinkRequests,
          docId: link.id,
          data: link.toMap(),
        ));
  }

  Future<void> deleteParentLink(String linkId) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.parentLinkRequests,
          docId: linkId,
        ));
  }

  // —— CRUD: Student registry & medical ——

  Future<void> pushStudentRegistryRecord(
    AdminStudentRecord student, {
    bool requireSuccess = false,
    bool immediate = false,
  }) async {
    final force = immediate || requireSuccess;
    await _pushSafe(
      () async {
        // User hit Save — refresh session and write now (do not wait for Ready).
        if (force) {
          try {
            await SupabaseBootstrap.ensureReadyForFirestore();
          } catch (_) {}
          try {
            await SupabaseBootstrap.client.auth.refreshSession();
          } catch (_) {}
        } else {
          await _prepareCloudRead();
        }
        final schoolId = (student.schoolId.trim().isNotEmpty
                ? student.schoolId
                : AuthService.activeSchoolId ?? '')
            .trim()
            .toUpperCase();
        final edge = await SchoolAuthCloudService.instance.upsertRegistryRecord(
          collection: AppCollections.studentRegistry,
          schoolId: schoolId,
          docId: student.studentId,
          record: student.toMap(),
        );
        if (edge.ok) return;
        if (edge.errorCode == 'cloud_required') {
          await _crud.createOrUpdate(
            collection: AppCollections.studentRegistry,
            docId: student.studentId,
            data: student.toMap(),
          );
          return;
        }
        throw StateError(
          edge.errorMessage ??
              'Student could not sync to the cloud (${edge.errorCode}).',
        );
      },
      rethrowOnError: requireSuccess,
      immediate: force,
    );
  }

  /// Soft push of in-memory students for the active school (orphan repair).
  Future<void> _pushLocalStudentRegistryBestEffort() async {
    final schoolId = AuthService.activeSchoolId?.trim().toUpperCase();
    if (schoolId == null || schoolId.isEmpty) return;
    final students =
        StudentRegistryService.instance.studentsForSchool(schoolId);
    for (final student in students) {
      await pushStudentRegistryRecord(student);
    }
  }

  /// Soft push of in-memory teachers for the active school (orphan repair).
  Future<void> _pushLocalTeacherRegistryBestEffort() async {
    final schoolId = AuthService.activeSchoolId?.trim().toUpperCase();
    if (schoolId == null || schoolId.isEmpty) return;
    final teachers =
        TeacherRegistryService.instance.teachersForSchool(schoolId);
    for (final teacher in teachers) {
      await pushTeacherRegistryRecord(teacher);
    }
  }

  Future<void> deleteStudentRegistryRecord(String studentId) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.studentRegistry,
          docId: studentId,
        ));
  }

  Future<void> pushStudentMedical(AdminStudentRecord student) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.studentMedical,
          docId: student.studentId,
          data: {
            'studentId': student.studentId,
            'schoolId': student.schoolId,
            'className': student.className,
            'hasMedicalCondition': student.hasMedicalCondition,
            if (student.medicalConditionDetails != null)
              'medicalConditionDetails': student.medicalConditionDetails,
            if (student.otherMedicalInfo != null)
              'otherMedicalInfo': student.otherMedicalInfo,
          },
        ));
  }

  // —— CRUD: Teacher & driver registry ——

  Future<void> pushTeacherRegistryRecord(
    AdminTeacherRecord teacher, {
    bool requireSuccess = false,
  }) async {
    await _pushSafe(
      () async {
        await _prepareCloudRead();
        final data = Map<String, dynamic>.from(teacher.toMap())
          ..remove('initialPassword');
        final schoolId = (teacher.schoolId.trim().isNotEmpty
                ? teacher.schoolId
                : AuthService.activeSchoolId ?? '')
            .trim()
            .toUpperCase();
        final edge = await SchoolAuthCloudService.instance.upsertRegistryRecord(
          collection: AppCollections.teacherRegistry,
          schoolId: schoolId,
          docId: teacher.teacherId,
          record: data,
        );
        if (edge.ok) return;
        if (edge.errorCode == 'cloud_required') {
          await _crud.createOrUpdate(
            collection: AppCollections.teacherRegistry,
            docId: teacher.teacherId,
            data: data,
          );
          return;
        }
        throw StateError(
          edge.errorMessage ??
              'Staff directory could not sync to the cloud (${edge.errorCode}).',
        );
      },
      rethrowOnError: requireSuccess,
    );
  }

  Future<void> deleteTeacherRegistryRecord(String teacherId) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.teacherRegistry,
          docId: teacherId,
        ));
  }

  Future<void> pushDriverRegistryRecord(AdminDriverRecord driver) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.driverRegistry,
          docId: driver.driverId,
          data: driver.toMap(),
        ));
  }

  Future<void> deleteDriverRegistryRecord(String driverId) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.driverRegistry,
          docId: driverId,
        ));
  }

  Future<void> pushEmployeeRegistryRecord(EmployeeRecord employee) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.employeeRegistry,
          docId: employee.employeeId,
          data: employee.toMap(),
        ));
  }

  Future<void> deleteEmployeeRegistryRecord(String employeeId) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.employeeRegistry,
          docId: employeeId,
        ));
  }

  // —— CRUD: Grades, homework, daily activities ——

  Future<void> pushGradeReport(StudentGradeReport report) async {
    final docId = _gradeDocId(report);
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.gradeReports,
          docId: docId,
          data: report.toMap(),
        ));
  }

  Future<void> pushAllGradeReports() async {
    final reports = SchoolDataService.instance.gradeReportsSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.gradeReports,
          items: reports.map((r) => r.toMap()).toList(),
          docIdFor: (item) => _gradeDocIdFromMap(item),
        ));
  }

  Future<void> deleteGradeReport(StudentGradeReport report) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.gradeReports,
          docId: _gradeDocId(report),
        ));
  }

  Future<void> pushHomeworkItem(HomeworkItem item) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.homework,
          docId: item.id,
          data: item.toMap(),
        ));
  }

  Future<void> pushAllHomework() async {
    final items = SchoolDataService.instance.homeworkSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.homework,
          items: items.map((i) => i.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> deleteHomeworkItem(String id) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.homework,
          docId: id,
        ));
  }

  Future<void> pushLearningMaterialItem(LearningMaterialItem item) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.learningMaterials,
          docId: item.id,
          data: item.toMap(),
        ));
  }

  Future<void> pushAllLearningMaterials() async {
    final items = SchoolDataService.instance.learningMaterialsSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.learningMaterials,
          items: items.map((i) => i.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  // —— CRUD: Inventory ——

  Future<void> pushAllInventory() async {
    final svc = InventoryService.instance;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.inventoryItems,
          items: svc.itemsSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.stockTransactions,
          items: svc.transactionsSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.studentIssuedItems,
          items: svc.studentIssuedSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.classroomInventory,
          items: svc.classroomSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.assets,
          items: svc.assetsSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.suppliers,
          items: svc.suppliersSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.maintenanceReports,
          items: svc.maintenanceSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  /// Purchase / issue requests. The server-side write-guard permission-gates
  /// each row, so batch echoes from devices without procurement permissions
  /// are skipped silently instead of failing the sync.
  Future<void> pushAllProcurement() async {
    final svc = ProcurementService.instance;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.purchaseRequests,
          items: svc.purchasesSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.issueRequests,
          items: svc.issuesSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> pushAllTransferRequests() async {
    final svc = TransferWorkflowService.instance;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.transferRequests,
          items: svc.requestsSnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  /// Student Affairs cases — staff/teacher/admin writers pass the write guard.
  Future<void> pushAllDisciplineCases() async {
    final items = DisciplineService.instance.snapshotMaps();
    if (items.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.disciplineCases,
          items: items,
          docIdFor: (item) => item['id'] as String,
        ));
  }

  /// Admissions pipeline — registrar/admin writers pass the write guard.
  Future<void> pushAllAdmissionApplications() async {
    final items = AdmissionService.instance.snapshotMaps();
    if (items.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.admissionApplications,
          items: items,
          docIdFor: (item) => item['id'] as String,
        ));
  }

  /// QA findings — QA staff (teacher JWT) writers pass the write guard.
  Future<void> pushAllQaFindings() async {
    final items = QaFindingsService.instance.snapshotMaps();
    if (items.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.qaFindings,
          items: items,
          docIdFor: (item) => item['id'] as String,
        ));
  }

  /// Leave requests — via the service-role registry edge because parents
  /// (the submitters) are not in the client write-guard allowlist.
  Future<void> pushAllLeaveRequests() async {
    final items = LeaveRequestService.instance.snapshotMaps();
    if (items.isEmpty) return;
    await _pushSafe(() async {
      final result = await SchoolAuthCloudService.instance.upsertRegistryBatch(
        collection: AppCollections.leaveRequests,
        records: items,
      );
      if (!result.ok) {
        throw StateError(
          result.errorMessage ?? 'Leave request sync failed.',
        );
      }
    });
  }

  /// Question bank + papers (staff writeBatch) and attempts (upsert so
  /// students can submit without a client write-guard allowlist).
  Future<void> pushAllExamBank() async {
    final role = AuthService.currentUser?.roleKey;
    final isStudent = role == AuthService.roleStudent;
    if (!isStudent) {
      final questions = ExamService.instance.questionMaps();
      if (questions.isNotEmpty) {
        await _pushSafe(() => _crud.writeBatch(
              collection: AppCollections.examQuestions,
              items: questions,
              docIdFor: (item) => item['id'] as String,
            ));
      }
      final papers = ExamService.instance.paperMaps();
      if (papers.isNotEmpty) {
        await _pushSafe(() => _crud.writeBatch(
              collection: AppCollections.examPapers,
              items: papers,
              docIdFor: (item) => item['id'] as String,
            ));
      }
    }
    final attempts = ExamService.instance.attemptMaps();
    if (attempts.isEmpty) return;
    await _pushSafe(() async {
      final result = await SchoolAuthCloudService.instance.upsertRegistryBatch(
        collection: AppCollections.examAttempts,
        records: attempts,
      );
      if (!result.ok) {
        throw StateError(result.errorMessage ?? 'Exam attempt sync failed.');
      }
    });
  }

  Future<void> pushAllLessonPlans() async {
    final items = LessonPlanService.instance.snapshotMaps();
    if (items.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.lessonPlans,
          items: items,
          docIdFor: (item) => item['id'] as String,
        ));
  }

  /// Staff write units / reviews / evals / meetings. Feedback uses
  /// school-upsert-registry so students and parents can submit comments.
  Future<void> pushAllCurriculumOffice() async {
    final svc = CurriculumService.instance;
    final role = AuthService.currentUser?.roleKey;
    final publicReader = role == AuthService.roleStudent ||
        role == AuthService.roleParent;
    if (!publicReader) {
      final units = svc.unitMaps();
      if (units.isNotEmpty) {
        await _pushSafe(() => _crud.writeBatch(
              collection: AppCollections.curriculumUnits,
              items: units,
              docIdFor: (item) => item['id'] as String,
            ));
      }
      final reviews = svc.reviewMaps();
      if (reviews.isNotEmpty) {
        await _pushSafe(() => _crud.writeBatch(
              collection: AppCollections.lessonPlanReviews,
              items: reviews,
              docIdFor: (item) => item['id'] as String,
            ));
      }
      final evals = svc.evaluationMaps();
      if (evals.isNotEmpty) {
        await _pushSafe(() => _crud.writeBatch(
              collection: AppCollections.teacherEvaluations,
              items: evals,
              docIdFor: (item) => item['id'] as String,
            ));
      }
      final meetings = svc.meetingMaps();
      if (meetings.isNotEmpty) {
        await _pushSafe(() => _crud.writeBatch(
              collection: AppCollections.academicMeetings,
              items: meetings,
              docIdFor: (item) => item['id'] as String,
            ));
      }
    }
    final feedback = svc.feedbackMaps();
    if (feedback.isEmpty) return;
    await _pushSafe(() async {
      final result = await SchoolAuthCloudService.instance.upsertRegistryBatch(
        collection: AppCollections.curriculumFeedback,
        records: feedback,
      );
      if (!result.ok) {
        throw StateError(result.errorMessage ?? 'Curriculum feedback sync failed.');
      }
    });
  }

  Future<void> pushAllBuses() async {
    final svc = BusRegistryService.instance;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.buses,
          items: svc.registrySnapshot().map((e) => e.toMap()).toList(),
          docIdFor: (item) => item['busId'] as String,
        ));
  }

  Future<void> pushAllSchoolAudit() async {
    final entries = SchoolAuditLogService.instance.snapshot();
    if (entries.isEmpty) return;
    // Append-only collection: never upsert (updates are blocked by SQL).
    for (final entry in entries) {
      await _pushSafe(() => _crud.insertIfAbsent(
            collection: AppCollections.schoolAuditLog,
            docId: entry.id,
            data: entry.toMap(),
          ));
    }
  }

  Future<void> pushAllMaterialPurchases() async {
    final items = MaterialPurchaseService.instance
        .snapshot()
        .map((e) => e.toMap())
        .toList();
    if (items.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.materialPurchaseRequests,
          items: items,
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> pushSchoolAuditEntry(SchoolAuditEntry entry) async {
    await _pushSafe(() => _crud.insertIfAbsent(
          collection: AppCollections.schoolAuditLog,
          docId: entry.id,
          data: entry.toMap(),
        ));
  }

  Future<void> deleteLearningMaterialItem(String id) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.learningMaterials,
          docId: id,
        ));
  }

  Future<void> pushGradeAuditEntry(GradeAuditEntry entry) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.gradeAuditLog,
          docId: entry.id,
          data: entry.toMap(),
        ));
  }

  Future<void> pushAllGradeAuditEntries() async {
    final entries = GradeAuditService.instance.snapshotMaps();
    if (entries.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.gradeAuditLog,
          items: entries,
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> pushDailyActivity(DailyActivityReport report) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.dailyActivities,
          docId: report.id,
          data: report.toMap(),
        ));
  }

  Future<void> pushAllDailyActivities() async {
    final reports = SchoolDataService.instance.dailyActivitiesSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.dailyActivities,
          items: reports.map((r) => r.toMap()).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> deleteDailyActivity(String id) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.dailyActivities,
          docId: id,
        ));
  }

  // —— CRUD: Conversations ——

  Future<void> pushConversation(
    Conversation conversation, {
    String? schoolId,
    bool requireCloud = false,
  }) async {
    final sid = (SchoolAuthCloudService.jwtSchoolId() ??
            schoolId ??
            SchoolAuthCloudService.resolvedSchoolId() ??
            AuthService.activeSchoolId ??
            '')
        .trim()
        .toUpperCase();
    var merged = conversation;
    try {
      final existing = await _crud.readDoc(
        collection: AppCollections.conversations,
        docId: conversation.id,
      );
      if (existing != null) {
        existing['id'] = conversation.id;
        final cloud = ConversationDocument.fromMap(existing).toConversation();
        SchoolDataService.instance.mergeConversationFromCloud(cloud);
        merged =
            SchoolDataService.instance.getConversation(conversation.id) ??
                conversation;
      }
    } catch (_) {}

    final doc = ConversationDocument.fromConversation(
      merged,
      schoolId: sid.isEmpty ? null : sid,
    );
    await _pushSafe(
      () => _crud.createOrUpdate(
        collection: AppCollections.conversations,
        docId: merged.id,
        data: doc.toMap(),
      ),
      rethrowOnError: requireCloud,
      immediate: true,
    );
  }

  Future<void> pushAllConversations() async {
    final conversations = SchoolDataService.instance.getConversations();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.conversations,
          items: conversations
              .map(
                (c) => ConversationDocument.fromConversation(c).toMap(),
              )
              .toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> deleteConversation(String conversationId) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.conversations,
          docId: conversationId,
        ));
  }

  // —— Pull helpers ——

  Future<void> _pullAuthAccounts() async {
    final role = AuthService.currentUser?.roleKey;
    final List<Map<String, dynamic>> rows;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      final username = AuthService.currentUser?.username.toLowerCase();
      if (username == null || username.isEmpty) return;
      final own = await _crud.readDoc(
        collection: AppCollections.authAccounts,
        docId: schoolAccountDocId(
          AuthService.activeSchoolId ?? '',
          username,
        ),
      );
      final legacy = own == null
          ? await _crud.readDoc(
              collection: AppCollections.authAccounts,
              docId: username,
            )
          : null;
      rows = (own ?? legacy) == null ? const [] : [own ?? legacy!];
    } else if (role == AuthService.roleTeacher) {
      rows = await _schoolRead(
        AppCollections.authAccounts,
        whereInField: 'roleKey',
        whereInValues: const [
          AuthService.roleTeacher,
          AuthService.roleAdmin,
          AuthService.roleDriver,
        ],
      );
    } else {
      rows = await _schoolRead(AppCollections.authAccounts);
    }
    for (final map in rows) {
      try {
        final user = RegisteredUser(
          username: map['username'] as String,
          // Passwords live in auth_secrets (Admin SDK only).
          password: AuthService.passwordRedactedMarker,
          roleKey: map['roleKey'] as String,
          email: map['email'] as String?,
          phone: map['phone'] as String?,
          schoolId: map['schoolId'] as String?,
          fullName: map['fullName'] as String?,
          linkedStudentIds: (map['linkedStudentIds'] as List<dynamic>?)
                  ?.map((e) => e.toString())
                  .toList() ??
              const [],
          linkedTeacherId: map['linkedTeacherId'] as String?,
          linkedAdminId: map['linkedAdminId'] as String?,
          linkedDriverId: map['linkedDriverId'] as String?,
          linkedStudentId: map['linkedStudentId'] as String?,
          mustChangePassword: map['mustChangePassword'] as bool? ?? false,
        );
        AuthService.mergePersistedUser(user);
      } catch (_) {}
    }
    if (rows.isNotEmpty) {
      await AuthPersistenceService.instance.saveAll();
    }
    AuthService.ensureRegistryLoginAccounts();
  }

  Future<void> _pullParentLinks() async {
    final role = AuthService.currentUser?.roleKey;
    var rows = await _schoolRead(AppCollections.parentLinkRequests);
    if (role == AuthService.roleParent) {
      final username = AuthService.currentUser?.username;
      if (username == null || username.trim().isEmpty) return;
      rows = rows.where((map) {
        final stored = '${map['parentUsername'] ?? ''}';
        final a = stored.trim().toLowerCase();
        final b = username.trim().toLowerCase();
        if (a.isNotEmpty && a == b) return true;
        return PhoneUtils.matches(stored, username);
      }).toList();
    }
    if (rows.isEmpty) return;

    final links = <ParentLinkRequest>[];
    var maxId = EnrollmentService.instance.nextLinkIdCounter;

    for (final map in rows) {
      try {
        final link = ParentLinkRequest.fromMap(map);
        links.add(link);
        final numeric = int.tryParse(link.id.replaceAll(RegExp(r'\D'), ''));
        if (numeric != null && numeric >= maxId) maxId = numeric + 1;
      } catch (_) {}
    }

    if (links.isNotEmpty) {
      if (role == AuthService.roleParent) {
        EnrollmentService.instance.upsertLinks(links, nextId: maxId);
      } else {
        EnrollmentService.instance.replaceLinks(links, nextId: maxId);
      }
      await EnrollmentPersistenceService.instance.saveFromEnrollmentService(
        pushCloud: false,
      );
    }
  }

  Future<void> _pullStudentRegistry() async {
    final rows = await _scopedStudentRead(AppCollections.studentRegistry);
    if (rows.isEmpty) return;

    final students = <AdminStudentRecord>[];
    var maxId = StudentRegistryService.instance.nextStudentIdCounter;

    for (final map in rows) {
      try {
        final student = AdminStudentRecord.fromMap(map);
        students.add(student);
        final numeric = ShortRegistryId.parseNumber(student.studentId);
        if (numeric != null && numeric >= maxId) maxId = numeric + 1;
      } catch (_) {}
    }

    if (students.isNotEmpty) {
      StudentRegistryService.instance.applyPersistedStudents(
        students,
        nextId: maxId,
      );
      await StudentPersistenceService.instance.saveRegistryFromService(
        pushCloud: false,
      );
    }
  }

  Future<void> _pullTeacherRegistry() async {
    final rows = await _schoolRead(AppCollections.teacherRegistry);
    if (rows.isEmpty) return;

    final teachers = <AdminTeacherRecord>[];
    var maxId = TeacherRegistryService.instance.nextTeacherIdCounter;

    for (final map in rows) {
      try {
        final teacher = AdminTeacherRecord.fromMap(map);
        teachers.add(teacher);
        final numeric = ShortRegistryId.parseNumber(teacher.teacherId);
        if (numeric != null && numeric >= maxId) maxId = numeric + 1;
      } catch (_) {}
    }

    if (teachers.isNotEmpty) {
      TeacherRegistryService.instance.applyPersistedTeachers(
        teachers,
        nextId: maxId,
      );
      await TeacherPersistenceService.instance.saveRegistryFromService(
        pushCloud: false,
        notifyStaff: false,
      );
    }
  }

  Future<void> _pullDriverRegistry() async {
    final rows = await _schoolRead(AppCollections.driverRegistry);
    if (rows.isEmpty) return;

    final drivers = <AdminDriverRecord>[];
    var maxId = DriverRegistryService.instance.nextDriverIdCounter;

    for (final map in rows) {
      try {
        final driver = AdminDriverRecord.fromMap(map);
        drivers.add(driver);
        final numeric = ShortRegistryId.parseNumber(driver.driverId);
        if (numeric != null && numeric >= maxId) maxId = numeric + 1;
      } catch (_) {}
    }

    if (drivers.isNotEmpty) {
      DriverRegistryService.instance.applyPersistedDrivers(
        drivers,
        nextId: maxId,
      );
      await DriverPersistenceService.instance.saveRegistryFromService(
        pushCloud: false,
        notifyStaff: false,
      );
    }
  }

  Future<void> _pullEmployeeRegistry() async {
    final rows = await _schoolRead(AppCollections.employeeRegistry);
    if (rows.isEmpty) return;

    final employees = <EmployeeRecord>[];
    var maxId = EmployeeRegistryService.instance.nextEmployeeIdCounter;

    for (final map in rows) {
      try {
        final employee = EmployeeRecord.fromMap(map);
        employees.add(employee);
        final numeric = ShortRegistryId.parseNumber(employee.employeeId);
        if (numeric != null && numeric >= maxId) maxId = numeric + 1;
      } catch (_) {}
    }

    if (employees.isNotEmpty) {
      EmployeeRegistryService.instance.applyPersistedEmployees(
        employees,
        nextId: maxId,
      );
      await EmployeePersistenceService.instance.saveRegistryFromService(
        pushCloud: false,
        notifyStaff: false,
      );
    }
  }

  Future<void> _pullStudentMedical() async {
    final rows = await _scopedStudentIdRead(AppCollections.studentMedical);
    for (final map in rows) {
      final studentId = (map['studentId'] as String?)?.toUpperCase();
      if (studentId == null) continue;
      final record = StudentRegistryService.instance.lookupById(studentId);
      if (record == null) continue;

      final updated = record.copyWith(
        hasMedicalCondition: map['hasMedicalCondition'] as bool? ?? false,
        medicalConditionDetails: map['medicalConditionDetails'] as String?,
        otherMedicalInfo: map['otherMedicalInfo'] as String?,
      );
      StudentRegistryService.instance.updateStudent(updated);
      await StudentPersistenceService.instance.saveMedicalForStudent(
        updated,
        pushCloud: false,
      );
    }
  }

  Future<void> _pullGradeReports() async {
    final role = AuthService.currentUser?.roleKey;
    List<Map<String, dynamic>> rows;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      rows = await _scopedStudentIdRead(AppCollections.gradeReports);
      if (rows.isEmpty) {
        rows = await _scopedClassRead(AppCollections.gradeReports);
      }
    } else if (role == AuthService.roleTeacher) {
      rows = await _scopedClassRead(AppCollections.gradeReports);
    } else {
      rows = await _schoolRead(AppCollections.gradeReports);
    }
    if (rows.isEmpty) return;

    final parsed = <StudentGradeReport>[];
    for (final map in rows) {
      try {
        parsed.add(StudentGradeReport.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedGradeReports(parsed);
      await GradePersistenceService.instance.saveFromService(pushCloud: false);
    }
  }

  Future<void> _pullHomework() async {
    final rows = await _scopedClassRead(AppCollections.homework);
    if (rows.isEmpty) return;

    final parsed = <HomeworkItem>[];
    for (final map in rows) {
      try {
        parsed.add(HomeworkItemPersistence.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedHomework(parsed);
      await HomeworkPersistenceService.instance.saveFromService(pushCloud: false);
    }
  }

  Future<void> _pullLearningMaterials() async {
    final rows = await _scopedClassRead(AppCollections.learningMaterials);
    if (rows.isNotEmpty) {
      final parsed = <LearningMaterialItem>[];
      for (final map in rows) {
        try {
          parsed.add(LearningMaterialItemPersistence.fromMap(map));
        } catch (_) {}
      }
      if (parsed.isNotEmpty) {
        SchoolDataService.instance.applyPersistedLearningMaterials(parsed);
        await LearningMaterialsPersistenceService.instance.saveFromService(
          pushCloud: false,
        );
      }
    }
    SchoolDataService.instance.ensureSampleLearningMaterials();
  }

  Future<void> _pullGradeAuditLog() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return;
    }
    final rows = role == AuthService.roleTeacher
        ? await _scopedClassRead(AppCollections.gradeAuditLog)
        : await _schoolRead(AppCollections.gradeAuditLog);
    if (rows.isEmpty) return;

    final parsed = <GradeAuditEntry>[];
    for (final map in rows) {
      try {
        parsed.add(GradeAuditEntry.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      GradeAuditService.instance.applyPersistedEntries(parsed);
      await GradeAuditPersistenceService.instance.saveFromService(
        pushCloud: false,
      );
    }
  }

  Future<void> _pullDailyActivities() async {
    final role = AuthService.currentUser?.roleKey;
    final rows = role == AuthService.roleTeacher
        ? await _scopedClassRead(AppCollections.dailyActivities)
        : await _scopedStudentIdRead(AppCollections.dailyActivities);
    if (rows.isEmpty) return;

    final parsed = <DailyActivityReport>[];
    for (final map in rows) {
      try {
        parsed.add(DailyActivityReport.fromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedDailyActivities(parsed);
      await DailyActivityPersistenceService.instance.saveFromService(
        pushCloud: false,
      );
    }
  }

  Future<void> _pullConversations() async {
    // Parent visibility is enforced by RLS (`app_doc_parent_conversation_visible`)
    // and then again by MessagingAccessService.canView. Do not pre-filter by
    // linkedStudentIds — username-only threads (and empty linked-student arrays)
    // would never download, so parents would never see teacher messages.
    final rows = await _schoolRead(AppCollections.conversations);
    if (rows.isEmpty) return;

    final parsed = <Conversation>[];
    for (final map in rows) {
      try {
        parsed.add(ConversationDocument.fromMap(map).toConversation());
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      SchoolDataService.instance.applyPersistedConversations(parsed);
      await MessagePersistenceService.instance.saveFromService(pushCloud: false);
    }
  }

  static String _gradeDocId(StudentGradeReport report) =>
      _gradeDocIdFromMap(report.toMap());

  static String _gradeDocIdFromMap(Map<String, dynamic> map) {
    final studentId = map['studentId'] as String? ?? '';
    final className = map['className'] as String? ?? '';
    final term = map['term'] as String? ?? '';
    return '${studentId}_${className}_$term'
        .replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
  }

  // —— Push: school content ——

  Future<void> pushAllSchoolContent() async {
    await pushAllFees();
    await pushAllCalendarEvents();
    await pushAllGalleryPosts();
    await pushAllQrScans();
    await pushAllAnnouncements();
    await pushAllAttendanceSessions();
    await pushAllClassTimetables();
  }

  Future<void> pushAllFees() async {
    final fees = SchoolDataService.instance.feesSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.fees,
          items: fees.map(AppDataMaps.feeToMap).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> pushAllCalendarEvents() async {
    final events = SchoolDataService.instance.calendarSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.calendarEvents,
          items: events.map(AppDataMaps.calendarEventToMap).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> pushAllGalleryPosts() async {
    final posts = SchoolDataService.instance.gallerySnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.galleryPosts,
          items: posts.map(AppDataMaps.galleryPostToMap).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> pushAllQrScans() async {
    final scans = SchoolDataService.instance.qrScanSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.qrScans,
          items: scans.map(AppDataMaps.qrScanToMap).toList(),
          docIdFor: (item) =>
              AppDataMaps.qrScanDocId(AppDataMaps.qrScanFromMap(item)),
        ));
  }

  Future<void> pushAllAnnouncements() async {
    final items = SchoolDataService.instance.announcementsSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.announcements,
          items: items.map(AppDataMaps.announcementToMap).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> pushAllAttendanceSessions() async {
    final sessions = SchoolDataService.instance.attendanceSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.attendanceSessions,
          items: sessions.map(AppDataMaps.attendanceSessionToMap).toList(),
          docIdFor: (item) => AppDataMaps.attendanceDocId(
            AppDataMaps.attendanceSessionFromMap(item),
          ),
        ));
  }

  Future<void> pushAllClassTimetables() async {
    final timetables = TimetableService.instance.allPersistedTimetables();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.classTimetables,
          items: timetables.map(AppDataMaps.classTimetableToMap).toList(),
          docIdFor: (item) => _classTimetableDocId(
            item['className'] as String? ?? '',
          ),
        ));
  }

  static String _classTimetableDocId(String className) =>
      className.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

  Future<void> pushAllSchools({bool ignoreActiveFilter = false}) async {
    var schools = SchoolRegistryService.instance.allSchoolsSnapshot();
    if (!ignoreActiveFilter) {
      final active = AuthService.activeSchoolId?.trim().toUpperCase();
      if (active != null && active.isNotEmpty) {
        schools = schools
            .where((s) => s.id.trim().toUpperCase() == active)
            .toList();
      }
    }
    if (schools.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.schoolRegistry,
          items: schools
              .map((s) => {
                    ...AppDataMaps.schoolToMap(s),
                    'schoolId': s.id,
                  })
              .toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  /// Push one school registry doc with correct school_id (platform create).
  Future<void> pushSchool(SchoolRecord school) async {
    final id = school.id.trim().toUpperCase();
    if (id.isEmpty) return;
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.schoolRegistry,
          docId: id,
          data: {
            ...AppDataMaps.schoolToMap(school),
            'id': id,
            'schoolId': id,
          },
          merge: true,
        ));
  }

  Future<void> pushAllAuditEntries() async {
    final entries = PlatformAuditLogService.instance.allEntriesSnapshot();
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.platformAudit,
          items: entries.map(AppDataMaps.auditEntryToMap).toList(),
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> deleteFee(String id) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.fees,
          docId: id,
        ));
  }

  Future<void> deleteCalendarEvent(String id) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.calendarEvents,
          docId: id,
        ));
  }

  Future<void> deleteGalleryPost(String id) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.galleryPosts,
          docId: id,
        ));
  }

  Future<void> deleteAnnouncement(String id) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.announcements,
          docId: id,
        ));
  }

  Future<void> deleteSchool(String schoolId) async {
    await _pushSafe(() => _crud.deleteDoc(
          collection: AppCollections.schoolRegistry,
          docId: schoolId,
        ));
  }

  // —— Transport: scans, onboard state, bus GPS ——

  Future<void> pushTransportScan(TransportScanRecord scan) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.transportScans,
          docId: AppDataMaps.transportScanDocId(scan),
          data: AppDataMaps.transportScanToMap(scan),
        ));
  }

  Future<void> pushTransportPassengerStatus({
    required String studentId,
    required String driverId,
    required TransportPassengerStatus status,
    required DateTime updatedAt,
    String? updatedBy,
  }) async {
    final id = studentId.trim().toUpperCase();
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.transportPassengerStatus,
          docId: id,
          data: AppDataMaps.transportPassengerStatusToMap(
            studentId: id,
            driverId: driverId.trim().toUpperCase(),
            status: status,
            updatedAt: updatedAt,
            updatedBy: updatedBy,
          ),
        ));
  }

  Future<void> pushBusPosition(BusLivePosition position) async {
    final id = position.driverId.trim().toUpperCase();
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.busLivePositions,
          docId: id,
          data: AppDataMaps.busPositionToMap(position),
        ));
  }

  Future<void> pushAppNotification(AppNotification notification) async {
    await _pushSafe(() => _crud.createOrUpdate(
          collection: AppCollections.appNotifications,
          docId: notification.id,
          data: AppDataMaps.appNotificationToMap(notification),
        ));
  }

  Future<void> pullTransportStateIntoServices() async {
    if (!available) return;
    await _prepareCloudRead();
    await _pullTransportPassengerStatus();
    await _pullTransportScans();
    await _pullBusLivePositions();
    await _pullAppNotifications();
  }

  Future<void> _pullBusLivePositions() async {
    final rows = await _schoolRead(AppCollections.busLivePositions);
    for (final map in rows) {
      try {
        BusLiveLocationService.instance.applyCloudPosition(
          AppDataMaps.busPositionFromMap(map),
        );
      } catch (_) {}
    }
  }

  Future<void> _pullTransportPassengerStatus() async {
    final rows =
        await _scopedStudentIdRead(AppCollections.transportPassengerStatus);
    for (final map in rows) {
      try {
        final studentId = (map['studentId'] as String? ?? '').toUpperCase();
        if (studentId.isEmpty) continue;
        final status = AppDataMaps.transportPassengerStatusFromName(
          map['status'] as String?,
        );
        TransportService.instance.applyCloudPassengerStatus(studentId, status);
      } catch (_) {}
    }
  }

  Future<void> _pullTransportScans() async {
    final rows = await _scopedStudentIdRead(AppCollections.transportScans);
    if (rows.isEmpty) return;
    final parsed = <TransportScanRecord>[];
    for (final map in rows) {
      try {
        parsed.add(AppDataMaps.transportScanFromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      TransportService.instance.applyCloudScanHistory(parsed);
    }
  }

  Future<void> _pullAppNotifications() async {
    final rows = await _schoolRead(AppCollections.appNotifications);
    if (rows.isEmpty) return;
    final parsed = <AppNotification>[];
    for (final map in rows) {
      try {
        parsed.add(AppDataMaps.appNotificationFromMap(map));
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      NotificationService.instance.applyCloudNotifications(parsed);
    }
  }

  // —— Pull: school content ——

  Future<void> _pullAnnouncements() async {
    final rows = await _schoolRead(AppCollections.announcements);
    if (rows.isEmpty) return;
    final parsed = rows.map(AppDataMaps.announcementFromMap).toList();
    var maxId = SchoolDataService.instance.announcementNextIdSnapshot();
    for (final a in parsed) {
      final n = int.tryParse(a.id);
      if (n != null && n >= maxId) maxId = n + 1;
    }
    SchoolDataService.instance.applyPersistedAnnouncements(parsed, nextId: maxId);
    await SchoolContentPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullAttendanceSessions() async {
    final rows = await _scopedClassRead(AppCollections.attendanceSessions);
    if (rows.isEmpty) return;
    final parsed = rows.map(AppDataMaps.attendanceSessionFromMap).toList();
    SchoolDataService.instance.applyPersistedAttendance(parsed);
    await SchoolContentPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullFees() async {
    final role = AuthService.currentUser?.roleKey;
    List<Map<String, dynamic>> rows;
    if (role == AuthService.roleParent) {
      rows = await _schoolRead(
        AppCollections.fees,
        whereInField: 'studentId',
        whereInValues: AuthService.activeLinkedStudentIds(),
      );
      if (rows.isEmpty && AuthService.cloudLinkedStudentNames.isNotEmpty) {
        rows = await _schoolRead(
          AppCollections.fees,
          whereInField: 'studentName',
          whereInValues: AuthService.cloudLinkedStudentNames,
        );
      }
    } else if (role == AuthService.roleTeacher) {
      rows = await _scopedClassRead(AppCollections.fees);
    } else {
      rows = await _schoolRead(AppCollections.fees);
    }
    if (rows.isEmpty) return;
    final parsed = rows.map(AppDataMaps.feeFromMap).toList();
    SchoolDataService.instance.applyPersistedFees(parsed);
    await SchoolContentPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullCalendarEvents() async {
    final rows = await _schoolRead(AppCollections.calendarEvents);
    if (rows.isEmpty) return;
    final parsed = rows.map(AppDataMaps.calendarEventFromMap).toList();
    var maxId = SchoolDataService.instance.calendarNextIdSnapshot();
    for (final e in parsed) {
      final n = int.tryParse(e.id.replaceAll(RegExp(r'\D'), ''));
      if (n != null && n >= maxId) maxId = n + 1;
    }
    SchoolDataService.instance.applyPersistedCalendar(parsed, nextId: maxId);
    await SchoolContentPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullClassTimetables() async {
    final rows = await _scopedClassRead(AppCollections.classTimetables);
    if (rows.isEmpty) return;
    final parsed = <ClassTimetable>[];
    for (final map in rows) {
      try {
        parsed.add(AppDataMaps.classTimetableFromMap(map));
      } catch (_) {}
    }
    if (parsed.isEmpty) return;
    TimetableService.instance.applyPersistedTimetables(parsed);
    await TimetablePersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullGalleryPosts() async {
    final rows = await _schoolRead(AppCollections.galleryPosts);
    if (rows.isEmpty) return;
    final parsed = rows.map(AppDataMaps.galleryPostFromMap).toList();
    SchoolDataService.instance.applyPersistedGallery(parsed);
    await SchoolContentPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullQrScans() async {
    final rows = await _schoolRead(AppCollections.qrScans);
    if (rows.isEmpty) return;
    final parsed = rows.map(AppDataMaps.qrScanFromMap).toList();
    SchoolDataService.instance.applyPersistedQrScans(parsed);
    await SchoolContentPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullSchoolRegistry() async {
    final sid = AuthService.activeSchoolId?.trim();
    if (sid == null || sid.isEmpty) return;
    final map = await _crud.readDoc(
      collection: AppCollections.schoolRegistry,
      docId: sid,
    );
    if (map == null) return;
    final parsed = AppDataMaps.schoolFromMap({...map, 'id': sid, '_docId': sid});
    // Merge — never wipe the full multi-school registry used by platform console.
    SchoolRegistryService.instance.upsertSchool(parsed);
    await SchoolRegistryPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullPlatformAudit() async {
    final rows = await _schoolRead(AppCollections.platformAudit);
    if (rows.isEmpty) return;
    final parsed = <PlatformAuditEntry>[];
    var maxId = PlatformAuditLogService.instance.nextIdSnapshot();
    for (final map in rows) {
      try {
        final entry = AppDataMaps.auditEntryFromMap(map);
        parsed.add(entry);
        final n = int.tryParse(entry.id.replaceAll('audit-', ''));
        if (n != null && n >= maxId) maxId = n + 1;
      } catch (_) {}
    }
    if (parsed.isNotEmpty) {
      PlatformAuditLogService.instance.applyPersistedEntries(
        parsed,
        nextId: maxId,
      );
      await PlatformAuditPersistenceService.instance.saveFromService(
        pushCloud: false,
      );
    }
  }

  Future<void> _pullInventory() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return;
    }
    final itemRows =
        await _schoolRead(AppCollections.inventoryItems);
    final txnRows =
        await _schoolRead(AppCollections.stockTransactions);
    final issuedRows =
        await _schoolRead(AppCollections.studentIssuedItems);
    final classroomRows =
        await _schoolRead(AppCollections.classroomInventory);
    final assetRows = await _schoolRead(AppCollections.assets);
    final supplierRows =
        await _schoolRead(AppCollections.suppliers);
    final maintenanceRows =
        await _schoolRead(AppCollections.maintenanceReports);

    if (itemRows.isEmpty &&
        txnRows.isEmpty &&
        issuedRows.isEmpty &&
        classroomRows.isEmpty &&
        assetRows.isEmpty &&
        supplierRows.isEmpty &&
        maintenanceRows.isEmpty) {
      return;
    }

    final items = <InventoryItem>[];
    for (final map in itemRows) {
      try {
        items.add(InventoryItem.fromMap(map));
      } catch (_) {}
    }
    final txns = <StockTransaction>[];
    for (final map in txnRows) {
      try {
        txns.add(StockTransaction.fromMap(map));
      } catch (_) {}
    }
    final issued = <StudentIssuedItem>[];
    for (final map in issuedRows) {
      try {
        issued.add(StudentIssuedItem.fromMap(map));
      } catch (_) {}
    }
    final classroom = <ClassroomInventoryEntry>[];
    for (final map in classroomRows) {
      try {
        classroom.add(ClassroomInventoryEntry.fromMap(map));
      } catch (_) {}
    }
    final assets = <SchoolAsset>[];
    for (final map in assetRows) {
      try {
        assets.add(SchoolAsset.fromMap(map));
      } catch (_) {}
    }
    final suppliers = <InventorySupplier>[];
    for (final map in supplierRows) {
      try {
        suppliers.add(InventorySupplier.fromMap(map));
      } catch (_) {}
    }
    final maintenance = <InventoryMaintenanceReport>[];
    for (final map in maintenanceRows) {
      try {
        maintenance.add(InventoryMaintenanceReport.fromMap(map));
      } catch (_) {}
    }

    InventoryService.instance.applyPersistedData(
      items: items,
      transactions: txns,
      studentIssued: issued,
      classroom: classroom,
      assets: assets,
      suppliers: suppliers,
      maintenance: maintenance,
    );
    await InventoryPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullProcurement() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return;
    }
    final purchaseRows = await _schoolRead(AppCollections.purchaseRequests);
    final issueRows = await _schoolRead(AppCollections.issueRequests);
    if (purchaseRows.isEmpty && issueRows.isEmpty) return;

    final purchases = <PurchaseRequest>[];
    for (final map in purchaseRows) {
      try {
        purchases.add(PurchaseRequest.fromMap(map));
      } catch (_) {}
    }
    final issues = <IssueRequest>[];
    for (final map in issueRows) {
      try {
        issues.add(IssueRequest.fromMap(map));
      } catch (_) {}
    }
    ProcurementService.instance.applyPersistedData(
      purchases: purchases,
      issues: issues,
    );
    await ProcurementPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  Future<void> _pullDisciplineCases() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleStudent || role == AuthService.roleDriver) {
      return;
    }
    final rows = role == AuthService.roleParent
        ? await _scopedStudentIdRead(AppCollections.disciplineCases)
        : await _schoolRead(AppCollections.disciplineCases);
    if (rows.isEmpty) return;
    final cases = <DisciplineCase>[];
    for (final map in rows) {
      try {
        cases.add(DisciplineCase.fromMap(map));
      } catch (_) {}
    }
    if (cases.isEmpty) return;
    DisciplineService.instance.applyPersistedData(cases, merge: true);
    await DisciplinePersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  Future<void> _pullLeaveRequests() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleStudent || role == AuthService.roleDriver) {
      return;
    }
    final rows = role == AuthService.roleParent
        ? await _scopedStudentIdRead(AppCollections.leaveRequests)
        : await _schoolRead(AppCollections.leaveRequests);
    if (rows.isEmpty) return;
    final requests = <LeaveRequest>[];
    for (final map in rows) {
      try {
        requests.add(LeaveRequest.fromMap(map));
      } catch (_) {}
    }
    if (requests.isEmpty) return;
    LeaveRequestService.instance.applyPersistedData(requests, merge: true);
    await LeaveRequestPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  /// Admissions applications — staff/admin only.
  Future<void> _pullAdmissionApplications() async {
    final role = AuthService.currentUser?.roleKey;
    if (role != AuthService.roleAdmin && role != AuthService.roleTeacher) {
      return;
    }
    final rows = await _schoolRead(AppCollections.admissionApplications);
    if (rows.isEmpty) return;
    final items = <AdmissionApplication>[];
    for (final map in rows) {
      try {
        items.add(AdmissionApplication.fromMap(map));
      } catch (_) {}
    }
    if (items.isEmpty) return;
    AdmissionService.instance.applyPersistedData(items, merge: true);
    await AdmissionPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  /// Exam bank, papers, and attempts. Students pull all three so they can
  /// sit published papers; parents/drivers never receive the bank.
  Future<void> _pullExamBank() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleDriver) {
      return;
    }
    final questionRows = await _schoolRead(AppCollections.examQuestions);
    final paperRows = await _schoolRead(AppCollections.examPapers);
    final attemptRows = await _schoolRead(AppCollections.examAttempts);
    if (questionRows.isEmpty && paperRows.isEmpty && attemptRows.isEmpty) {
      return;
    }
    final questions = <ExamQuestion>[];
    for (final map in questionRows) {
      try {
        questions.add(ExamQuestion.fromMap(map));
      } catch (_) {}
    }
    final papers = <ExamPaper>[];
    for (final map in paperRows) {
      try {
        papers.add(ExamPaper.fromMap(map));
      } catch (_) {}
    }
    final attempts = <ExamAttempt>[];
    for (final map in attemptRows) {
      try {
        attempts.add(ExamAttempt.fromMap(map));
      } catch (_) {}
    }
    if (questions.isEmpty && papers.isEmpty && attempts.isEmpty) return;
    ExamService.instance.applyPersistedData(
      questions: questions.isEmpty ? null : questions,
      papers: papers.isEmpty ? null : papers,
      attempts: attempts.isEmpty ? null : attempts,
      merge: true,
    );
    await ExamPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullLessonPlans() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleDriver) {
      return;
    }
    final rows = await _scopedClassRead(AppCollections.lessonPlans);
    if (rows.isEmpty) return;
    final plans = <LessonPlan>[];
    for (final map in rows) {
      try {
        plans.add(LessonPlan.fromMap(map));
      } catch (_) {}
    }
    if (plans.isEmpty) return;
    LessonPlanService.instance.applyPersistedData(plans, merge: true);
    await LessonPlanPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  /// Curriculum office. Students/parents receive published units + own
  /// feedback only — never reviews, evaluations, or meeting notes.
  Future<void> _pullCurriculumOffice() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleDriver) return;
    final unitRows = await _schoolRead(AppCollections.curriculumUnits);
    final feedbackRows = await _schoolRead(AppCollections.curriculumFeedback);
    final publicReader = role == AuthService.roleStudent ||
        role == AuthService.roleParent;
    final reviewRows = publicReader
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.lessonPlanReviews);
    final evalRows = publicReader
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.teacherEvaluations);
    final meetingRows = publicReader
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.academicMeetings);
    if (unitRows.isEmpty &&
        feedbackRows.isEmpty &&
        reviewRows.isEmpty &&
        evalRows.isEmpty &&
        meetingRows.isEmpty) {
      return;
    }
    final units = <CurriculumUnit>[];
    for (final map in unitRows) {
      try {
        units.add(CurriculumUnit.fromMap(map));
      } catch (_) {}
    }
    final feedback = <CurriculumFeedback>[];
    for (final map in feedbackRows) {
      try {
        feedback.add(CurriculumFeedback.fromMap(map));
      } catch (_) {}
    }
    final reviews = <LessonPlanReview>[];
    for (final map in reviewRows) {
      try {
        reviews.add(LessonPlanReview.fromMap(map));
      } catch (_) {}
    }
    final evals = <TeacherEvaluation>[];
    for (final map in evalRows) {
      try {
        evals.add(TeacherEvaluation.fromMap(map));
      } catch (_) {}
    }
    final meetings = <AcademicMeeting>[];
    for (final map in meetingRows) {
      try {
        meetings.add(AcademicMeeting.fromMap(map));
      } catch (_) {}
    }
    if (units.isEmpty &&
        feedback.isEmpty &&
        reviews.isEmpty &&
        evals.isEmpty &&
        meetings.isEmpty) {
      return;
    }
    CurriculumService.instance.applyPersistedData(
      units: units.isEmpty ? null : units,
      feedback: feedback.isEmpty ? null : feedback,
      reviews: publicReader ? const [] : (reviews.isEmpty ? null : reviews),
      evaluations: publicReader ? const [] : (evals.isEmpty ? null : evals),
      meetings: publicReader ? const [] : (meetings.isEmpty ? null : meetings),
      merge: true,
    );
    await CurriculumPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  /// Staff write care files via writeBatch. Parents/students file
  /// [support_requests] through school-upsert-registry. Safeguarding never
  /// leaves the care-leadership desk.
  Future<void> pushAllStudentSupport() async {
    final svc = StudentSupportService.instance;
    final role = AuthService.currentUser?.roleKey;
    final publicReader = role == AuthService.roleStudent ||
        role == AuthService.roleParent;
    if (!publicReader) {
      Future<void> pushStaff(String collection, List<Map<String, dynamic>> items) async {
        if (items.isEmpty) return;
        await _pushSafe(() => _crud.writeBatch(
              collection: collection,
              items: items,
              docIdFor: (item) => item['id'] as String,
            ));
      }

      await pushStaff(AppCollections.healthRecords, svc.healthMaps());
      await pushStaff(AppCollections.counselingRecords, svc.counselingMaps());
      await pushStaff(AppCollections.iepPlans, svc.iepMaps());
      await pushStaff(AppCollections.collegeGuidance, svc.collegeMaps());
      if (role == AuthService.roleAdmin ||
          role == AuthService.roleTeacher) {
        await pushStaff(
          AppCollections.safeguardingCases,
          svc.safeguardingMaps(),
        );
      }
    }
    final requests = svc.requestMaps();
    if (requests.isEmpty) return;
    await _pushSafe(() async {
      final result = await SchoolAuthCloudService.instance.upsertRegistryBatch(
        collection: AppCollections.supportRequests,
        records: requests,
      );
      if (!result.ok) {
        throw StateError(
          result.errorMessage ?? 'Student-support request sync failed.',
        );
      }
    });
  }

  /// Health / counseling / IEP / college / requests. Child-protection files
  /// are never pulled for parents, students, or drivers.
  Future<void> _pullStudentSupport() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleDriver) return;

    final parent = role == AuthService.roleParent;
    final student = role == AuthService.roleStudent;
    final publicReader = parent || student;

    final healthRows = student
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.healthRecords);
    final counselingRows = student
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.counselingRecords);
    final iepRows = student
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.iepPlans);
    final collegeRows = await _schoolRead(AppCollections.collegeGuidance);
    final requestRows = await _schoolRead(AppCollections.supportRequests);
    final safeguardingRows = publicReader
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.safeguardingCases);

    if (healthRows.isEmpty &&
        counselingRows.isEmpty &&
        iepRows.isEmpty &&
        collegeRows.isEmpty &&
        requestRows.isEmpty &&
        safeguardingRows.isEmpty) {
      return;
    }

    final health = <HealthRecord>[];
    for (final map in healthRows) {
      try {
        health.add(HealthRecord.fromMap(map));
      } catch (_) {}
    }
    final counseling = <CounselingRecord>[];
    for (final map in counselingRows) {
      try {
        counseling.add(CounselingRecord.fromMap(map));
      } catch (_) {}
    }
    final iep = <IepPlan>[];
    for (final map in iepRows) {
      try {
        iep.add(IepPlan.fromMap(map));
      } catch (_) {}
    }
    final college = <CollegeGuidancePlan>[];
    for (final map in collegeRows) {
      try {
        college.add(CollegeGuidancePlan.fromMap(map));
      } catch (_) {}
    }
    final requests = <SupportRequest>[];
    for (final map in requestRows) {
      try {
        requests.add(SupportRequest.fromMap(map));
      } catch (_) {}
    }
    final safeguarding = <SafeguardingCase>[];
    for (final map in safeguardingRows) {
      try {
        safeguarding.add(SafeguardingCase.fromMap(map));
      } catch (_) {}
    }

    if (health.isEmpty &&
        counseling.isEmpty &&
        iep.isEmpty &&
        college.isEmpty &&
        requests.isEmpty &&
        safeguarding.isEmpty) {
      return;
    }

    StudentSupportService.instance.applyPersistedData(
      health: health.isEmpty ? null : health,
      counseling: counseling.isEmpty ? null : counseling,
      iep: iep.isEmpty ? null : iep,
      college: college.isEmpty ? null : college,
      requests: requests.isEmpty ? null : requests,
      safeguarding:
          publicReader ? const [] : (safeguarding.isEmpty ? null : safeguarding),
      merge: true,
    );
    await StudentSupportPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  /// Staff write clubs / internships / meetings. Memberships, scholarships,
  /// and grievances use upsert so students and parents can apply.
  Future<void> pushAllDosa() async {
    final svc = DosaService.instance;
    final role = AuthService.currentUser?.roleKey;
    final publicReader = role == AuthService.roleStudent ||
        role == AuthService.roleParent;
    if (!publicReader) {
      Future<void> pushStaff(
        String collection,
        List<Map<String, dynamic>> items,
      ) async {
        if (items.isEmpty) return;
        await _pushSafe(() => _crud.writeBatch(
              collection: collection,
              items: items,
              docIdFor: (item) => item['id'] as String,
            ));
      }

      await pushStaff(AppCollections.extracurricularClubs, svc.clubMaps());
      await pushStaff(AppCollections.internships, svc.internshipMaps());
      await pushStaff(AppCollections.dosaMeetings, svc.meetingMaps());
    }

    Future<void> upsertPublic(
      String collection,
      List<Map<String, dynamic>> items,
    ) async {
      if (items.isEmpty) return;
      await _pushSafe(() async {
        final result = await SchoolAuthCloudService.instance.upsertRegistryBatch(
          collection: collection,
          records: items,
        );
        if (!result.ok) {
          throw StateError(
            result.errorMessage ?? 'Student-program sync failed.',
          );
        }
      });
    }

    await upsertPublic(AppCollections.clubMemberships, svc.membershipMaps());
    await upsertPublic(AppCollections.scholarships, svc.scholarshipMaps());
    await upsertPublic(AppCollections.grievances, svc.grievanceMaps());
  }

  Future<void> _pullDosa() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleDriver) return;

    final clubRows = await _schoolRead(AppCollections.extracurricularClubs);
    final membershipRows = await _schoolRead(AppCollections.clubMemberships);
    final scholarshipRows = await _schoolRead(AppCollections.scholarships);
    final grievanceRows = await _schoolRead(AppCollections.grievances);
    final internshipRows = await _schoolRead(AppCollections.internships);
    final meetingRows = await _schoolRead(AppCollections.dosaMeetings);

    if (clubRows.isEmpty &&
        membershipRows.isEmpty &&
        scholarshipRows.isEmpty &&
        grievanceRows.isEmpty &&
        internshipRows.isEmpty &&
        meetingRows.isEmpty) {
      return;
    }

    final clubs = <ExtracurricularClub>[];
    for (final map in clubRows) {
      try {
        clubs.add(ExtracurricularClub.fromMap(map));
      } catch (_) {}
    }
    final memberships = <ClubMembership>[];
    for (final map in membershipRows) {
      try {
        memberships.add(ClubMembership.fromMap(map));
      } catch (_) {}
    }
    final scholarships = <ScholarshipRecord>[];
    for (final map in scholarshipRows) {
      try {
        scholarships.add(ScholarshipRecord.fromMap(map));
      } catch (_) {}
    }
    final grievances = <Grievance>[];
    for (final map in grievanceRows) {
      try {
        grievances.add(Grievance.fromMap(map));
      } catch (_) {}
    }
    final internships = <Internship>[];
    for (final map in internshipRows) {
      try {
        internships.add(Internship.fromMap(map));
      } catch (_) {}
    }
    final meetings = <DosaMeeting>[];
    for (final map in meetingRows) {
      try {
        meetings.add(DosaMeeting.fromMap(map));
      } catch (_) {}
    }

    if (clubs.isEmpty &&
        memberships.isEmpty &&
        scholarships.isEmpty &&
        grievances.isEmpty &&
        internships.isEmpty &&
        meetings.isEmpty) {
      return;
    }

    DosaService.instance.applyPersistedData(
      clubs: clubs.isEmpty ? null : clubs,
      memberships: memberships.isEmpty ? null : memberships,
      scholarships: scholarships.isEmpty ? null : scholarships,
      grievances: grievances.isEmpty ? null : grievances,
      internships: internships.isEmpty ? null : internships,
      meetings: meetings.isEmpty ? null : meetings,
      merge: true,
    );
    await DosaPersistenceService.instance.saveFromService(pushCloud: false);
  }

  /// Staff write observations / audits / surveys / research. Responses upsert
  /// so parents, students, and teachers can submit.
  Future<void> pushAllQaMonitor() async {
    final svc = QaMonitorService.instance;
    final role = AuthService.currentUser?.roleKey;
    final publicReader = role == AuthService.roleStudent ||
        role == AuthService.roleParent;
    if (!publicReader) {
      Future<void> pushStaff(
        String collection,
        List<Map<String, dynamic>> items,
      ) async {
        if (items.isEmpty) return;
        await _pushSafe(() => _crud.writeBatch(
              collection: collection,
              items: items,
              docIdFor: (item) => item['id'] as String,
            ));
      }

      await pushStaff(
        AppCollections.teachingObservations,
        svc.observationMaps(),
      );
      await pushStaff(AppCollections.academicAudits, svc.auditMaps());
      await pushStaff(AppCollections.qaSurveys, svc.surveyMaps());
      await pushStaff(AppCollections.actionResearch, svc.researchMaps());
    }

    if (svc.responseMaps().isEmpty) return;
    await _pushSafe(() async {
      final result = await SchoolAuthCloudService.instance.upsertRegistryBatch(
        collection: AppCollections.qaSurveyResponses,
        records: svc.responseMaps(),
      );
      if (!result.ok) {
        throw StateError(result.errorMessage ?? 'Survey response sync failed.');
      }
    });
  }

  Future<void> _pullQaMonitor() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleDriver) return;

    final observationRows =
        await _schoolRead(AppCollections.teachingObservations);
    final auditRows = await _schoolRead(AppCollections.academicAudits);
    final surveyRows = await _schoolRead(AppCollections.qaSurveys);
    final responseRows = await _schoolRead(AppCollections.qaSurveyResponses);
    final researchRows = await _schoolRead(AppCollections.actionResearch);

    if (observationRows.isEmpty &&
        auditRows.isEmpty &&
        surveyRows.isEmpty &&
        responseRows.isEmpty &&
        researchRows.isEmpty) {
      return;
    }

    final observations = <TeachingObservation>[];
    for (final map in observationRows) {
      try {
        observations.add(TeachingObservation.fromMap(map));
      } catch (_) {}
    }
    final audits = <AcademicAudit>[];
    for (final map in auditRows) {
      try {
        audits.add(AcademicAudit.fromMap(map));
      } catch (_) {}
    }
    final surveys = <QaSurvey>[];
    for (final map in surveyRows) {
      try {
        surveys.add(QaSurvey.fromMap(map));
      } catch (_) {}
    }
    final responses = <QaSurveyResponse>[];
    for (final map in responseRows) {
      try {
        responses.add(QaSurveyResponse.fromMap(map));
      } catch (_) {}
    }
    final research = <ActionResearch>[];
    for (final map in researchRows) {
      try {
        research.add(ActionResearch.fromMap(map));
      } catch (_) {}
    }

    if (observations.isEmpty &&
        audits.isEmpty &&
        surveys.isEmpty &&
        responses.isEmpty &&
        research.isEmpty) {
      return;
    }

    QaMonitorService.instance.applyPersistedData(
      observations: observations.isEmpty ? null : observations,
      audits: audits.isEmpty ? null : audits,
      surveys: surveys.isEmpty ? null : surveys,
      responses: responses.isEmpty ? null : responses,
      research: research.isEmpty ? null : research,
      merge: true,
    );
    await QaMonitorPersistenceService.instance.saveFromService(pushCloud: false);
  }

  /// MFA, consents, data-rights, school backup meta.
  Future<void> pullGoLive() => _pullGoLive();

  Future<void> pushAllGoLive() async {
    final svc = GoliveService.instance;
    final role = AuthService.currentUser?.roleKey;
    final publicReader = role == AuthService.roleStudent ||
        role == AuthService.roleParent;

    Future<void> upsert(String collection, List<Map<String, dynamic>> items) async {
      if (items.isEmpty) return;
      await _pushSafe(() async {
        final result = await SchoolAuthCloudService.instance.upsertRegistryBatch(
          collection: collection,
          records: items,
        );
        if (!result.ok) {
          throw StateError(result.errorMessage ?? 'Go-live sync failed.');
        }
      });
    }

    await upsert(AppCollections.mfaEnrollments, svc.mfaMaps(cloud: true));
    await upsert(AppCollections.privacyConsents, svc.consentMaps());
    await upsert(AppCollections.dataRightsRequests, svc.rightsMaps());

    if (publicReader) return;
    final backups = svc.backupMaps();
    if (backups.isEmpty) return;
    await _pushSafe(() => _crud.writeBatch(
          collection: AppCollections.schoolBackups,
          items: backups,
          docIdFor: (item) => item['id'] as String,
        ));
  }

  Future<void> _pullGoLive() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleDriver) return;

    final mfaRows = await _schoolRead(AppCollections.mfaEnrollments);
    final consentRows = await _schoolRead(AppCollections.privacyConsents);
    final rightsRows = await _schoolRead(AppCollections.dataRightsRequests);
    final backupRows = role == AuthService.roleParent ||
            role == AuthService.roleStudent
        ? const <Map<String, dynamic>>[]
        : await _schoolRead(AppCollections.schoolBackups);

    if (mfaRows.isEmpty &&
        consentRows.isEmpty &&
        rightsRows.isEmpty &&
        backupRows.isEmpty) {
      return;
    }

    final enrollments = <MfaEnrollment>[];
    for (final map in mfaRows) {
      try {
        enrollments.add(MfaEnrollment.fromMap(map));
      } catch (_) {}
    }
    final consents = <PrivacyConsent>[];
    for (final map in consentRows) {
      try {
        consents.add(PrivacyConsent.fromMap(map));
      } catch (_) {}
    }
    final rights = <DataRightsRequest>[];
    for (final map in rightsRows) {
      try {
        rights.add(DataRightsRequest.fromMap(map));
      } catch (_) {}
    }
    final backups = <SchoolBackupRecord>[];
    for (final map in backupRows) {
      try {
        backups.add(SchoolBackupRecord.fromMap(map));
      } catch (_) {}
    }

    if (enrollments.isEmpty &&
        consents.isEmpty &&
        rights.isEmpty &&
        backups.isEmpty) {
      return;
    }

    GoliveService.instance.applyPersistedData(
      enrollments: enrollments.isEmpty ? null : enrollments,
      consents: consents.isEmpty ? null : consents,
      rights: rights.isEmpty ? null : rights,
      backups: backups.isEmpty ? null : backups,
      merge: true,
    );
    await GolivePersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> pushAllDigitalOps() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent ||
        role == AuthService.roleStudent ||
        role == AuthService.roleDriver) {
      return;
    }
    final svc = DigitalOpsService.instance;
    Future<void> push(String collection, List<Map<String, dynamic>> items) async {
      if (items.isEmpty) return;
      await _pushSafe(() => _crud.writeBatch(
            collection: collection,
            items: items,
            docIdFor: (item) => item['id'] as String,
          ));
    }

    await push(AppCollections.ictDevices, svc.deviceMaps());
    await push(AppCollections.ictWeeklyReviews, svc.reviewMaps());
  }

  Future<void> _pullDigitalOps() async {
    final role = AuthService.currentUser?.roleKey;
    if (role != AuthService.roleAdmin && role != AuthService.roleTeacher) {
      return;
    }
    final deviceRows = await _schoolRead(AppCollections.ictDevices);
    final reviewRows = await _schoolRead(AppCollections.ictWeeklyReviews);
    if (deviceRows.isEmpty && reviewRows.isEmpty) return;

    final devices = <IctDeviceRecord>[];
    for (final map in deviceRows) {
      try {
        devices.add(IctDeviceRecord.fromMap(map));
      } catch (_) {}
    }
    final reviews = <IctWeeklyReview>[];
    for (final map in reviewRows) {
      try {
        reviews.add(IctWeeklyReview.fromMap(map));
      } catch (_) {}
    }
    if (devices.isEmpty && reviews.isEmpty) return;

    DigitalOpsService.instance.applyPersistedData(
      devices: devices.isEmpty ? null : devices,
      reviews: reviews.isEmpty ? null : reviews,
      merge: true,
    );
    await DigitalOpsPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  /// QA findings — staff-only register (parents/students never pull it).
  Future<void> _pullQaFindings() async {
    final role = AuthService.currentUser?.roleKey;
    if (role != AuthService.roleAdmin && role != AuthService.roleTeacher) {
      return;
    }
    final rows = await _schoolRead(AppCollections.qaFindings);
    if (rows.isEmpty) return;
    final findings = <QaFinding>[];
    for (final map in rows) {
      try {
        findings.add(QaFinding.fromMap(map));
      } catch (_) {}
    }
    if (findings.isEmpty) return;
    QaFindingsService.instance.applyPersistedData(findings, merge: true);
    await QaFindingsPersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  Future<void> _pullTransferRequests() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return;
    }
    final rows = await _schoolRead(AppCollections.transferRequests);
    if (rows.isEmpty) return;
    final requests = <TransferRequest>[];
    for (final map in rows) {
      try {
        requests.add(TransferRequest.fromMap(map));
      } catch (_) {}
    }
    TransferWorkflowService.instance.applyPersistedData(requests: requests);
    await TransferPersistenceService.instance.saveFromService(pushCloud: false);
  }

  Future<void> _pullMaterialPurchases() async {
    final rows = await _schoolRead(AppCollections.materialPurchaseRequests);
    if (rows.isEmpty) return;
    final requests = <MaterialPurchaseRequest>[];
    for (final map in rows) {
      try {
        requests.add(MaterialPurchaseRequest.fromMap(map));
      } catch (_) {}
    }
    MaterialPurchaseService.instance.applyPersisted(requests);
    await MaterialPurchasePersistenceService.instance.saveFromService(
      pushCloud: false,
    );
  }

  Future<void> _pullBuses() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent || role == AuthService.roleStudent) {
      return;
    }
    final rows = await _schoolRead(AppCollections.buses);
    if (rows.isEmpty) {
      BusRegistryService.instance.seedFromDriversIfEmpty();
      return;
    }
    final buses = <BusRecord>[];
    var maxId = BusRegistryService.instance.nextBusIdCounter;
    for (final map in rows) {
      try {
        final bus = BusRecord.fromMap(map);
        buses.add(bus);
        final n = int.tryParse(bus.busId.replaceAll(RegExp(r'\D'), '')) ?? 0;
        if (n >= maxId) maxId = n + 1;
      } catch (_) {}
    }
    if (buses.isNotEmpty) {
      BusRegistryService.instance.applyPersistedBuses(
        buses,
        nextId: maxId,
        replace: true,
      );
      await BusPersistenceService.instance.saveFromService(pushCloud: false);
    }
  }

  Future<void> _pullSchoolAudit() async {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleParent ||
        role == AuthService.roleStudent ||
        role == AuthService.roleDriver) {
      return;
    }
    final rows = await _schoolRead(AppCollections.schoolAuditLog);
    if (rows.isEmpty) return;
    final entries = <SchoolAuditEntry>[];
    for (final map in rows) {
      try {
        entries.add(SchoolAuditEntry.fromMap(map));
      } catch (_) {}
    }
    if (entries.isNotEmpty) {
      SchoolAuditLogService.instance.applyPersistedEntries(entries);
      await SchoolAuditPersistenceService.instance.saveFromService(
        pushCloud: false,
      );
    }
  }
}
