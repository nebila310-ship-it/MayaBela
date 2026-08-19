import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/services/persistence/cloud_outbox_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await CloudOutboxService.instance.resetForTest();
  });

  test('coalesces two upserts of the same document', () async {
    await CloudOutboxService.instance.enqueue(
      collection: 'fees',
      docId: 'FEE-1',
      schoolId: 'TB-001',
      data: {'amount': 10},
    );
    await CloudOutboxService.instance.enqueue(
      collection: 'fees',
      docId: 'FEE-1',
      schoolId: 'TB-001',
      data: {'amount': 20},
    );
    expect(CloudOutboxService.instance.mutationCount, 1);
    expect(CloudOutboxService.instance.hasPending, isTrue);
    expect(CloudOutboxService.instance.hasFullPush, isFalse);
    expect(
      CloudOutboxService.instance.snapshotMutations().single.data?['amount'],
      20,
    );
  });

  test('ack removes only that document', () async {
    await CloudOutboxService.instance.enqueue(
      collection: 'inventory_items',
      docId: 'INV-1',
      data: {'qty': 1},
    );
    await CloudOutboxService.instance.enqueue(
      collection: 'inventory_items',
      docId: 'INV-2',
      data: {'qty': 2},
    );
    await CloudOutboxService.instance.ack('inventory_items', 'INV-1');
    expect(CloudOutboxService.instance.mutationCount, 1);
    expect(
      CloudOutboxService.instance.snapshotMutations().single.docId,
      'INV-2',
    );
  });

  test('delete replaces a prior upsert for the same id', () async {
    await CloudOutboxService.instance.enqueue(
      collection: 'homework',
      docId: 'HW-1',
      data: {'title': 'old'},
    );
    await CloudOutboxService.instance.enqueue(
      collection: 'homework',
      docId: 'HW-1',
      op: 'delete',
    );
    expect(CloudOutboxService.instance.mutationCount, 1);
    expect(CloudOutboxService.instance.snapshotMutations().single.op, 'delete');
  });
}
