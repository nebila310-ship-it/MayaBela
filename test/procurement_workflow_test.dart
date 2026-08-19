import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/models/procurement_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/procurement_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/services/school_registry_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const schoolId = 'TB-001';

  void signIn(String username, String roleKey, List<String> staffRoles) {
    AuthService.currentUser = RegisteredUser(
      username: username,
      password: 'x',
      roleKey: roleKey,
      schoolId: schoolId,
      fullName: username,
      staffRoles: staffRoles,
    );
  }

  void setSelfApproval(bool value) {
    SchoolRegistryService.instance.applyPersistedSchools([
      SchoolRecord(
        id: schoolId,
        name: 'Test School',
        allowSelfApproval: value,
      ),
    ]);
  }

  Future<InventoryItem> seedItem({int quantity = 20}) {
    signIn('owner', AuthService.roleAdmin, const []);
    return InventoryService.instance.addItem(
      name: 'Chalk Box',
      category: InventoryItemCategory.stationery,
      description: 'White chalk',
      quantityAvailable: quantity,
      unit: 'box',
      minimumStockLevel: 2,
      storageLocation: 'Main Store',
      purchasePrice: 50,
      supplier: 'Paper World',
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    setSelfApproval(false);
    ProcurementService.instance.applyPersistedData(purchases: [], issues: []);
    InventoryService.instance.applyPersistedData(
      items: [],
      transactions: [],
      studentIssued: [],
      classroom: [],
      assets: [],
      suppliers: [],
      maintenance: [],
    );
  });

  tearDown(() {
    AuthService.currentUser = null;
  });

  group('Purchase request workflow', () {
    test('procurement creates, VP approves, storekeeper receives', () async {
      signIn('proc.officer', AuthService.roleTeacher, [StaffRoles.procurement]);
      final createError =
          await ProcurementService.instance.createPurchaseRequest(
        lines: const [
          PurchaseRequestLine(name: 'Chalk Box', quantity: 10, unit: 'box'),
        ],
        reason: 'Term restock',
      );
      expect(createError, isNull);
      final request = ProcurementService.instance.purchasesSnapshot().first;
      expect(request.status, ApprovalStatus.pending);
      expect(request.requestedBy, 'proc.officer');

      signIn('vp.user', AuthService.roleTeacher, [StaffRoles.vicePresident]);
      expect(
        await ProcurementService.instance.approvePurchaseRequest(request.id),
        isNull,
      );
      expect(request.status, ApprovalStatus.approved);
      expect(request.approvedBy, 'vp.user');

      // Receiving stocks the inventory: the named item exists, so it gets a
      // stock-in movement.
      await seedItem(quantity: 5);
      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      expect(
        await ProcurementService.instance.receivePurchaseRequest(
          request.id,
          supplier: 'Paper World',
        ),
        isNull,
      );
      expect(request.status, ApprovalStatus.received);
      final item = InventoryService.instance.filteredItems().first;
      expect(item.quantityAvailable, 15); // 5 seeded + 10 received

      // Idempotency: a second receive attempt is rejected.
      expect(
        await ProcurementService.instance.receivePurchaseRequest(request.id),
        'not_approved',
      );
      expect(item.quantityAvailable, 15);
    });

    test('receiving unknown items adds them to the catalog', () async {
      signIn('owner', AuthService.roleAdmin, const []);
      await ProcurementService.instance.createPurchaseRequest(
        lines: const [
          PurchaseRequestLine(
            name: 'Whiteboard Marker',
            quantity: 24,
            unit: 'piece',
            estimatedUnitPrice: 30,
          ),
        ],
        reason: 'New classrooms',
      );
      final request = ProcurementService.instance.purchasesSnapshot().first;
      // Owner approves someone else's flow end-to-end.
      await ProcurementService.instance.approvePurchaseRequest(request.id);
      await ProcurementService.instance.receivePurchaseRequest(request.id);

      final items = InventoryService.instance.filteredItems();
      expect(items, hasLength(1));
      expect(items.first.name, 'Whiteboard Marker');
      expect(items.first.quantityAvailable, 24);
    });

    test('approval requires the approve permission', () async {
      signIn('proc.officer', AuthService.roleTeacher, [StaffRoles.procurement]);
      await ProcurementService.instance.createPurchaseRequest(
        lines: const [PurchaseRequestLine(name: 'Desks', quantity: 4)],
        reason: 'Replacement',
      );
      final request = ProcurementService.instance.purchasesSnapshot().first;

      // Procurement officers cannot approve purchase requests.
      expect(
        await ProcurementService.instance.approvePurchaseRequest(request.id),
        'not_allowed',
      );
      // Storekeepers cannot either.
      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      expect(
        await ProcurementService.instance.approvePurchaseRequest(request.id),
        'not_allowed',
      );
      expect(request.status, ApprovalStatus.pending);
    });

    test('rejection requires a reason and records it', () async {
      signIn('proc.officer', AuthService.roleTeacher, [StaffRoles.procurement]);
      await ProcurementService.instance.createPurchaseRequest(
        lines: const [PurchaseRequestLine(name: 'Projector', quantity: 1)],
        reason: 'Lab upgrade',
      );
      final request = ProcurementService.instance.purchasesSnapshot().first;

      signIn('vp.user', AuthService.roleTeacher, [StaffRoles.vicePresident]);
      expect(
        await ProcurementService.instance.rejectPurchaseRequest(request.id, ''),
        'reason_required',
      );
      expect(
        await ProcurementService.instance
            .rejectPurchaseRequest(request.id, 'No budget this term'),
        isNull,
      );
      expect(request.status, ApprovalStatus.rejected);
      expect(request.rejectionReason, 'No budget this term');

      // Decided requests cannot be re-decided.
      expect(
        await ProcurementService.instance.approvePurchaseRequest(request.id),
        'not_pending',
      );
    });

    test('creation requires the create permission', () async {
      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      expect(
        await ProcurementService.instance.createPurchaseRequest(
          lines: const [PurchaseRequestLine(name: 'Chalk', quantity: 1)],
          reason: 'x',
        ),
        'not_allowed',
      );
    });
  });

  group('Self-approval school setting', () {
    test('blocked by default, allowed when the owner enables it', () async {
      // A user holding both create and approve permissions (e.g. Full Access).
      signIn('multi.user', AuthService.roleTeacher, [StaffRoles.fullAccess]);
      await ProcurementService.instance.createPurchaseRequest(
        lines: const [PurchaseRequestLine(name: 'Paper', quantity: 2)],
        reason: 'Office',
      );
      final request = ProcurementService.instance.purchasesSnapshot().first;

      expect(
        await ProcurementService.instance.approvePurchaseRequest(request.id),
        'self_approval_blocked',
      );
      expect(request.status, ApprovalStatus.pending);

      setSelfApproval(true);
      expect(
        await ProcurementService.instance.approvePurchaseRequest(request.id),
        isNull,
      );
      expect(request.status, ApprovalStatus.approved);
    });

    test('does not apply to a different approver', () async {
      signIn('proc.officer', AuthService.roleTeacher, [StaffRoles.procurement]);
      await ProcurementService.instance.createPurchaseRequest(
        lines: const [PurchaseRequestLine(name: 'Paper', quantity: 2)],
        reason: 'Office',
      );
      final request = ProcurementService.instance.purchasesSnapshot().first;

      signIn('vp.user', AuthService.roleTeacher, [StaffRoles.vicePresident]);
      expect(
        await ProcurementService.instance.approvePurchaseRequest(request.id),
        isNull,
      );
    });
  });

  group('Issue request workflow', () {
    test('storekeeper creates, procurement approves, storekeeper issues',
        () async {
      final item = await seedItem(quantity: 20);

      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      expect(
        await ProcurementService.instance.createIssueRequest(
          itemId: item.id,
          quantity: 8,
          purpose: 'Science week',
          department: 'Science',
        ),
        isNull,
      );
      final request = ProcurementService.instance.issuesSnapshot().first;
      expect(request.status, ApprovalStatus.pending);

      // The storekeeper cannot fulfil an unapproved request.
      expect(
        await ProcurementService.instance.fulfillIssueRequest(request.id),
        'not_approved',
      );

      signIn('proc.officer', AuthService.roleTeacher, [StaffRoles.procurement]);
      expect(
        await ProcurementService.instance.approveIssueRequest(request.id),
        isNull,
      );
      expect(request.status, ApprovalStatus.approved);

      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      expect(
        await ProcurementService.instance.fulfillIssueRequest(request.id),
        isNull,
      );
      expect(request.status, ApprovalStatus.issued);
      expect(item.quantityAvailable, 12); // 20 - 8

      // Idempotency: fulfilling again does not move stock twice.
      expect(
        await ProcurementService.instance.fulfillIssueRequest(request.id),
        'not_approved',
      );
      expect(item.quantityAvailable, 12);
    });

    test('insufficient stock blocks fulfilment, not approval', () async {
      final item = await seedItem(quantity: 3);

      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      await ProcurementService.instance.createIssueRequest(
        itemId: item.id,
        quantity: 10,
        purpose: 'Too much',
      );
      final request = ProcurementService.instance.issuesSnapshot().first;

      signIn('proc.officer', AuthService.roleTeacher, [StaffRoles.procurement]);
      expect(
        await ProcurementService.instance.approveIssueRequest(request.id),
        isNull,
      );

      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      expect(
        await ProcurementService.instance.fulfillIssueRequest(request.id),
        'insufficient_stock',
      );
      expect(request.status, ApprovalStatus.approved);
      expect(item.quantityAvailable, 3);
    });

    test('self-approval rule applies to issue requests too', () async {
      final item = await seedItem();

      // Procurement officer holds both create is false — use Full Access to
      // hold create_issue_requests and approve_issue_requests together.
      signIn('multi.user', AuthService.roleTeacher, [StaffRoles.fullAccess]);
      await ProcurementService.instance.createIssueRequest(
        itemId: item.id,
        quantity: 2,
        purpose: 'Office',
      );
      final request = ProcurementService.instance.issuesSnapshot().first;

      expect(
        await ProcurementService.instance.approveIssueRequest(request.id),
        'self_approval_blocked',
      );
      setSelfApproval(true);
      expect(
        await ProcurementService.instance.approveIssueRequest(request.id),
        isNull,
      );
    });

    test('only issue_stock holders can fulfil', () async {
      final item = await seedItem();

      signIn('store.keeper', AuthService.roleTeacher, [StaffRoles.storekeeper]);
      await ProcurementService.instance.createIssueRequest(
        itemId: item.id,
        quantity: 2,
        purpose: 'Office',
      );
      final request = ProcurementService.instance.issuesSnapshot().first;

      signIn('proc.officer', AuthService.roleTeacher, [StaffRoles.procurement]);
      await ProcurementService.instance.approveIssueRequest(request.id);
      // Procurement approves but cannot hand out stock.
      expect(
        await ProcurementService.instance.fulfillIssueRequest(request.id),
        'not_allowed',
      );
    });
  });

  group('Model round-trips', () {
    test('purchase request survives toMap/fromMap', () {
      final request = PurchaseRequest(
        id: 'pr-1',
        lines: const [
          PurchaseRequestLine(
            name: 'Chalk',
            quantity: 5,
            unit: 'box',
            estimatedUnitPrice: 45,
          ),
        ],
        reason: 'Restock',
        requestedBy: 'proc.officer',
        requestedByName: 'Procurement Officer',
        department: 'Store',
        createdAt: DateTime(2026, 7, 28),
        status: ApprovalStatus.approved,
        approvedBy: 'vp.user',
        approvedByName: 'VP',
        approvedAt: DateTime(2026, 7, 28, 10),
        schoolId: schoolId,
      );
      final restored = PurchaseRequest.fromMap(request.toMap());
      expect(restored.id, request.id);
      expect(restored.lines.single.name, 'Chalk');
      expect(restored.lines.single.estimatedUnitPrice, 45);
      expect(restored.status, ApprovalStatus.approved);
      expect(restored.approvedBy, 'vp.user');
      expect(restored.estimatedTotal, 225);
    });

    test('issue request survives toMap/fromMap', () {
      final request = IssueRequest(
        id: 'ir-1',
        itemId: 'inv-1',
        itemName: 'Chalk Box',
        quantity: 3,
        purpose: 'Science week',
        requestedBy: 'store.keeper',
        requestedByName: 'Storekeeper',
        department: 'Science',
        createdAt: DateTime(2026, 7, 28),
        status: ApprovalStatus.issued,
        issuedBy: 'store.keeper',
        issuedAt: DateTime(2026, 7, 28, 12),
        schoolId: schoolId,
      );
      final restored = IssueRequest.fromMap(request.toMap());
      expect(restored.itemName, 'Chalk Box');
      expect(restored.status, ApprovalStatus.issued);
      expect(restored.issuedBy, 'store.keeper');
      expect(restored.department, 'Science');
    });

    test('unknown status parses as pending, ranks are forward-only', () {
      expect(ApprovalStatusX.parse('bogus'), ApprovalStatus.pending);
      expect(
        ApprovalStatus.pending.rank < ApprovalStatus.approved.rank,
        isTrue,
      );
      expect(
        ApprovalStatus.approved.rank < ApprovalStatus.received.rank,
        isTrue,
      );
      expect(ApprovalStatus.rejected.rank, ApprovalStatus.approved.rank);
    });
  });
}
