import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/database/supabase/supabase_storage_bootstrap.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';

void main() {
  test('stale_write and the wrapped user message are both recognized', () {
    expect(
      DocumentStore.isStaleWrite(
        Exception('PostgrestException: stale_write (40001)'),
      ),
      isTrue,
    );
    expect(
      DocumentStore.isStaleWrite(
        StateError(
          'This fees record was updated elsewhere. Reload and try again.',
        ),
      ),
      isTrue,
    );
    expect(DocumentStore.isStaleWrite(Exception('network timeout')), isFalse);
  });

  test('stale_write must not queue another full-school dump', () {
    expect(
      CloudAppStore.shouldEscalateToFullPush(
        Exception('stale_write'),
      ),
      isFalse,
    );
    expect(
      CloudAppStore.shouldEscalateToFullPush(
        StateError('This inventory_items record was updated elsewhere.'),
      ),
      isFalse,
    );
  });

  test('JWT / deny failures still skip the full dump', () {
    expect(
      CloudAppStore.shouldEscalateToFullPush(Exception('JWT expired')),
      isFalse,
    );
    expect(
      CloudAppStore.shouldEscalateToFullPush(Exception('write_denied')),
      isFalse,
    );
  });

  test('RLS 403 / 42501 must not queue another full-school dump', () {
    expect(
      CloudAppStore.shouldEscalateToFullPush(
        Exception(
          'PostgrestException: new row violates row-level security '
          'policy for table "app_documents" (42501)',
        ),
      ),
      isFalse,
    );
    expect(
      CloudAppStore.shouldEscalateToFullPush(Exception('HTTP 403 Forbidden')),
      isFalse,
    );
    expect(
      CloudAppStore.shouldEscalateToFullPush(
        StateError('Cannot save fees/FEE-1 — JWT has no school.'),
      ),
      isFalse,
    );
  });

  test('teacher login must not schedule a full snapshot after a 403', () {
    expect(CloudAppStore.shouldRunFullLocalPush('teacher'), isFalse);
    expect(CloudAppStore.shouldRunFullLocalPush('parent'), isFalse);
    expect(CloudAppStore.shouldRunFullLocalPush('student'), isFalse);
    expect(CloudAppStore.shouldRunFullLocalPush('driver'), isFalse);
    expect(CloudAppStore.shouldRunFullLocalPush('admin'), isTrue);
    expect(
      CloudAppStore.isPermanentAuthDenial(
        errorCode: 'denied',
        errorMessage: 'Not allowed to write student registry.',
      ),
      isTrue,
    );
    expect(
      CloudAppStore.isPermanentAuthDenial(
        errorMessage: 'write_denied',
      ),
      isTrue,
    );
    expect(
      CloudAppStore.isPermanentAuthDenial(
        errorMessage:
            'new row violates row-level security policy for table "app_documents"',
      ),
      isTrue,
    );
    expect(
      CloudAppStore.shouldEscalateToFullPush(
        StateError('Not allowed to write student registry.'),
      ),
      isFalse,
    );
  });

  test('client does not post collections the trigger always rejects', () {
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'school_registry',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'platform_audit_log',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'homework',
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'admin',
        collection: 'school_registry',
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'auth_secrets',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'password_reset_codes',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'parent',
        collection: 'app_auth_accounts',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'parent',
        collection: 'conversations',
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'student',
        collection: 'homework',
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'student',
        collection: 'grade_reports',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'driver',
        collection: 'buses',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'driver',
        collection: 'bus_live_positions',
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'leadership_tasks',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'ict_devices',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'inventory_items',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'purchase_requests',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'buses',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'health_records',
        staffRoles: const ['student_affairs'],
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'inventory_items',
        mayReadAllSchoolData: true,
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'ict_devices',
        mayReadAllSchoolData: true,
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteRow(
        roleKey: 'teacher',
        collection: 'fees',
        docId: 'fee-other',
        data: const {'className': 'Grade 4A'},
        assignedClasses: const ['Grade 5B'],
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteRow(
        roleKey: 'teacher',
        collection: 'fees',
        docId: 'fee-own',
        data: const {'className': 'Grade 5B'},
        assignedClasses: const ['Grade 5B'],
      ),
      isTrue,
    );
    expect(
      DocumentStore.clientMayWriteRow(
        roleKey: 'teacher',
        collection: 'student_registry',
        docId: 'STU-1',
        data: const {'className': 'Grade 5B'},
        assignedClasses: const [],
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteRow(
        roleKey: 'teacher',
        collection: 'user_preferences',
        docId: 'other-teacher',
        data: const {'username': 'other-teacher'},
        username: 'ada',
        jwtSchoolId: 'MAL',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteRow(
        roleKey: 'teacher',
        collection: 'user_preferences',
        docId: 'ada',
        data: const {'username': 'ada'},
        username: 'ada',
        jwtSchoolId: 'MAL',
      ),
      isTrue,
    );
  });

  test('sign-in must not repeat a refused account save as a direct upsert', () {
    expect(
      CloudAppStore.shouldDirectUpsertAuthAccount(
        callerRole: 'teacher',
        callerMayManageStaff: false,
        errorCode: 'denied',
        errorMessage: 'Admin authentication required',
      ),
      isFalse,
    );
    expect(
      CloudAppStore.shouldDirectUpsertAuthAccount(
        callerRole: 'parent',
        callerMayManageStaff: false,
        errorCode: 'denied',
        errorMessage: 'Admin authentication required',
      ),
      isFalse,
    );
    expect(
      CloudAppStore.shouldDirectUpsertAuthAccount(
        callerRole: 'student',
        callerMayManageStaff: false,
      ),
      isFalse,
    );
    expect(
      CloudAppStore.shouldDirectUpsertAuthAccount(
        callerRole: 'admin',
        callerMayManageStaff: true,
        errorCode: 'denied',
        errorMessage: 'Not allowed',
      ),
      isFalse,
    );
    expect(
      CloudAppStore.shouldDirectUpsertAuthAccount(
        callerRole: 'admin',
        callerMayManageStaff: true,
        errorCode: 'invalid',
        errorMessage: 'network down',
      ),
      isTrue,
    );
    expect(
      CloudAppStore.shouldDirectUpsertAuthAccount(
        callerRole: 'teacher',
        callerMayManageStaff: true,
        errorCode: 'invalid',
        errorMessage: 'network down',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'teacher',
        collection: 'app_auth_accounts',
      ),
      isFalse,
    );
    expect(
      DocumentStore.clientMayWriteCollection(
        roleKey: 'admin',
        collection: 'app_auth_accounts',
      ),
      isTrue,
    );
    expect(
      SchoolAuthCloudService.jwtMayWriteAppDocuments({
        'role': 'anon',
        'app_metadata': {'role': 'teacher', 'schoolId': 'MAL'},
      }),
      isFalse,
    );
    expect(
      SchoolAuthCloudService.jwtMayWriteAppDocuments({
        'role': 'authenticated',
        'app_metadata': {'role': 'teacher', 'schoolId': 'MAL'},
      }),
      isTrue,
    );
    expect(
      SchoolAuthCloudService.jwtMayWriteAppDocuments({
        'role': 'authenticated',
        'app_metadata': {'role': 'authenticated', 'schoolId': 'MAL'},
      }),
      isFalse,
    );
  });

  test('a real transport error may still request a later snapshot', () {
    expect(
      CloudAppStore.shouldEscalateToFullPush(Exception('SocketException')),
      isTrue,
    );
  });

  test('isRlsForbidden matches PostgREST WITH CHECK failures', () {
    expect(
      DocumentStore.isRlsForbidden(
        Exception(
          'new row violates row-level security policy for table '
          '"app_documents"',
        ),
      ),
      isTrue,
    );
    expect(DocumentStore.isRlsForbidden(Exception('42501')), isTrue);
    expect(
      DocumentStore.isRlsForbidden(
        StateError('Not allowed to save this fees record.'),
      ),
      isTrue,
    );
    expect(
      DocumentStore.isRlsForbidden(
        StateError('Cannot save fees/FEE-1 — JWT has no school.'),
      ),
      isFalse,
    );
    expect(
      DocumentStore.isRlsForbidden(Exception('SocketException')),
      isFalse,
    );
  });

  test('canWriteSchoolRow requires a matching access-token school', () {
    expect(
      DocumentStore.canWriteSchoolRow(jwtSchoolId: null, rowSchoolId: 'FR-001'),
      isFalse,
    );
    expect(
      DocumentStore.canWriteSchoolRow(jwtSchoolId: 'FR-001', rowSchoolId: ''),
      isFalse,
    );
    expect(
      DocumentStore.canWriteSchoolRow(
        jwtSchoolId: 'fr-001',
        rowSchoolId: 'FR-001',
      ),
      isTrue,
    );
    expect(
      DocumentStore.canWriteSchoolRow(
        jwtSchoolId: 'FR-001',
        rowSchoolId: 'OTHER',
      ),
      isFalse,
    );
  });

  test('outbox holds when JWT has no school and drops a mismatch', () {
    expect(
      CloudAppStore.outboxWriteDecision(
        jwtSchoolId: null,
        mutationSchoolId: 'FR-001',
      ),
      OutboxWriteDecision.hold,
    );
    expect(
      CloudAppStore.outboxWriteDecision(
        jwtSchoolId: '',
        mutationSchoolId: 'FR-001',
      ),
      OutboxWriteDecision.hold,
    );
    expect(
      CloudAppStore.outboxWriteDecision(
        jwtSchoolId: 'FR-001',
        mutationSchoolId: 'OTHER',
      ),
      OutboxWriteDecision.drop,
    );
    expect(
      CloudAppStore.outboxWriteDecision(
        jwtSchoolId: 'fr-001',
        mutationSchoolId: 'FR-001',
      ),
      OutboxWriteDecision.post,
    );
    expect(
      CloudAppStore.outboxWriteDecision(
        jwtSchoolId: 'FR-001',
        mutationSchoolId: null,
      ),
      OutboxWriteDecision.post,
    );
  });

  test('class names for writes come from the access token only', () {
    expect(
      SchoolAuthCloudService.classNamesFromJwtPayload({
        'app_metadata': {
          'assignedClassNames': ['Grade 5B', ' 4A '],
          'linkedClassNames': ['Grade 5B'],
        },
        'user_metadata': {
          'assignedClassNames': ['Grade 9Z'],
        },
      }),
      ['Grade 5B', '4A'],
    );
    expect(
      SchoolAuthCloudService.classNamesFromJwtPayload({
        'user_metadata': {
          'assignedClassNames': ['Grade 9Z'],
        },
      }),
      isEmpty,
    );
  });

  test('schoolIdFromJwtPayload matches jwt_school_id() claim order', () {
    expect(
      SchoolAuthCloudService.schoolIdFromJwtPayload({
        'app_metadata': {'schoolId': 'fr-001'},
        'user_metadata': {'schoolId': 'OTHER'},
      }),
      'FR-001',
    );
    expect(
      SchoolAuthCloudService.schoolIdFromJwtPayload({
        'app_metadata': <String, dynamic>{},
        'user_metadata': {'school_id': 'fr-001'},
      }),
      isNull,
    );
    expect(
      SchoolAuthCloudService.schoolIdFromJwtPayload({
        'app_metadata': {'role': 'admin'},
      }),
      isNull,
    );
  });

  test('storage probe is not uploaded until a user is signed in', () {
    expect(
      SupabaseStorageBootstrap.shouldUploadStorageProbe(signedIn: false),
      isFalse,
    );
    expect(
      SupabaseStorageBootstrap.shouldUploadStorageProbe(signedIn: true),
      isTrue,
    );
    expect(
      SupabaseStorageBootstrap.storageErrorIsRowSecurity(
        Exception(
          'new row violates row-level security policy for table "objects"',
        ),
      ),
      isTrue,
    );
    expect(
      SupabaseStorageBootstrap.storageErrorIsRowSecurity(
        Exception('SocketException'),
      ),
      isFalse,
    );
  });
}
