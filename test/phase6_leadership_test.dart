import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/qa_finding.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/cloud_sync_engine.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/maya_assistant_service.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/qa_export_service.dart';
import 'package:mayabela/services/qa_findings_service.dart';
import 'package:mayabela/services/qa_monitor_service.dart';
import 'package:mayabela/services/totp.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  String read(String path) => File(path).readAsStringSync();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoliveService.resetForTests();
    QaMonitorService.resetForTests();
    AuthService.currentUser = RegisteredUser(
      username: 'admin.p6',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: 'TB-001',
    );
  });

  tearDown(() {
    GoliveService.resetForTests();
    QaMonitorService.resetForTests();
    AuthService.currentUser = null;
  });

  test('MFA is required for Admin and cannot be turned off', () async {
    final svc = GoliveService.instance;
    expect(svc.mfaRequiredForLeadership(), isTrue);
    expect(svc.mustEnroll(username: 'admin.p6'), isTrue);
    expect(svc.canDisableEnrollment('admin.p6'), isFalse);

    final started = await svc.startEnrollment();
    await svc.confirmEnrollment(
      'admin.p6',
      Totp.generateCode(started.enrollment.secret),
    );
    expect(svc.isEnabledFor('admin.p6'), isTrue);
    expect(svc.mustEnroll(username: 'admin.p6'), isFalse);
    await expectLater(
      svc.disableEnrollment('admin.p6'),
      throwsA(isA<StateError>()),
    );

    await svc.setMfaRequiredForLeadership(false);
    expect(svc.mfaRequiredForLeadership(), isFalse);
    expect(svc.canDisableEnrollment('admin.p6'), isTrue);
  });

  test('teachers stay opt-in while Admin is required', () {
    AuthService.currentUser = RegisteredUser(
      username: 'teacher.p6',
      password: 'x',
      roleKey: AuthService.roleTeacher,
      schoolId: 'TB-001',
    );
    expect(GoliveService.isLeadershipRole(AuthService.roleTeacher), isFalse);
    expect(GoliveService.instance.mustEnroll(username: 'teacher.p6'), isFalse);
    expect(GoliveService.instance.canDisableEnrollment('teacher.p6'), isTrue);
  });

  test('QA desk exports findings and monitor rows as CSV', () async {
    await QaFindingsService.instance.raiseFinding(
      area: QaFindingArea.academic,
      title: 'Phase 6 lesson walkthrough',
      details: 'Observation notes',
      severity: QaFindingSeverity.high,
    );
    final findings = QaExportService.instance.findingsCsv(schoolId: 'TB-001');
    expect(findings, contains('Phase 6 lesson walkthrough'));
    expect(findings, contains('Severity'));

    await QaMonitorService.instance.recordObservation(
      teacherName: 'Ms. Live',
      className: '2C',
      subject: 'Math',
    );
    final observations = QaExportService.instance.observationsCsv();
    expect(observations, contains('Ms. Live'));
    expect(
      QaExportService.instance.allCsv(schoolId: 'TB-001'),
      contains('Open findings'),
    );
  });

  test('Maya answers live school counts without inventing names', () async {
    final live = MayaLiveSnapshot.capture('TB-001');
    expect(live.summary, contains('students'));
    expect(live.toMap()['openFindings'], isA<int>());

    final reply = await MayaAssistantService.instance.reply(
      roleKey: AuthService.roleAdmin,
      userMessage: 'What is the current school status?',
    );
    expect(reply, contains('Live school snapshot'));
    expect(reply, contains('${live.students} students'));
  });

  test('policy leftover stays on the 30s lane and settings is a hub', () {
    expect(AppCollections.mfaPolicies, 'mfa_policies');
    expect(CloudSyncEngine.standardPriority, contains('mfa_policies'));
    expect(
      CloudAppStore.instance.pullGroupKeyForTest(AppCollections.mfaPolicies),
      'golive',
    );
    expect(
      CloudSyncEngine.highPriority,
      isNot(contains('mfa_policies')),
    );

    final router = read('lib/web_erp/router/web_erp_router.dart');
    expect(router, contains('WebSettingsHubPage'));
    expect(read('lib/web_erp/pages/web_settings_hub_page.dart'), contains('Leadership preflight'));
    expect(
      read('lib/services/maya_assistant_service.dart'),
      contains('liveContext'),
    );
    expect(
      read('supabase/functions/maya-assistant-chat/index.ts'),
      contains('Live school snapshot'),
    );
  });
}
