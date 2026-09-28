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

  test('a real transport error may still request a later snapshot', () {
    expect(
      CloudAppStore.shouldEscalateToFullPush(Exception('SocketException')),
      isTrue,
    );
  });
}
