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

  test('sameDocumentPayload ignores rowVersion so republish is not a write', () {
    expect(
      DocumentStore.sameDocumentPayload(
        {'title': 'Term 1', 'amount': 200, 'rowVersion': 6},
        {'title': 'Term 1', 'amount': 200},
      ),
      isTrue,
    );
    expect(
      DocumentStore.sameDocumentPayload(
        {'title': 'Term 1', 'amount': 200, 'rowVersion': 6},
        {'title': 'Term 1', 'amount': 250, 'rowVersion': 0},
      ),
      isFalse,
    );
  });

  test('writeRowVersion prefers the cloud snapshot over a local 0', () {
    expect(
      DocumentStore.writeRowVersion(
        collection: 'fees',
        existing: {'id': 'f1', 'rowVersion': 6},
        incoming: {'id': 'f1', 'title': 'Term 1'},
      ),
      6,
    );
    expect(
      DocumentStore.writeRowVersion(
        collection: 'fees',
        existing: null,
        incoming: {'id': 'f1'},
      ),
      0,
    );
    expect(
      DocumentStore.writeRowVersion(
        collection: 'homework',
        existing: {'rowVersion': 9},
        incoming: {'title': 'Essay'},
      ),
      0,
    );
  });

  test('fees and inventory are the only versioned collections', () {
    expect(DocumentStore.versionedCollections, {
      'fees',
      'inventory_items',
      'classroom_inventory',
    });
  });

  test('cloud reads page at 1000 so a Data API cap cannot hide later rows', () {
    expect(DocumentStore.readPageSize, 1000);
    expect(DocumentStore.pageRange(0), (0, 999));
    expect(DocumentStore.pageRange(1), (1000, 1999));
    expect(DocumentStore.shouldFetchNextPage(1000), isTrue);
    expect(DocumentStore.shouldFetchNextPage(999), isFalse);
    expect(DocumentStore.shouldFetchNextPage(0), isFalse);
  });
}
