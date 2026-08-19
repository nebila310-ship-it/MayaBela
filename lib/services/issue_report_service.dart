import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/school_data_service.dart';

class IssueReport {
  IssueReport({
    required this.id,
    required this.reporterName,
    required this.category,
    required this.description,
    required this.submittedAt,
    required this.recipientEmail,
    this.schoolId,
    this.roleKey,
  });

  final String id;
  final String reporterName;
  final String category;
  final String description;
  final DateTime submittedAt;
  final String recipientEmail;
  final String? schoolId;
  final String? roleKey;

  Map<String, dynamic> toJson() => {
        'id': id,
        'reporterName': reporterName,
        'category': category,
        'description': description,
        'submittedAt': submittedAt.toIso8601String(),
        'recipientEmail': recipientEmail,
        'schoolId': schoolId,
        'roleKey': roleKey,
      };

  factory IssueReport.fromJson(Map<String, dynamic> json) {
    return IssueReport(
      id: json['id'] as String,
      reporterName: json['reporterName'] as String,
      category: json['category'] as String,
      description: json['description'] as String,
      submittedAt: DateTime.parse(json['submittedAt'] as String),
      recipientEmail: json['recipientEmail'] as String,
      schoolId: json['schoolId'] as String?,
      roleKey: json['roleKey'] as String?,
    );
  }
}

/// Queues issue reports locally and delivers transport alerts to admin + parents.
class IssueReportService {
  IssueReportService._();

  static final instance = IssueReportService._();

  static const _storageKey = 'issue_reports_v1';
  static const maxReports = 100;

  final List<IssueReport> _reports = [];
  bool _loaded = false;
  int _nextId = 1;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      _reports
        ..clear()
        ..addAll(
          list.map((e) => IssueReport.fromJson(e as Map<String, dynamic>)),
        );
      for (final report in _reports) {
        final n = int.tryParse(report.id.replaceAll('issue-', ''));
        if (n != null && n >= _nextId) _nextId = n + 1;
      }
    } catch (_) {
      _reports.clear();
    }
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _storageKey,
      jsonEncode(_reports.map((r) => r.toJson()).toList()),
    );
  }

  Future<void> submit({
    required String reporterName,
    required String category,
    required String description,
    bool deliverToSchool = false,
  }) async {
    await load();
    final user = AuthService.currentUser;
    final report = IssueReport(
      id: 'issue-${_nextId++}',
      reporterName: reporterName,
      category: category,
      description: description,
      submittedAt: DateTime.now(),
      recipientEmail: AuthService.supportEmail,
      schoolId: AuthService.activeSchoolId ?? user?.schoolId,
      roleKey: user?.roleKey,
    );
    _reports.insert(0, report);
    if (_reports.length > maxReports) {
      _reports.removeRange(maxReports, _reports.length);
    }
    await _persist();

    if (deliverToSchool &&
        user?.roleKey == AuthService.roleDriver) {
      SchoolDataService.instance.deliverTransportIssueReport(
        reporterName: reporterName,
        category: category,
        description: description,
      );
    }

    await PlatformAuditLogService.instance.log(
      action: 'Issue report submitted',
      schoolId: report.schoolId,
      detail:
          'To: admin & parents · ${report.category} · ${report.reporterName}',
    );
  }

  List<IssueReport> recent({int limit = 50}) {
    return List.unmodifiable(_reports.take(limit));
  }
}
