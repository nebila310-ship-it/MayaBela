import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/models/student_support_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/messaging_access_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/student_support_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/short_registry_id.dart';

/// Phase G student-support desk. Clinic, counseling, IEP, and college sit on
/// the care collections. [SafeguardingCase] files never leave the
/// care-leadership desk — not parents, students, classroom teachers, or QA.
class StudentSupportService extends ChangeNotifier {
  StudentSupportService._();
  static final instance = StudentSupportService._();

  final List<HealthRecord> _health = [];
  final List<CounselingRecord> _counseling = [];
  final List<IepPlan> _iep = [];
  final List<CollegeGuidancePlan> _college = [];
  final List<SupportRequest> _requests = [];
  final List<SafeguardingCase> _safeguarding = [];
  final List<StudentDocument> _documents = [];
  final List<MedicationStockItem> _meds = [];
  final List<SelObservation> _sel = [];
  bool _loaded = false;

  @visibleForTesting
  static void resetForTests() {
    instance._health.clear();
    instance._counseling.clear();
    instance._iep.clear();
    instance._college.clear();
    instance._requests.clear();
    instance._safeguarding.clear();
    instance._documents.clear();
    instance._meds.clear();
    instance._sel.clear();
    instance._loaded = true;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await StudentSupportPersistenceService.instance.loadIntoService();
  }

