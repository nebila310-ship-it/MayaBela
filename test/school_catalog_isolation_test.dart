import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/finance_models.dart';
import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/models/inventory_models.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/finance_service.dart';
import 'package:mayabela/services/inventory_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/services/web_admin_stats_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void signIn(String schoolId) {
    AuthService.currentUser = RegisteredUser(
      username: 'admin.$schoolId',
      password: 'x',
      roleKey: AuthService.roleAdmin,
      schoolId: schoolId,
      fullName: 'Admin $schoolId',
    );
    AuthService.sessionSchoolId = schoolId;
  }

  void clearInventory() {
    InventoryService.instance.applyPersistedData(
      items: [],
      transactions: [],
      studentIssued: [],
      classroom: [],
      assets: [],
      suppliers: [],
      maintenance: [],
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
    FinanceService.instance.resetForTests();
    clearInventory();
  });

  tearDown(() {
    AuthService.currentUser = null;
    AuthService.sessionSchoolId = null;
    FinanceService.instance.resetForTests();
    clearInventory();
  });

  test('a new live school starts cash on hand at 0 and hides other schools', () {
    signIn('FN0597');
    FinanceService.instance.applyPersistedData(
      cashboxes: [
        FinanceCashbox(
          id: 'BOX-OTHER',
          schoolId: 'TB-001',
          name: 'Demo treasury',
          openingBalance: 88000,
        ),
        FinanceCashbox(
          id: 'BOX-ORPHAN',
          schoolId: '',
          name: 'Unscoped box',
          openingBalance: 12000,
        ),
        FinanceCashbox(
          id: 'BOX-SEED',
          schoolId: 'FN0597',
          name: 'Main office',
          openingBalance: 5000,
          cashierName: 'Cashier',
        ),
      ],
      cashMoves: [
        FinanceCashMovement(
          id: 'MOV-OTHER',
          schoolId: 'TB-001',
          cashboxId: 'BOX-OTHER',
          kind: FinanceCashKind.receipt,
          amount: 2500,
          at: DateTime.now(),
          recordedBy: 'Demo cashier',
          note: 'Demo collection',
        ),
      ],
    );

    FinanceService.instance.ensureDefaults(schoolId: 'FN0597');

    expect(FinanceService.instance.cashboxesForSchool('FN0597'), hasLength(1));
    expect(
      FinanceService.instance.cashboxesForSchool('FN0597').single.openingBalance,
      0,
    );
    expect(FinanceService.instance.controlTotals('FN0597').cashOnHand, 0);
    expect(
      FinanceService.instance.cashboxesForSchool('FN0597').map((c) => c.name),
      isNot(contains('Demo treasury')),
    );
    expect(
      FinanceService.instance.cashMovesForSchool('FN0597'),
      isEmpty,
    );
  });

  test('sample e-books stay on the demo school and off a live school', () {
    SchoolDataService.instance.applyPersistedLearningMaterials([
      LearningMaterialItem(
        id: 'lm-live-fn',
        className: 'Library',
        subject: 'General',
        bookName: 'Fnote Reader',
        materialName: 'School copy',
        filePath: 'asset:assets/branding/maya_brand.png',
        teacherId: 'admin.fn',
        teacherName: 'Librarian',
        postedAt: DateTime.now(),
        schoolId: 'FN0597',
      ),
      LearningMaterialItem(
        id: 'lm-other-school',
        className: 'Library',
        subject: 'General',
        bookName: 'Other School Atlas',
        materialName: 'Borrowed catalog',
        filePath: 'asset:assets/branding/maya_brand.png',
        teacherId: 'admin.tb',
        teacherName: 'Librarian',
        postedAt: DateTime.now(),
        schoolId: 'TB-001',
      ),
    ]);

    signIn('FN0597');
    SchoolDataService.instance.ensureSampleLearningMaterials();
    final live = SchoolDataService.instance.learningMaterialsForSchool();
    expect(live.map((b) => b.bookName), contains('Fnote Reader'));
    expect(live.map((b) => b.bookName), isNot(contains('Other School Atlas')));
    expect(
      live.any((b) => b.bookName.toLowerCase().startsWith('sample ')),
      isFalse,
    );
    expect(live.any((b) => b.id.startsWith('lm-sample-')), isFalse);

    signIn('TB-001');
    SchoolDataService.instance.ensureSampleLearningMaterials();
    final demo = SchoolDataService.instance.learningMaterialsForSchool();
    expect(demo.any((b) => b.id.startsWith('lm-sample-')), isTrue);
    expect(demo.map((b) => b.bookName), isNot(contains('Fnote Reader')));
  });

  test('pending report-card count matches this school only', () {
    StudentRegistryService.instance.applyPersistedStudents([
      AdminStudentRecord(
        studentId: 'STU-FN-1',
        fullName: 'Raey Student',
        grade: '1',
        className: 'Grade 1A',
        schoolId: 'FN0597',
        dateOfBirth: DateTime(2018, 3, 2),
      ),
    ], replace: true);

    SchoolDataService.instance.applyPersistedGradeReports([
      StudentGradeReport(
        studentName: 'Raey Student',
        studentId: 'STU-FN-1',
        className: 'Grade 1A',
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'Mathematics',
            score: 80,
            maxScore: 100,
            status: SubjectGradeStatus.pendingApproval,
            submittedAt: DateTime.utc(2026, 11, 1),
          ),
        ],
      ),
      StudentGradeReport(
        studentName: 'Sara Bekele',
        studentId: 'STU-1001',
        className: 'Grade 4A',
        term: 'Term 1',
        subjects: [
          SubjectGrade(
            subject: 'English',
            score: 92,
            maxScore: 100,
            status: SubjectGradeStatus.pendingApproval,
            submittedAt: DateTime.utc(2026, 11, 1),
          ),
        ],
      ),
    ]);

    signIn('FN0597');
    final pending = SchoolDataService.instance.pendingGradeApprovals(
      schoolId: 'FN0597',
    );
    expect(pending.map((item) => item.report.studentName), ['Raey Student']);
    expect(
      SchoolDataService.instance.pendingGradeApprovalCount(
        schoolId: 'FN0597',
        roleKey: AuthService.roleAdmin,
      ),
      1,
    );
    expect(
      WebAdminStatsService.instance.load().pendingApprovals,
      1,
    );
    expect(
      SchoolDataService.instance
          .getAllGradeReports()
          .map((r) => r.studentName),
      isNot(contains('Sara Bekele')),
    );

    signIn('MAYU-INTL');
    expect(
      SchoolDataService.instance.pendingGradeApprovalCount(
        schoolId: 'MAYU-INTL',
        roleKey: AuthService.roleAdmin,
      ),
      0,
    );
    expect(WebAdminStatsService.instance.load().pendingApprovals, 0);
  });

  test('sample inventory assets stay off a live school', () {
    signIn('TB-001');
    InventoryService.instance.seedDemoDataIfEmpty();
    expect(
      InventoryService.instance.assetsForActiveSchool().map((a) => a.name),
      contains('Epson Projector'),
    );
    expect(
      InventoryService.instance.filteredItems().map((i) => i.name),
      contains('Mathematics Textbook Grade 5'),
    );

    signIn('FN0597');
    InventoryService.instance.seedDemoDataIfEmpty();
    expect(InventoryService.instance.assetsForActiveSchool(), isEmpty);
    expect(InventoryService.instance.filteredItems(), isEmpty);

    InventoryService.instance.applyPersistedData(
      items: [
        InventoryItem(
          id: 'inv-1',
          name: 'Mathematics Textbook Grade 5',
          category: InventoryItemCategory.booksLearning,
          description: 'Official curriculum mathematics book',
          quantityAvailable: 120,
          unit: 'piece',
          minimumStockLevel: 20,
          storageLocation: 'Library Store',
          purchasePrice: 85,
          supplier: 'Ethio Books PLC',
          dateAdded: DateTime(2024, 1, 1),
          schoolId: 'FN0597',
        ),
        InventoryItem(
          id: 'inv-live',
          name: 'Fnote Chalk Box',
          category: InventoryItemCategory.stationery,
          description: 'Classroom chalk',
          quantityAvailable: 10,
          unit: 'box',
          minimumStockLevel: 2,
          storageLocation: 'Store',
          purchasePrice: 20,
          supplier: 'Local',
          dateAdded: DateTime(2026, 11, 1),
          schoolId: 'FN0597',
        ),
      ],
      transactions: [],
      studentIssued: [],
      classroom: [],
      assets: [
        SchoolAsset(
          id: 'ast-1',
          name: 'Epson Projector',
          category: 'Electronics',
          serialNumber: 'EP-2024-001',
          purchaseDate: DateTime(2024, 3, 1),
          purchasePrice: 18500,
          location: 'Grade 5A',
          assignedPerson: 'Science Department',
          schoolId: 'FN0597',
        ),
        SchoolAsset(
          id: 'ast-live',
          name: 'Fnote Laptop',
          category: 'Electronics',
          serialNumber: 'FN-LAP-1',
          purchaseDate: DateTime(2026, 2, 1),
          purchasePrice: 40000,
          location: 'Office',
          assignedPerson: 'Admin',
          schoolId: 'FN0597',
        ),
        SchoolAsset(
          id: 'ast-other',
          name: 'Other School Van',
          category: 'Transport',
          serialNumber: 'VAN-1',
          purchaseDate: DateTime(2024, 1, 1),
          purchasePrice: 1,
          location: 'Gate',
          assignedPerson: 'Driver',
          schoolId: 'TB-001',
        ),
      ],
      suppliers: [],
      maintenance: [],
    );

    expect(
      InventoryService.instance.filteredItems().map((i) => i.name),
      ['Fnote Chalk Box'],
    );
    expect(
      InventoryService.instance.assetsForActiveSchool().map((a) => a.name),
      ['Fnote Laptop'],
    );
  });
}
