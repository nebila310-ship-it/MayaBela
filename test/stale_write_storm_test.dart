import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/cloud_app_store.dart';

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

  test('RLS 42501 and duplicate upsert must not dump the whole school', () {
    expect(
      CloudAppStore.shouldEscalateToFullPush(
        Exception(
          'new row violates row-level security policy for table "app_documents"',
        ),
      ),
      isFalse,
    );
    expect(
      CloudAppStore.shouldEscalateToFullPush(
        Exception(
          'ON CONFLICT DO UPDATE command cannot affect row a second time',
        ),
      ),
      isFalse,
    );
  });

  test('writeBatch keeps the last row when the same doc id appears twice', () {
    final rows = DocumentStore.dedupeByDocId(
      [
        {'id': 'fee-1', 'amount': 10},
        {'id': 'fee-2', 'amount': 20},
        {'id': 'fee-1', 'amount': 99},
        {'id': '', 'amount': 1},
      ],
      (item) => '${item['id']}',
    );
    expect(rows, [
      {'id': 'fee-1', 'amount': 99},
      {'id': 'fee-2', 'amount': 20},
    ]);
  });

  test('a real transport error may still request a later snapshot', () {
    expect(
      CloudAppStore.shouldEscalateToFullPush(Exception('SocketException')),
      isTrue,
    );
  });
}
