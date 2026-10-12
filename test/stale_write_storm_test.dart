import 'package:flutter_test/flutter_test.dart';
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
      'FR-001',
    );
    expect(
      SchoolAuthCloudService.schoolIdFromJwtPayload({
        'app_metadata': {'role': 'admin'},
      }),
      isNull,
    );
  });
}
