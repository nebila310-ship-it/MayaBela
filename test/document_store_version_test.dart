import 'package:flutter_test/flutter_test.dart';
import 'package:mayabela/services/cloud/document_store.dart';

void main() {
  test('clientRowVersion keeps the snapshot the client last read', () {
    expect(DocumentStore.clientRowVersion({'rowVersion': 4}), 4);
    expect(DocumentStore.clientRowVersion({'rowVersion': '7'}), 7);
    expect(DocumentStore.clientRowVersion({}), 0);
  });

  test('sameDocumentPayload ignores volatile timestamps', () {
    expect(
      DocumentStore.sameDocumentPayload(
        {'name': 'Desk', 'updatedAt': 'a', 'updated_at': 'b', '_docId': '1'},
        {'name': 'Desk', 'updatedAt': 'c'},
      ),
      isTrue,
    );
  });

  test('fees and inventory are the only versioned collections', () {
    expect(DocumentStore.versionedCollections, {
      'fees',
      'inventory_items',
      'classroom_inventory',
    });
  });
}
