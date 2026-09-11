import 'package:flutter/foundation.dart';

import 'package:mayabela/models/app_notification.dart';
import 'package:mayabela/models/discipline_case.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/persistence/discipline_persistence_service.dart';

/// EDUABA Student Affairs — behaviour / incident case register.
///
/// Teachers file reports; Student Affairs (or admin) investigates, schedules
/// hearings, records outcomes, and notifies parents. Data lives in the
/// `discipline_cases` cloud collection and syncs on the 5s engine.
class DisciplineService extends ChangeNotifier {
  DisciplineService._();
  static final instance = DisciplineService._();

  final List<DisciplineCase> _cases = [];
  bool _loaded = false;

  List<DisciplineCase> get allCases => List.unmodifiable(_cases);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await DisciplinePersistenceService.instance.loadIntoService();
  }

  List<DisciplineCase> forSchool(String? schoolId) {
    final sid = schoolId?.trim().toUpperCase();
    if (sid == null || sid.isEmpty) return allCases;
    return _cases.where((c) => c.schoolId == sid).toList();
  }

  List<DisciplineCase> forStudentIds(Iterable<String> studentIds) {
    final ids = studentIds.map((s) => s.trim().toUpperCase()).toSet();
    return _cases.where((c) => ids.contains(c.studentId)).toList();
  }

  List<DisciplineCase> reportedBy(String reporterId) {
    final id = reporterId.trim().toLowerCase();
    return _cases
        .where((c) => c.reporterId.trim().toLowerCase() == id)
        .toList();
  }

  DisciplineCase? byId(String id) {
    for (final c in _cases) {
      if (c.id == id) return c;
    }
    return null;
  }

  Future<DisciplineCase> fileReport({
    required String studentId,
    required String studentName,
    required String className,
    required DisciplineCaseKind kind,
    required String title,
    required String description,
    String conductCode = '',
    bool notifyParent = true,
  }) async {
    final user = AuthService.currentUser;
    final now = DateTime.now();
    final newCase = DisciplineCase(
      id: 'dc-${now.millisecondsSinceEpoch}',
      schoolId: (AuthService.activeSchoolId ?? user?.schoolId ?? '')
          .trim()
          .toUpperCase(),
      studentId: studentId.trim().toUpperCase(),
      studentName: studentName.trim(),
      className: className.trim(),
      reporterId: user?.username ?? '',
      reporterName: user?.fullName ?? user?.username ?? 'Staff',
      reporterRole: user?.roleKey ?? '',
      kind: kind,
      title: title.trim(),
      description: description.trim(),
      conductCode: conductCode.trim(),
      parentNotified: notifyParent,
      createdAt: now,
      updatedAt: now,
    );
    _cases.insert(0, newCase);
    notifyListeners();
    await DisciplinePersistenceService.instance.saveFromService();
    _pushStaffDeskNotification(newCase);
    if (notifyParent) {
      _pushParentNotification(newCase);
    }
    return newCase;
  }

  /// Student Affairs / admin progression: status, hearing, outcome.
  Future<DisciplineCase?> updateCase(
    String id,
    DisciplineCase Function(DisciplineCase current) mutate, {
    bool notifyParent = false,
  }) async {
    final index = _cases.indexWhere((c) => c.id == id);
    if (index < 0) return null;
    final updated = mutate(_cases[index]).copyWith(
      handledByName:
          AuthService.currentUser?.fullName ?? AuthService.currentUser?.username,
      updatedAt: DateTime.now(),
    );
    _cases[index] = updated;
    notifyListeners();
    await DisciplinePersistenceService.instance.saveFromService();
    if (notifyParent) {
      _pushParentNotification(updated);
    }
    if (updated.status == DisciplineCaseStatus.escalated) {
      _pushStaffDeskNotification(updated);
    }
    // EDUABA §1A: outcomes are communicated to the reporting teacher too.
    if (updated.status == DisciplineCaseStatus.resolved ||
        updated.status == DisciplineCaseStatus.dismissed) {
      _pushReporterNotification(updated);
    }
    return updated;
  }

  void _pushReporterNotification(DisciplineCase c) {
    final reporter = c.reporterId.trim();
    if (reporter.isEmpty ||
        reporter == AuthService.currentUser?.username) {
      return;
    }
    final closing = c.status == DisciplineCaseStatus.resolved
        ? 'resolved (${c.outcome.name})'
        : 'dismissed';
    NotificationService.instance.push(
      title: 'Case update — ${c.studentName}',
      body: 'Your ${c.kind == DisciplineCaseKind.behaviour ? 'behaviour' : 'incident'} '
          'report "${c.title}" was $closing.'
          '${c.outcomeNotes.isNotEmpty ? ' ${c.outcomeNotes}' : ''}',
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: 'Student Affairs',
      recipientRole: AuthService.roleTeacher,
      recipientUsername: reporter,
    );
  }

  void _pushStaffDeskNotification(DisciplineCase c) {
    final kindLabel =
        c.kind == DisciplineCaseKind.behaviour ? 'behaviour' : 'incident';
    final body = c.status == DisciplineCaseStatus.escalated
        ? '${c.studentName} (${c.className}) escalated to '
            '${DisciplineConductCodes.escalationLabel(c.escalatedTo)}.'
        : '${c.reporterName} filed a $kindLabel report for ${c.studentName} '
            '(${c.className}): ${c.title}.';
    NotificationService.instance.push(
      title: c.status == DisciplineCaseStatus.escalated
          ? 'Discipline case escalated'
          : 'New discipline report',
      body: body,
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: c.reporterName.isNotEmpty ? c.reporterName : 'Student Affairs',
      recipientRole: AuthService.roleAdmin,
      targetClassName: c.className,
      showOnMessagesBadge: false,
    );
  }

  void _pushParentNotification(DisciplineCase c) {
    final rule = c.conductCode.isEmpty ? '' : ' Rule: ${c.conductCode}.';
    final statusText = switch (c.status) {
      DisciplineCaseStatus.submitted =>
        '${c.reporterName} recorded a ${c.kind.name} report for ${c.studentName}: '
            '${c.title}.$rule',
      DisciplineCaseStatus.escalated =>
        'The case for ${c.studentName} was escalated to '
            '${DisciplineConductCodes.escalationLabel(c.escalatedTo)}.$rule',
      DisciplineCaseStatus.hearingScheduled =>
        'A discipline hearing has been scheduled for ${c.studentName}.'
            '${c.hearingAt != null ? ' Date: ${c.hearingAt}' : ''}',
      DisciplineCaseStatus.resolved =>
        'Discipline case for ${c.studentName} resolved: '
            '${DisciplineConductCodes.outcomeLabel(c.outcome)}.'
            '${c.outcomeNotes.isNotEmpty ? ' ${c.outcomeNotes}' : ''}',
      DisciplineCaseStatus.dismissed =>
        'Discipline case for ${c.studentName} was dismissed.',
      _ => 'Update on the Student Affairs case for ${c.studentName}.',
    };
    NotificationService.instance.push(
      title: 'Student Affairs — ${c.studentName}',
      body: statusText,
      type: NotificationType.general,
      fromRole: AuthService.roleTeacher,
      fromName: 'Student Affairs',
      recipientRole: AuthService.roleParent,
      targetStudentId: c.studentId,
    );
  }

  /// Replace-or-merge from local disk / cloud pull; newest updatedAt wins.
  void applyPersistedData(List<DisciplineCase> items, {bool merge = false}) {
    if (!merge) {
      _cases
        ..clear()
        ..addAll(items);
    } else {
      final byId = {for (final c in _cases) c.id: c};
      for (final incoming in items) {
        final existing = byId[incoming.id];
        if (existing == null ||
            incoming.updatedAt.isAfter(existing.updatedAt)) {
          byId[incoming.id] = incoming;
        }
      }
      _cases
        ..clear()
        ..addAll(byId.values);
    }
    _cases.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> snapshotMaps() =>
      _cases.map((c) => c.toMap()).toList();

  @visibleForTesting
  void resetForTests() {
    _cases.clear();
    _loaded = true;
    notifyListeners();
  }
}
