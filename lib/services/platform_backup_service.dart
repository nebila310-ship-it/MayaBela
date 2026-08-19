import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/school_enrollment_metrics_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

class PlatformBackupService {
  PlatformBackupService._();
  static final instance = PlatformBackupService._();

  Map<String, dynamic> buildBackupPayload() {
    final schools = SchoolRegistryService.instance.getAllSchools();
    return {
      'format': 'maya_platform_backup',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'schoolCount': schools.length,
      'schools': schools.map((s) => s.toJson()).toList(),
    };
  }

  String buildCsv() {
    final schools = SchoolRegistryService.instance.getAllSchools();
    final metrics = SchoolEnrollmentMetricsService.instance;
    final buffer = StringBuffer(
      'School ID,Name,City,Status,Subscription Expiry,Admin Phone,Students,Rate ETB/student,Min Monthly ETB,Contracted Seats\n',
    );
    for (final s in schools) {
      final m = metrics.forSchool(s.id);
      final expiry = s.subscriptionExpiresAt;
      final expiryStr = expiry == null
          ? ''
          : '${expiry.year}-${expiry.month.toString().padLeft(2, '0')}-${expiry.day.toString().padLeft(2, '0')}';
      buffer.writeln([
        _csvCell(s.id),
        _csvCell(s.name),
        _csvCell(s.city ?? ''),
        _csvCell(s.status.name),
        _csvCell(expiryStr),
        _csvCell(s.adminContactPhone ?? ''),
        m.billableStudents.toString(),
        (s.ratePerStudentMonthEtb ?? '').toString(),
        (s.minimumMonthlyEtb ?? '').toString(),
        (s.contractedSeats ?? '').toString(),
      ].join(','));
    }
    return buffer.toString();
  }

  String _csvCell(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }

  Future<void> shareJsonBackup() async {
    final payload = buildBackupPayload();
    final json = const JsonEncoder.withIndent('  ').convert(payload);
    final file = await _writeTemp('maya_platform_backup.json', json);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Maya Platform backup',
      text: 'Maya Platform school registry backup (${payload['schoolCount']} schools)',
    );
    await PlatformAuditLogService.instance.log(
      action: 'backup_exported',
      detail: 'JSON · ${payload['schoolCount']} schools',
    );
  }

  Future<void> shareCsvBackup() async {
    final csv = buildCsv();
    final schools = SchoolRegistryService.instance.getAllSchools();
    final file = await _writeTemp('maya_platform_schools.csv', csv);
    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'Maya Platform schools',
      text: 'Maya Platform school export (${schools.length} schools)',
    );
    await PlatformAuditLogService.instance.log(
      action: 'backup_exported',
      detail: 'CSV · ${schools.length} schools',
    );
  }

  Future<File> _writeTemp(String name, String contents) async {
    final dir = await getTemporaryDirectory();
    final stamp = DateTime.now().millisecondsSinceEpoch;
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot + 1) : 'txt';
    final file = File('${dir.path}/${base}_$stamp.$ext');
    await file.writeAsString(contents);
    return file;
  }
}