  String get _schoolId =>
      (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
          .trim()
          .toUpperCase();

  String get _username => AuthService.currentUser?.username ?? '';

  bool get _isStudent =>
      AuthService.currentUser?.roleKey == AuthService.roleStudent;
  bool get _isParent =>
      AuthService.currentUser?.roleKey == AuthService.roleParent;
  bool get _isPublicReader => _isStudent || _isParent;

  bool get canManageDesk => ModuleAccess.canManage('student_affairs');
  bool get canViewDesk => ModuleAccess.canView('student_affairs');
  bool get canViewSafeguarding => ModuleAccess.canView('safeguarding');
  bool get canManageSafeguarding => ModuleAccess.canManage('safeguarding');

  List<HealthRecord> healthForSchool([String? schoolId]) {
    var list = _schoolFilter(_health, schoolId);
    if (_isStudent) return const [];
    if (_isParent) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicHealth)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<CounselingRecord> counselingForSchool([String? schoolId]) {
    var list = _schoolFilter(_counseling, schoolId);
    if (_isStudent) return const [];
    if (_isParent) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicCounseling)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<IepPlan> iepForSchool([String? schoolId]) {
    var list = _schoolFilter(_iep, schoolId);
    if (_isStudent) return const [];
    if (_isParent) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicIep)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<CollegeGuidancePlan> collegeForSchool([String? schoolId]) {
    var list = _schoolFilter(_college, schoolId);
    if (_isPublicReader) {
      list = list
          .where((row) => _ownsStudent(row.studentId))
          .map(_publicCollege)
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<SupportRequest> requestsForSchool([String? schoolId]) {
    var list = _schoolFilter(_requests, schoolId);
    if (_isPublicReader) {
      final uname = _username.trim().toLowerCase();
      list = list
          .where(
            (row) =>
                _ownsStudent(row.studentId) ||
                (uname.isNotEmpty &&
                    row.authorUsername.trim().toLowerCase() == uname),
          )
          .toList();
    }
    return list..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  List<SafeguardingCase> safeguardingForSchool([String? schoolId]) {
    if (!canViewSafeguarding) return const [];
    return _schoolFilter(_safeguarding, schoolId)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<HealthRecord> healthForStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    return healthForSchool()
        .where((row) => row.studentId.toUpperCase() == id)
        .toList();
  }

  List<CounselingRecord> counselingForStudent(String studentId) =>
      counselingForSchool().where((row) => row.studentId == studentId).toList();

  List<IepPlan> iepForStudent(String studentId) =>
      iepForSchool().where((row) => row.studentId == studentId).toList();

  CollegeGuidancePlan? collegeForStudent(String studentId) {
    for (final row in collegeForSchool()) {
      if (row.studentId == studentId) return row;
    }
    return null;
  }

  List<SupportRequest> requestsForStudent(String studentId) =>
      requestsForSchool().where((row) => row.studentId == studentId).toList();

  List<SafeguardingCase> safeguardingForStudent(String studentId) =>
      safeguardingForSchool()
          .where((row) => row.studentId == studentId)
          .toList();

  List<SupportRequest> pendingRequests([String? schoolId]) =>
      requestsForSchool(schoolId)
          .where((row) => row.status != SupportRequestStatus.completed)
          .toList();

  int pendingRequestCount([String? schoolId]) => pendingRequests(schoolId).length;

  List<IepPlan> unsignedIeps([String? schoolId]) => iepForSchool(schoolId)
      .where(
        (row) =>
            row.stage == IepStage.intake ||
            row.stage == IepStage.draftPlan ||
            !row.parentAgreed,
      )
      .toList();

  int unsignedIepCount([String? schoolId]) => unsignedIeps(schoolId).length;

  List<SafeguardingCase> openSafeguarding([String? schoolId]) =>
      safeguardingForSchool(schoolId).where((row) => row.isOpen).toList();

  int openSafeguardingCount([String? schoolId]) =>
      openSafeguarding(schoolId).length;

  List<StudentDocument> documentsForSchool([String? schoolId]) {
    var list = _schoolFilter(_documents, schoolId);
    if (_isPublicReader) {
      list = list
          .where(
            (row) =>
                _ownsStudent(row.studentId) &&
                row.confidentiality != 'leadership',
          )
          .toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  List<StudentDocument> documentsForStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    return documentsForSchool()
        .where((row) => row.studentId.toUpperCase() == id)
        .toList();
  }

  List<MedicationStockItem> medicationStockForSchool([String? schoolId]) {
    if (_isPublicReader) return const [];
    return _schoolFilter(_meds, schoolId)
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  List<SelObservation> selForSchool([String? schoolId]) {
    if (_isStudent) return const [];
    var list = _schoolFilter(_sel, schoolId);
    if (_isParent) {
      list = list.where((row) => _ownsStudent(row.studentId)).toList();
    }
    return list..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  double? selAverageForStudent(String studentId, [String? schoolId]) {
    final rows = selForSchool(schoolId)
        .where((row) => row.studentId == studentId)
        .toList();
    if (rows.isEmpty) return null;
    return rows.fold<int>(0, (sum, row) => sum + row.rating) / rows.length;
  }

  SelAnalytics selAnalytics([String? schoolId]) {
    final rows = selForSchool(schoolId);
    if (rows.isEmpty) {
      return const SelAnalytics(
        observations: 0,
        studentsCovered: 0,
        domainAverages: {},
      );
    }
    final domainAverages = <SelDomain, double>{};
    for (final domain in SelDomain.values) {
      final subset = rows.where((row) => row.domain == domain).toList();
      if (subset.isEmpty) continue;
      domainAverages[domain] =
          subset.fold<int>(0, (sum, row) => sum + row.rating) / subset.length;
    }
    return SelAnalytics(
      observations: rows.length,
      studentsCovered: rows.map((row) => row.studentId).toSet().length,
      domainAverages: domainAverages,
      overall:
          rows.fold<int>(0, (sum, row) => sum + row.rating) / rows.length,
    );
  }

  List<CounselingRecord> upcomingCounselingAppointments({
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return counselingForSchool(schoolId).where((row) {
      if (row.kind != CounselingKind.appointment || row.startsAt == null) {
        return false;
      }
      return !row.startsAt!.isBefore(start);
    }).toList()
      ..sort((a, b) => a.startsAt!.compareTo(b.startsAt!));
  }

  List<CollegeGuidancePlan> upcomingCollegeAppointments({
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return collegeForSchool(schoolId).where((row) {
      final at = row.nextAppointmentAt;
      if (at == null) return false;
      return !at.isBefore(start);
    }).toList()
      ..sort((a, b) => a.nextAppointmentAt!.compareTo(b.nextAppointmentAt!));
  }

  List<CalendarEvent> collegeGuidanceEvents({DateTime? now}) {
    final today = now ?? DateTime.now();
    final start = DateTime(today.year, today.month, today.day);
    return SchoolDataService.instance
        .getVisibleCalendarEvents()
        .where((event) => event.type == CalendarEventType.collegeGuidance)
        .where((event) => !event.date.isBefore(start))
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
  }

  CalendarEvent scheduleCollegeGuidanceEvent({
    required String title,
    String description = '',
    required DateTime date,
    String? time,
    String audience = 'College',
  }) {
    _requireStaffDesk();
    return SchoolDataService.instance.scheduleCalendarEvent(
      title: title.trim(),
      description: description.trim(),
      date: date,
      type: CalendarEventType.collegeGuidance,
      audience: audience,
      autoAnnounce: false,
      time: time,
    );
  }

  Future<HealthRecord> addHealthRecord({
    required String studentId,
    required HealthRecordType type,
    String title = '',
    String details = '',
    String staffNotes = '',
    DateTime? occurredAt,
    String? schoolId,
    String severity = 'routine',
    String vaccineName = '',
    int? doseNumber,
    DateTime? nextDueAt,
    String? medicationStockItemId,
    double? quantity,
    String unit = '',
    bool notifyParent = false,
    String disposition = '',
    DateTime? followUpAt,
    String vitalNotes = '',
    String parentContactMethod = '',
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final record = HealthRecord(
      id: _id('HR', _health.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      type: type,
      title: title.trim(),
      details: details.trim(),
      staffNotes: staffNotes.trim(),
      occurredAt: occurredAt ?? now,
      createdBy: _username,
      severity: type == HealthRecordType.emergencyAlert ? 'urgent' : severity,
      vaccineName: vaccineName.trim(),
      doseNumber: doseNumber,
      nextDueAt: nextDueAt,
      medicationStockItemId: medicationStockItemId,
      quantity: quantity,
      unit: unit.trim(),
      disposition: disposition.trim(),
      followUpAt: followUpAt,
      vitalNotes: vitalNotes.trim(),
      parentContactMethod: parentContactMethod.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _health.add(record);
    final shouldAlert = notifyParent || record.isUrgent;
    if (shouldAlert) {
      _pushHealthParentNotification(record);
    }
    await _persist();
    return record;
  }

  List<HealthRecord> clinicLogForDate(DateTime day, [String? schoolId]) {
    return healthForSchool(schoolId)
        .where((row) => _sameDay(row.recordedAt, day))
        .toList();
  }

  HealthClinicSummary clinicSummaryForDate(DateTime day, [String? schoolId]) {
    final rows = clinicLogForDate(day, schoolId);
    return HealthClinicSummary(
      day: DateTime(day.year, day.month, day.day),
      visits: rows.where((r) => r.type == HealthRecordType.clinicVisit).length,
      vaccinations:
          rows.where((r) => r.type == HealthRecordType.vaccination).length,
      medications:
          rows.where((r) => r.type == HealthRecordType.medication).length,
      alerts:
          rows.where((r) => r.type == HealthRecordType.emergencyAlert).length,
      checkups:
          rows.where((r) => r.type == HealthRecordType.medicalCheckup).length,
      accidents:
          rows.where((r) => r.type == HealthRecordType.accident).length,
    );
  }

  List<HealthRecord> vaccinesDueSoon({
    int withinDays = 30,
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final until = today.add(Duration(days: withinDays));
    return healthForSchool(schoolId).where((row) {
      if (row.type != HealthRecordType.vaccination || row.nextDueAt == null) {
        return false;
      }
      final due = row.nextDueAt!;
      return !due.isAfter(until);
    }).toList()
      ..sort((a, b) => a.nextDueAt!.compareTo(b.nextDueAt!));
  }

  List<List<String>> healthReportRows([String? schoolId]) {
    return [
      [
        'When',
        'Student',
        'Class',
        'Type',
        'Title',
        'Details',
        'Vaccine',
        'Dose',
        'Next due',
        'Severity',
        'Qty',
        'Unit',
        'Disposition',
        'Follow-up',
        'Vitals',
        'Parent contact',
        'Recorded by',
        'Parent notified',
      ],
      for (final row in healthForSchool(schoolId))
        [
          row.recordedAt.toIso8601String(),
          row.studentName,
          row.className ?? '',
          row.type.name,
          row.title,
          row.details,
          row.vaccineName,
          row.doseNumber?.toString() ?? '',
          row.nextDueAt?.toIso8601String().split('T').first ?? '',
          row.severity,
          row.quantity?.toString() ?? '',
          row.unit,
          row.disposition,
          row.followUpAt?.toIso8601String().split('T').first ?? '',
          row.vitalNotes,
          row.parentContactMethod,
          row.createdBy ?? '',
          row.parentNotifiedAt?.toIso8601String() ?? '',
        ],
    ];
  }

  List<HealthRecord> healthFollowUpsDue({
    int withinDays = 14,
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final until = today.add(Duration(days: withinDays));
    return healthForSchool(schoolId).where((row) {
      final due = row.followUpAt;
      if (due == null) return false;
      return !due.isAfter(until);
    }).toList()
      ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
  }

  List<CounselingRecord> counselingFollowUpsDue({
    int withinDays = 14,
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final until = today.add(Duration(days: withinDays));
    return counselingForSchool(schoolId).where((row) {
      final due = row.followUpAt;
      if (due == null) return false;
      return !due.isAfter(until);
    }).toList()
      ..sort((a, b) => a.followUpAt!.compareTo(b.followUpAt!));
  }

  List<StudentDocument> vaultReviewsDue({
    int withinDays = 30,
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final until = today.add(Duration(days: withinDays));
    return documentsForSchool(schoolId).where((row) {
      final due = row.reviewAt ?? row.expiresAt;
      if (due == null) return false;
      return !due.isAfter(until);
    }).toList()
      ..sort((a, b) {
        final aDue = a.reviewAt ?? a.expiresAt!;
        final bDue = b.reviewAt ?? b.expiresAt!;
        return aDue.compareTo(bDue);
      });
  }

  List<SupportRequest> overdueSupportRequests({
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    return pendingRequests(schoolId).where((row) {
      final due = row.dueAt;
      if (due == null) return false;
      return due.isBefore(today);
    }).toList();
  }

  List<SafeguardingCase> safeguardingReviewsDue({
    int withinDays = 14,
    String? schoolId,
    DateTime? now,
  }) {
    final today = now ?? DateTime.now();
    final until = today.add(Duration(days: withinDays));
    return openSafeguarding(schoolId).where((row) {
      final due = row.nextReviewAt;
      if (due == null) return false;
      return !due.isAfter(until);
    }).toList()
      ..sort((a, b) => a.nextReviewAt!.compareTo(b.nextReviewAt!));
  }

  List<MedicationStockItem> controlledMedicationStock([String? schoolId]) =>
      medicationStockForSchool(schoolId)
          .where((row) => row.controlledDrug)
          .toList();

  void _pushHealthParentNotification(HealthRecord row) {
    final kind = switch (row.type) {
      HealthRecordType.emergencyAlert => 'Emergency clinic alert',
      HealthRecordType.vaccination => 'Vaccination recorded',
      HealthRecordType.medication => 'Medication given',
      HealthRecordType.clinicVisit => 'Clinic visit',
      HealthRecordType.medicalCheckup => 'Medical check-up',
      HealthRecordType.accident => 'Accident / incident report',
    };
    NotificationService.instance.push(
      title: '$kind — ${row.studentName}',
      body: [
        if (row.title.trim().isNotEmpty) row.title.trim(),
        if (row.details.trim().isNotEmpty) row.details.trim(),
        if (row.vaccineName.isNotEmpty)
          'Vaccine ${row.vaccineName}'
              '${row.doseNumber == null ? '' : ' dose ${row.doseNumber}'}',
        if (row.nextDueAt != null)
          'Next due ${row.nextDueAt!.toIso8601String().split('T').first}',
      ].join(' · '),
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: 'School clinic',
      recipientRole: AuthService.roleParent,
      targetStudentId: row.studentId,
    );
    row.parentNotifiedAt = DateTime.now();
    row.parentNotifiedBy = _username;
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  Future<CounselingRecord> addCounselingRecord({
    required String studentId,
    required CounselingKind kind,
    String title = '',
    String parentSummary = '',
    String staffNotes = '',
    String? referralTo,
    DateTime? startsAt,
    String? schoolId,
    String format = 'individual',
    int? durationMinutes,
    DateTime? followUpAt,
    String confidentialityLimit = 'confidentialUnlessSafeguarding',
    String riskWatch = 'none',
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final record = CounselingRecord(
      id: _id('CN', _counseling.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      kind: kind,
      title: title.trim(),
      parentSummary: parentSummary.trim(),
      staffNotes: staffNotes.trim(),
      referralTo: referralTo?.trim(),
      startsAt: startsAt,
      createdBy: _username,
      format: format.trim().isEmpty ? 'individual' : format.trim(),
      durationMinutes: durationMinutes,
      followUpAt: followUpAt,
      confidentialityLimit: confidentialityLimit.trim().isEmpty
          ? 'confidentialUnlessSafeguarding'
          : confidentialityLimit.trim(),
      riskWatch: riskWatch == 'monitor' ? 'monitor' : 'none',
      createdAt: now,
      updatedAt: now,
    );
    _counseling.add(record);
    await _persist();
    return record;
  }

  Future<IepPlan> addIepPlan({
    required String studentId,
    String goals = '',
    String accommodations = '',
    String staffNotes = '',
    String parentAgreementText = '',
    IepStage stage = IepStage.intake,
    DateTime? nextReviewAt,
    String? schoolId,
    int mtssTier = 1,
    List<String> accessArrangements = const [],
    String reviewCycle = 'termly',
    String externalReportRef = '',
    String intakeAssessment = '',
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final plan = IepPlan(
      id: _id('IP', _iep.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      stage: stage,
      goals: goals.trim(),
      accommodations: accommodations.trim(),
      staffNotes: staffNotes.trim(),
      parentAgreementText: parentAgreementText.trim(),
      nextReviewAt: nextReviewAt,
      createdBy: _username,
      mtssTier: mtssTier.clamp(1, 3),
      accessArrangements: List.of(accessArrangements),
      reviewCycle: reviewCycle.trim().isEmpty ? 'termly' : reviewCycle.trim(),
      externalReportRef: externalReportRef.trim(),
      intakeAssessment: intakeAssessment.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _iep.add(plan);
    await _persist();
    return plan;
  }

  Future<IepPlan> updateIepStage(String id, IepStage stage) async {
    _requireStaffDesk();
    final plan = _iep.cast<IepPlan?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (plan == null) {
      throw StateError('IEP plan not found.');
    }
    plan.stage = stage;
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  Future<IepPlan> updateIepAccess({
    required String id,
    int? mtssTier,
    List<String>? accessArrangements,
    String? reviewCycle,
    String? externalReportRef,
    DateTime? nextReviewAt,
  }) async {
    _requireStaffDesk();
    final plan = _iep.cast<IepPlan?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (plan == null) {
      throw StateError('IEP plan not found.');
    }
    if (mtssTier != null) plan.mtssTier = mtssTier.clamp(1, 3);
    if (accessArrangements != null) {
      plan.accessArrangements = List.of(accessArrangements);
    }
    if (reviewCycle != null && reviewCycle.trim().isNotEmpty) {
      plan.reviewCycle = reviewCycle.trim();
    }
    if (externalReportRef != null) {
      plan.externalReportRef = externalReportRef.trim();
    }
    if (nextReviewAt != null) plan.nextReviewAt = nextReviewAt;
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  /// Parent agreement. Does not write grades. Cloud write of the IEP itself
  /// stays on the care desk; the parent also files a [SupportRequest].
  Future<IepPlan> signIepPlan(String id, {String note = ''}) async {
    if (!_isParent) {
      throw StateError('Only a parent can sign an IEP agreement.');
    }
    final plan = _iep.cast<IepPlan?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (plan == null) {
      throw StateError('IEP plan not found.');
    }
    if (!_ownsStudent(plan.studentId)) {
      throw StateError('You can only sign your child\'s IEP.');
    }
    plan.stage = IepStage.parentAgreement;
    plan.parentSignedAt = DateTime.now();
    plan.parentSignedBy = _username;
    plan.updatedAt = DateTime.now();
    final hasOpen = _requests.any(
      (row) =>
          row.relatedPlanId == id &&
          row.kind == SupportRequestKind.iepAgreement &&
          row.status != SupportRequestStatus.completed,
    );
    if (!hasOpen) {
      await submitSupportRequest(
        studentId: plan.studentId,
        kind: SupportRequestKind.iepAgreement,
        body: note.trim().isEmpty
            ? 'Parent signed the IEP agreement.'
            : note.trim(),
        relatedPlanId: id,
      );
      return plan;
    }
    await _persist();
    return plan;
  }

  Future<CollegeGuidancePlan> upsertCollegePlan({
    required String studentId,
    CollegeStage stage = CollegeStage.exploring,
    String targets = '',
    String portfolio = '',
    String notes = '',
    DateTime? nextAppointmentAt,
    List<CollegeArtifact>? artifacts,
    String? schoolId,
    String? applicationSystem,
    String? testingPlan,
    String? counselorName,
    String? destinationCountry,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final existing = _college.cast<CollegeGuidancePlan?>().firstWhere(
          (row) => row?.studentId == studentId.trim().toUpperCase(),
          orElse: () => null,
        );
    if (existing != null) {
      existing.studentName = meta.name;
      existing.className = meta.className;
      existing.stage = stage;
      existing.targets = targets.trim();
      existing.portfolio = portfolio.trim();
      existing.notes = notes.trim();
      existing.nextAppointmentAt = nextAppointmentAt;
      if (artifacts != null) existing.artifacts = List.of(artifacts);
      if (applicationSystem != null) {
        existing.applicationSystem = applicationSystem.trim();
      }
      if (testingPlan != null) existing.testingPlan = testingPlan.trim();
      if (counselorName != null) existing.counselorName = counselorName.trim();
      if (destinationCountry != null) {
        existing.destinationCountry = destinationCountry.trim();
      }
      existing.updatedAt = now;
      await _persist();
      return existing;
    }
    final plan = CollegeGuidancePlan(
      id: _id('CG', _college.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      stage: stage,
      targets: targets.trim(),
      portfolio: portfolio.trim(),
      notes: notes.trim(),
      nextAppointmentAt: nextAppointmentAt,
      artifacts: List.of(artifacts ?? const []),
      applicationSystem: applicationSystem?.trim() ?? '',
      testingPlan: testingPlan?.trim() ?? '',
      counselorName: counselorName?.trim() ?? '',
      destinationCountry: destinationCountry?.trim() ?? '',
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _college.add(plan);
    await _persist();
    return plan;
  }

  Future<CollegeGuidancePlan> scheduleCollegeAppointment({
    required String studentId,
    required DateTime when,
    String? schoolId,
  }) async {
    final existing = collegeForStudent(studentId);
    return upsertCollegePlan(
      studentId: studentId,
      stage: existing?.stage ?? CollegeStage.exploring,
      targets: existing?.targets ?? '',
      portfolio: existing?.portfolio ?? '',
      notes: existing?.notes ?? '',
      nextAppointmentAt: when,
      artifacts: existing?.artifacts,
      schoolId: schoolId,
      applicationSystem: existing?.applicationSystem,
      testingPlan: existing?.testingPlan,
      counselorName: existing?.counselorName,
      destinationCountry: existing?.destinationCountry,
    );
  }

  Future<CollegeGuidancePlan> addCollegeArtifact({
    required String studentId,
    required String title,
    CollegeArtifactKind kind = CollegeArtifactKind.other,
    DateTime? dueAt,
    String? filePath,
    String notes = '',
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final plan = collegeForStudent(studentId) ??
        await upsertCollegePlan(studentId: studentId, schoolId: schoolId);
    plan.artifacts = [
      ...plan.artifacts,
      CollegeArtifact(
        id: _id('CA', plan.artifacts.map((row) => row.id)),
        title: title.trim(),
        kind: kind,
        dueAt: dueAt,
        filePath: filePath,
        notes: notes.trim(),
      ),
    ];
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  Future<CollegeGuidancePlan> toggleCollegeArtifact(
    String studentId,
    String artifactId,
  ) async {
    _requireStaffDesk();
    final plan = collegeForStudent(studentId);
    if (plan == null) {
      throw StateError('College plan not found.');
    }
    for (final row in plan.artifacts) {
      if (row.id == artifactId) {
        row.done = !row.done;
        break;
      }
    }
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  Future<IepPlan> addIepEvaluation({
    required String id,
    required String notes,
    DateTime? evaluatedAt,
  }) async {
    _requireStaffDesk();
    final plan = _iep.cast<IepPlan?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (plan == null) {
      throw StateError('IEP plan not found.');
    }
    plan.evaluationNotes = notes.trim();
    plan.lastEvaluatedAt = evaluatedAt ?? DateTime.now();
    plan.stage = IepStage.review;
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  Future<IepPlan> addIepTraining({
    required String planId,
    required String topic,
    DateTime? trainedAt,
    String trainer = '',
    String notes = '',
    String audience = 'teacher',
  }) async {
    _requireStaffDesk();
    final plan = _iep.cast<IepPlan?>().firstWhere(
          (row) => row?.id == planId,
          orElse: () => null,
        );
    if (plan == null) {
      throw StateError('IEP plan not found.');
    }
    plan.trainingSessions = [
      ...plan.trainingSessions,
      IepTrainingSession(
        id: _id('IT', plan.trainingSessions.map((row) => row.id)),
        topic: topic.trim(),
        trainedAt: trainedAt,
        trainer: trainer.trim(),
        notes: notes.trim(),
        audience: audience.trim().isEmpty ? 'teacher' : audience.trim(),
      ),
    ];
    plan.updatedAt = DateTime.now();
    await _persist();
    return plan;
  }

  Future<StudentDocument> addStudentDocument({
    required String studentId,
    required String title,
    String category = 'other',
    String? filePath,
    String notes = '',
    String? schoolId,
    String confidentiality = 'staff',
    DateTime? expiresAt,
    DateTime? reviewAt,
    String source = '',
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final row = StudentDocument(
      id: _id('SD', _documents.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      title: title.trim(),
      category: category.trim().isEmpty ? 'other' : category.trim(),
      filePath: filePath,
      notes: notes.trim(),
      uploadedBy: _username,
      confidentiality:
          confidentiality.trim().isEmpty ? 'staff' : confidentiality.trim(),
      expiresAt: expiresAt,
      reviewAt: reviewAt,
      source: source.trim(),
      createdAt: now,
      updatedAt: now,
    );
    _documents.add(row);
    await _persist();
    return row;
  }

  Future<MedicationStockItem> upsertMedicationStock({
    String? id,
    required String name,
    String unit = 'unit',
    double quantityOnHand = 0,
    double reorderLevel = 0,
    String notes = '',
    String? schoolId,
    String batchNumber = '',
    DateTime? expiresAt,
    bool? controlledDrug,
    String? route,
    bool? parentConsentOnFile,
    String? prescriber,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    if (id != null) {
      final existing = _meds.cast<MedicationStockItem?>().firstWhere(
            (row) => row?.id == id,
            orElse: () => null,
          );
      if (existing != null) {
        existing.name = name.trim();
        existing.unit = unit.trim().isEmpty ? 'unit' : unit.trim();
        existing.quantityOnHand = quantityOnHand;
        existing.reorderLevel = reorderLevel;
        existing.notes = notes.trim();
        existing.batchNumber = batchNumber.trim();
        existing.expiresAt = expiresAt;
        if (controlledDrug != null) existing.controlledDrug = controlledDrug;
        if (route != null && route.trim().isNotEmpty) {
          existing.route = route.trim();
        }
        if (parentConsentOnFile != null) {
          existing.parentConsentOnFile = parentConsentOnFile;
        }
        if (prescriber != null) existing.prescriber = prescriber.trim();
        existing.updatedAt = now;
        await _persist();
        return existing;
      }
    }
    final row = MedicationStockItem(
      id: _id('MS', _meds.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      name: name.trim(),
      unit: unit.trim().isEmpty ? 'unit' : unit.trim(),
      quantityOnHand: quantityOnHand,
      reorderLevel: reorderLevel,
      notes: notes.trim(),
      createdBy: _username,
      batchNumber: batchNumber.trim(),
      expiresAt: expiresAt,
      controlledDrug: controlledDrug ?? false,
      route: (route ?? 'oral').trim().isEmpty ? 'oral' : (route ?? 'oral').trim(),
      parentConsentOnFile: parentConsentOnFile ?? false,
      prescriber: prescriber?.trim() ?? '',
      movements: [
        if (quantityOnHand != 0)
          MedicationStockMovement(
            id: 'mv-${now.millisecondsSinceEpoch}',
            delta: quantityOnHand,
            reason: 'receive',
            createdBy: _username,
            quantityAfter: quantityOnHand,
            createdAt: now,
          ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    _meds.add(row);
    await _persist();
    return row;
  }

  Future<MedicationStockItem> adjustMedicationStock({
    required String id,
    required double delta,
    String? studentId,
    String note = '',
    String reason = '',
    String witnessedBy = '',
  }) async {
    _requireStaffDesk();
    final row = _meds.cast<MedicationStockItem?>().firstWhere(
          (item) => item?.id == id,
          orElse: () => null,
        );
    if (row == null) {
      throw StateError('Medication stock item not found.');
    }
    final now = DateTime.now();
    row.quantityOnHand = (row.quantityOnHand + delta).clamp(0, 1e9);
    row.updatedAt = now;
    final meta = studentId == null || studentId.trim().isEmpty
        ? null
        : _studentMeta(studentId);
    final movementReason = reason.trim().isNotEmpty
        ? reason.trim()
        : (delta < 0 && meta != null ? 'dispense' : 'adjust');
    row.movements = [
      ...row.movements,
      MedicationStockMovement(
        id: 'mv-${now.millisecondsSinceEpoch}',
        delta: delta,
        reason: movementReason,
        studentId: studentId?.trim().toUpperCase(),
        studentName: meta?.name,
        note: note.trim(),
        createdBy: _username,
        quantityAfter: row.quantityOnHand,
        witnessedBy: witnessedBy.trim(),
        createdAt: now,
      ),
    ];
    if (studentId != null && studentId.trim().isNotEmpty && delta < 0) {
      await addHealthRecord(
        studentId: studentId,
        type: HealthRecordType.medication,
        title: 'Dispensed ${row.name}',
        details: '${delta.abs()} ${row.unit}'
            '${note.trim().isEmpty ? '' : ' · ${note.trim()}'}'
            '${row.batchNumber.isEmpty ? '' : ' · batch ${row.batchNumber}'}',
        medicationStockItemId: row.id,
        quantity: delta.abs(),
        unit: row.unit,
      );
      return row;
    }
    await _persist();
    return row;
  }

  Future<SelObservation> addSelObservation({
    required String studentId,
    SelDomain domain = SelDomain.selfAwareness,
    int rating = 3,
    String notes = '',
    DateTime? observedAt,
    String? schoolId,
  }) async {
    _requireStaffDesk();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final clamped = rating.clamp(1, 5);
    final row = SelObservation(
      id: _id('SEL', _sel.map((item) => item.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      domain: domain,
      rating: clamped,
      notes: notes.trim(),
      observedAt: observedAt ?? now,
      createdBy: _username,
      createdAt: now,
      updatedAt: now,
    );
    _sel.add(row);
    await _persist();
    return row;
  }

  Future<SupportRequest> submitSupportRequest({
    required String studentId,
    required SupportRequestKind kind,
    String body = '',
    String? relatedPlanId,
    String? schoolId,
    String priority = 'normal',
    String assignedTo = '',
    DateTime? dueAt,
  }) async {
    if (!_isParent && !_isStudent && !canManageDesk) {
      throw StateError('You cannot submit a student-support request.');
    }
    if (_isParent && !_ownsStudent(studentId)) {
      throw StateError('You can only request support for your linked child.');
    }
    if (_isStudent) {
      final self = (AuthService.currentUser?.linkedStudentId ?? '')
          .trim()
          .toUpperCase();
      if (self.isEmpty || self != studentId.trim().toUpperCase()) {
        throw StateError('You can only request support for yourself.');
      }
    }
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final request = SupportRequest(
      id: _id('SR', _requests.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      kind: kind,
      body: body.trim(),
      authorUsername: _username,
      authorRole: AuthService.currentUser?.roleKey,
      relatedPlanId: relatedPlanId,
      priority: priority.trim().isEmpty ? 'normal' : priority.trim(),
      assignedTo: assignedTo.trim(),
      dueAt: dueAt,
      createdAt: now,
      updatedAt: now,
    );
    _requests.add(request);
    await _persist();
    return request;
  }

  Future<SupportRequest> assignSupportRequest({
    required String id,
    String assignedTo = '',
    String priority = '',
    DateTime? dueAt,
    String lastActionNote = '',
  }) async {
    _requireStaffDesk();
    final request = _requests.cast<SupportRequest?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (request == null) {
      throw StateError('Support request not found.');
    }
    if (assignedTo.trim().isNotEmpty) request.assignedTo = assignedTo.trim();
    if (priority.trim().isNotEmpty) request.priority = priority.trim();
    if (dueAt != null) request.dueAt = dueAt;
    if (lastActionNote.trim().isNotEmpty) {
      request.lastActionNote = lastActionNote.trim();
    }
    request.updatedAt = DateTime.now();
    await _persist();
    return request;
  }

  Future<SupportRequest> acknowledgeSupportRequest(String id) async {
    _requireStaffDesk();
    return _setRequestStatus(id, SupportRequestStatus.acknowledged);
  }

  Future<SupportRequest> completeSupportRequest(String id) async {
    _requireStaffDesk();
    final request = await _setRequestStatus(id, SupportRequestStatus.completed);
    if (request.kind == SupportRequestKind.iepAgreement &&
        (request.relatedPlanId ?? '').isNotEmpty) {
      final plan = _iep.cast<IepPlan?>().firstWhere(
            (row) => row?.id == request.relatedPlanId,
            orElse: () => null,
          );
      if (plan != null) {
        plan.stage = IepStage.parentAgreement;
        plan.parentSignedAt ??= DateTime.now();
        plan.parentSignedBy ??= request.authorUsername;
        plan.updatedAt = DateTime.now();
        await _persist();
      }
    }
    return request;
  }

  Future<SafeguardingCase> openSafeguardingCase({
    required String studentId,
    String title = '',
    String details = '',
    String severity = 'standard',
    String? schoolId,
    String category = 'other',
    String dslName = '',
    DateTime? nextReviewAt,
    String agencyReferred = '',
  }) async {
    _requireSafeguarding();
    final now = DateTime.now();
    final meta = _studentMeta(studentId);
    final file = SafeguardingCase(
      id: _id('SG', _safeguarding.map((row) => row.id)),
      schoolId: (schoolId ?? _schoolId).toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: meta.name,
      className: meta.className,
      title: title.trim(),
      details: details.trim(),
      severity: severity.trim().isEmpty ? 'standard' : severity.trim(),
      reporterUsername: _username,
      assignedRole: 'student_affairs',
      category: category.trim().isEmpty ? 'other' : category.trim(),
      dslName: dslName.trim(),
      nextReviewAt: nextReviewAt,
      agencyReferred: agencyReferred.trim(),
      chronology: [
        SafeguardingChronologyEntry(
          id: 'sc-${now.millisecondsSinceEpoch}',
          note: 'Case opened.',
          author: _username,
          createdAt: now,
        ),
      ],
      createdAt: now,
      updatedAt: now,
    );
    _safeguarding.add(file);
    await _persist();
    return file;
  }

  Future<SafeguardingCase> updateSafeguardingStatus(
    String id,
    SafeguardingStatus status,
  ) async {
    _requireSafeguarding();
    final file = _safeguarding.cast<SafeguardingCase?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (file == null) {
      throw StateError('Safeguarding case not found.');
    }
    file.status = status;
    file.updatedAt = DateTime.now();
    file.chronology = [
      ...file.chronology,
      SafeguardingChronologyEntry(
        id: 'sc-${file.updatedAt.millisecondsSinceEpoch}',
        note: 'Status set to ${status.name}.',
        author: _username,
        createdAt: file.updatedAt,
      ),
    ];
    await _persist();
    return file;
  }

  Future<SafeguardingCase> addSafeguardingChronology({
    required String id,
    required String note,
    String agencyReferred = '',
    DateTime? nextReviewAt,
  }) async {
    _requireSafeguarding();
    final file = _safeguarding.cast<SafeguardingCase?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (file == null) {
      throw StateError('Safeguarding case not found.');
    }
    if (note.trim().isEmpty) {
      throw StateError('Write a chronology note first.');
    }
    final now = DateTime.now();
    file.chronology = [
      ...file.chronology,
      SafeguardingChronologyEntry(
        id: _id('SC', file.chronology.map((row) => row.id)),
        note: note.trim(),
        author: _username,
        createdAt: now,
      ),
    ];
    if (agencyReferred.trim().isNotEmpty) {
      file.agencyReferred = agencyReferred.trim();
    }
    if (nextReviewAt != null) file.nextReviewAt = nextReviewAt;
    file.updatedAt = now;
    await _persist();
    return file;
  }

  /// Reuses the existing parent-messaging thread. Never put child-protection
  /// case narrative in [body].
  Future<bool> openParentChannel({
    required String studentId,
    required String body,
  }) async {
    if (body.trim().isEmpty) {
      throw StateError('Write a parent message first.');
    }
    _requireStaffDesk();
    final student = StudentRegistryService.instance.lookupById(studentId);
    final parentName = student?.primaryParentName?.trim() ?? '';
    if (parentName.isEmpty) {
      throw StateError('No parent name is listed for this student.');
    }
    final recipient = MessagingAccessService.findParentRecipient(parentName);
    if (recipient == null) {
      throw StateError('No parent account is linked to this student.');
    }
    final sent = SchoolDataService.instance.sendAdminDirectMessage(
      parentName: recipient.parentName,
      body: body.trim(),
      studentId: studentId,
    );
    if (sent.isEmpty) {
      throw StateError('Could not open the parent message thread.');
    }
    return true;
  }

  void applyPersistedData({
    List<HealthRecord>? health,
    List<CounselingRecord>? counseling,
    List<IepPlan>? iep,
    List<CollegeGuidancePlan>? college,
    List<SupportRequest>? requests,
    List<SafeguardingCase>? safeguarding,
    List<StudentDocument>? documents,
    List<MedicationStockItem>? medication,
    List<SelObservation>? sel,
    bool merge = false,
  }) {
    void mergeList<T>(
      List<T> local,
      List<T> incoming,
      String Function(T) idOf,
    ) {
      if (!merge) {
        local
          ..clear()
          ..addAll(incoming);
        return;
      }
      final byId = {for (final item in local) idOf(item): item};
      for (final item in incoming) {
        byId[idOf(item)] = item;
      }
      local
        ..clear()
        ..addAll(byId.values);
    }

    if (health != null) mergeList(_health, health, (row) => row.id);
    if (counseling != null) {
      mergeList(_counseling, counseling, (row) => row.id);
    }
    if (iep != null) mergeList(_iep, iep, (row) => row.id);
    if (college != null) mergeList(_college, college, (row) => row.id);
    if (requests != null) mergeList(_requests, requests, (row) => row.id);
    if (safeguarding != null) {
      if (_isPublicReader || !canViewSafeguarding) {
        _safeguarding.clear();
      } else {
        mergeList(_safeguarding, safeguarding, (row) => row.id);
      }
    }
    if (documents != null) mergeList(_documents, documents, (row) => row.id);
    if (medication != null) {
      if (_isPublicReader) {
        _meds.clear();
      } else {
        mergeList(_meds, medication, (row) => row.id);
      }
    }
    if (sel != null) {
      if (_isStudent) {
        _sel.clear();
      } else {
        mergeList(_sel, sel, (row) => row.id);
      }
    }
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> healthMaps() =>
      _health.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> counselingMaps() =>
      _counseling.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> iepMaps() =>
      _iep.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> collegeMaps() =>
      _college.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> requestMaps() =>
      _requests.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> safeguardingMaps() =>
      _safeguarding.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> documentMaps() =>
      _documents.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> medicationMaps() =>
      _meds.map((row) => row.toMap()).toList();
  List<Map<String, dynamic>> selMaps() =>
      _sel.map((row) => row.toMap()).toList();

  Future<SupportRequest> _setRequestStatus(
    String id,
    SupportRequestStatus status,
  ) async {
    final request = _requests.cast<SupportRequest?>().firstWhere(
          (row) => row?.id == id,
          orElse: () => null,
        );
    if (request == null) {
      throw StateError('Support request not found.');
    }
    request.status = status;
    request.updatedAt = DateTime.now();
    await _persist();
    return request;
  }

  List<T> _schoolFilter<T>(List<T> rows, String? schoolId) {
    final sid = (schoolId ?? _schoolId).toUpperCase();
    if (sid.isEmpty) return List<T>.from(rows);
    return rows.where((row) {
      final rowSchool = switch (row) {
        HealthRecord r => r.schoolId,
        CounselingRecord r => r.schoolId,
        IepPlan r => r.schoolId,
        CollegeGuidancePlan r => r.schoolId,
        SupportRequest r => r.schoolId,
        SafeguardingCase r => r.schoolId,
        StudentDocument r => r.schoolId,
        MedicationStockItem r => r.schoolId,
        SelObservation r => r.schoolId,
        _ => '',
      };
      return rowSchool == sid;
    }).toList();
  }

  HealthRecord _publicHealth(HealthRecord row) => HealthRecord(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        type: row.type,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        title: row.title,
        details: row.details,
        staffNotes: '',
        occurredAt: row.occurredAt,
        createdBy: row.createdBy,
        severity: row.severity,
        vaccineName: row.vaccineName,
        doseNumber: row.doseNumber,
        nextDueAt: row.nextDueAt,
        quantity: row.quantity,
        unit: row.unit,
        parentNotifiedAt: row.parentNotifiedAt,
        parentNotifiedBy: row.parentNotifiedBy,
        disposition: row.disposition,
        followUpAt: row.followUpAt,
        parentContactMethod: row.parentContactMethod,
      );

  CounselingRecord _publicCounseling(CounselingRecord row) => CounselingRecord(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        kind: row.kind,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        title: row.title,
        parentSummary: row.parentSummary,
        staffNotes: '',
        referralTo: row.referralTo,
        startsAt: row.startsAt,
        createdBy: row.createdBy,
        format: row.format,
        durationMinutes: row.durationMinutes,
        followUpAt: row.followUpAt,
      );

  IepPlan _publicIep(IepPlan row) => IepPlan(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        stage: row.stage,
        goals: row.goals,
        accommodations: row.accommodations,
        staffNotes: '',
        parentAgreementText: row.parentAgreementText,
        parentSignedAt: row.parentSignedAt,
        parentSignedBy: row.parentSignedBy,
        nextReviewAt: row.nextReviewAt,
        createdBy: row.createdBy,
        trainingSessions: List.of(row.trainingSessions),
        mtssTier: row.mtssTier,
        accessArrangements: List.of(row.accessArrangements),
        reviewCycle: row.reviewCycle,
        externalReportRef: row.externalReportRef,
        intakeAssessment: row.intakeAssessment,
        evaluationNotes: row.evaluationNotes,
        lastEvaluatedAt: row.lastEvaluatedAt,
      );

  CollegeGuidancePlan _publicCollege(CollegeGuidancePlan row) =>
      CollegeGuidancePlan(
        id: row.id,
        schoolId: row.schoolId,
        studentId: row.studentId,
        studentName: row.studentName,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        className: row.className,
        stage: row.stage,
        targets: row.targets,
        portfolio: row.portfolio,
        notes: '',
        nextAppointmentAt: row.nextAppointmentAt,
        createdBy: row.createdBy,
        artifacts: List.of(row.artifacts),
        applicationSystem: row.applicationSystem,
        testingPlan: row.testingPlan,
        counselorName: row.counselorName,
        destinationCountry: row.destinationCountry,
      );

  ({String name, String? className}) _studentMeta(String studentId) {
    final student = StudentRegistryService.instance.lookupById(studentId);
    return (
      name: student?.fullName ?? studentId.trim().toUpperCase(),
      className: student?.className,
    );
  }

  bool _ownsStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    if (id.isEmpty) return false;
    if (_isStudent) {
      final self = (AuthService.currentUser?.linkedStudentId ?? '')
          .trim()
          .toUpperCase();
      return self.isNotEmpty && self == id;
    }
    return AuthService.activeLinkedStudentIds()
        .map((value) => value.trim().toUpperCase())
        .contains(id);
  }

  void _requireStaffDesk() {
    if (!canManageDesk) {
      throw StateError(
        'Student-support files can only be written by the care desk.',
      );
    }
  }

  void _requireSafeguarding() {
    if (!canManageSafeguarding) {
      throw StateError('Safeguarding files stay on the care-leadership desk.');
    }
  }

  Future<void> _persist() async {
    notifyListeners();
    await StudentSupportPersistenceService.instance.saveFromService();
  }

  String _id(String prefix, Iterable<String> existing) {
    return ShortRegistryId.allocate(
      prefix: prefix,
      existingIds: existing,
      isTaken: (id) => existing.contains(id),
    );
  }
}
