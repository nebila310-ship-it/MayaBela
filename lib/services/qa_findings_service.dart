import 'package:flutter/foundation.dart';

import 'package:mayabela/models/qa_finding.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/qa_findings_persistence_service.dart';

/// EDUABA Quality Assurance — findings & improvement plans register (§2).
///
/// QA staff log findings from audits (teaching quality, assessment integrity,
/// grading process, Student Affairs fairness, policy compliance), issue an
/// improvement plan, track it to resolution, and the summary metrics feed the
/// Deputy General Manager / General Manager. Data lives in the `qa_findings`
/// cloud collection and syncs on the 5s engine.
class QaFindingsService extends ChangeNotifier {
  QaFindingsService._();
  static final instance = QaFindingsService._();

  final List<QaFinding> _findings = [];
  bool _loaded = false;

  List<QaFinding> get allFindings => List.unmodifiable(_findings);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    await QaFindingsPersistenceService.instance.loadIntoService();
  }

  List<QaFinding> forSchool(String? schoolId) {
    final sid = schoolId?.trim().toUpperCase();
    if (sid == null || sid.isEmpty) return allFindings;
    return _findings.where((f) => f.schoolId == sid).toList();
  }

  QaFinding? byId(String id) {
    for (final f in _findings) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<QaFinding> raiseFinding({
    required QaFindingArea area,
    required String title,
    required String details,
    required QaFindingSeverity severity,
    String improvementPlan = '',
    String ownerRole = '',
    DateTime? dueDate,
  }) async {
    final user = AuthService.currentUser;
    final now = DateTime.now();
    final finding = QaFinding(
      id: 'qa-${now.millisecondsSinceEpoch}',
      schoolId: (AuthService.activeSchoolId ?? user?.schoolId ?? '')
          .trim()
          .toUpperCase(),
      area: area,
      title: title.trim(),
      details: details.trim(),
      severity: severity,
      status: improvementPlan.trim().isEmpty
          ? QaFindingStatus.open
          : QaFindingStatus.actionPlanned,
      improvementPlan: improvementPlan.trim(),
      ownerRole: ownerRole.trim(),
      raisedById: user?.username ?? '',
      raisedByName: user?.fullName ?? user?.username ?? 'Quality Assurance',
      dueDate: dueDate,
      createdAt: now,
      updatedAt: now,
    );
    _findings.insert(0, finding);
    notifyListeners();
    await QaFindingsPersistenceService.instance.saveFromService();
    return finding;
  }

  Future<QaFinding?> updateFinding(
    String id,
    QaFinding Function(QaFinding current) mutate,
  ) async {
    final index = _findings.indexWhere((f) => f.id == id);
    if (index < 0) return null;
    _findings[index] = mutate(_findings[index]).copyWith(
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await QaFindingsPersistenceService.instance.saveFromService();
    return _findings[index];
  }

  /// Quality metrics for the DGM / GM report header.
  ({int open, int critical, int overdue, int resolved}) metricsForSchool(
    String? schoolId,
  ) {
    final items = forSchool(schoolId);
    var open = 0, critical = 0, overdue = 0, resolved = 0;
    for (final f in items) {
      if (f.isOpen) {
        open++;
        if (f.severity == QaFindingSeverity.critical) critical++;
        if (f.isOverdue) overdue++;
      } else {
        resolved++;
      }
    }
    return (open: open, critical: critical, overdue: overdue, resolved: resolved);
  }

  /// Replace-or-merge from local disk / cloud pull; newest updatedAt wins.
  void applyPersistedData(List<QaFinding> items, {bool merge = false}) {
    if (!merge) {
      _findings
        ..clear()
        ..addAll(items);
    } else {
      final byId = {for (final f in _findings) f.id: f};
      for (final incoming in items) {
        final existing = byId[incoming.id];
        if (existing == null ||
            incoming.updatedAt.isAfter(existing.updatedAt)) {
          byId[incoming.id] = incoming;
        }
      }
      _findings
        ..clear()
        ..addAll(byId.values);
    }
    _findings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    _loaded = true;
    notifyListeners();
  }

  List<Map<String, dynamic>> snapshotMaps() =>
      _findings.map((f) => f.toMap()).toList();
}
