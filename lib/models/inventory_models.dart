import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

enum InventoryItemCategory {
  booksLearning,
  uniforms,
  stationery,
  electronics,
  furniture,
  cleaning,
  transport,
  cafeteria,
  sports,
  laboratory,
}

enum InventoryItemStatus { active, inactive }

enum InventoryStockDirection { stockIn, stockOut }

enum InventoryIssueTarget {
  student,
  teacher,
  classroom,
  department,
}

enum StudentIssueReturnStatus {
  returned,
  notReturned,
  damaged,
  lost,
}

enum AssetCondition { newItem, good, needsRepair, damaged }

enum MaintenanceReportStatus { pending, inProgress, completed }

extension InventoryItemCategoryX on InventoryItemCategory {
  String get label => switch (this) {
        InventoryItemCategory.booksLearning => 'e-Book and Material',
        InventoryItemCategory.uniforms => 'Uniforms',
        InventoryItemCategory.stationery => 'Stationery',
        InventoryItemCategory.electronics => 'Electronics',
        InventoryItemCategory.furniture => 'Furniture',
        InventoryItemCategory.cleaning => 'Cleaning Supplies',
        InventoryItemCategory.transport => 'Transport Supplies',
        InventoryItemCategory.cafeteria => 'Cafeteria Supplies',
        InventoryItemCategory.sports => 'Sports Equipment',
        InventoryItemCategory.laboratory => 'Laboratory Equipment',
      };

  static InventoryItemCategory fromName(String raw) {
    return InventoryItemCategory.values.firstWhere(
      (e) => e.name == raw,
      orElse: () => InventoryItemCategory.stationery,
    );
  }
}

class InventoryItem {
  InventoryItem({
    required this.id,
    required this.name,
    required this.category,
    required this.description,
    required this.quantityAvailable,
    required this.unit,
    required this.minimumStockLevel,
    required this.storageLocation,
    required this.purchasePrice,
    required this.supplier,
    required this.dateAdded,
    this.status = InventoryItemStatus.active,
    this.schoolId,
    this.imagePath,
  });

  final String id;
  final String name;
  final InventoryItemCategory category;
  final String description;
  int quantityAvailable;
  final String unit;
  final int minimumStockLevel;
  final String storageLocation;
  final double purchasePrice;
  final String supplier;
  final DateTime dateAdded;
  InventoryItemStatus status;
  final String? schoolId;
  final String? imagePath;

  double get inventoryValue => quantityAvailable * purchasePrice;

  bool get isLowStock =>
      quantityAvailable > 0 && quantityAvailable <= minimumStockLevel;

  bool get isOutOfStock => quantityAvailable <= 0;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category.name,
        'description': description,
        'quantityAvailable': quantityAvailable,
        'unit': unit,
        'minimumStockLevel': minimumStockLevel,
        'storageLocation': storageLocation,
        'purchasePrice': purchasePrice,
        'supplier': supplier,
        'dateAdded': dateAdded.toIso8601String(),
        'status': status.name,
        if (schoolId != null) 'schoolId': schoolId,
        if (imagePath != null) 'imagePath': imagePath,
      };

  static InventoryItem fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      category: InventoryItemCategoryX.fromName(map['category'] as String? ?? ''),
      description: map['description'] as String? ?? '',
      quantityAvailable: (map['quantityAvailable'] as num?)?.toInt() ?? 0,
      unit: map['unit'] as String? ?? 'piece',
      minimumStockLevel: (map['minimumStockLevel'] as num?)?.toInt() ?? 5,
      storageLocation: map['storageLocation'] as String? ?? 'Main Store',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0,
      supplier: map['supplier'] as String? ?? '',
      dateAdded: DateTime.tryParse(map['dateAdded'] as String? ?? '') ??
          DateTime.now(),
      status: InventoryItemStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => InventoryItemStatus.active,
      ),
      schoolId: map['schoolId'] as String?,
      imagePath: map['imagePath'] as String?,
    );
  }
}

class StockTransaction {
  StockTransaction({
    required this.id,
    required this.direction,
    required this.date,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.actorName,
    this.supplierOrDonor,
    this.invoiceNumber,
    this.receivedBy,
    this.issuedTo,
    this.issueTarget,
    this.approvedBy,
    this.reason,
    this.notes,
    this.schoolId,
    this.invoiceAttachmentPath,
  });

  final String id;
  final InventoryStockDirection direction;
  final DateTime date;
  final String itemId;
  final String itemName;
  final int quantity;
  final String actorName;
  final String? supplierOrDonor;
  final String? invoiceNumber;
  final String? receivedBy;
  final String? issuedTo;
  final InventoryIssueTarget? issueTarget;
  final String? approvedBy;
  final String? reason;
  final String? notes;
  final String? schoolId;
  final String? invoiceAttachmentPath;

  Map<String, dynamic> toMap() => {
        'id': id,
        'direction': direction.name,
        'date': date.toIso8601String(),
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'actorName': actorName,
        if (supplierOrDonor != null) 'supplierOrDonor': supplierOrDonor,
        if (invoiceNumber != null) 'invoiceNumber': invoiceNumber,
        if (receivedBy != null) 'receivedBy': receivedBy,
        if (issuedTo != null) 'issuedTo': issuedTo,
        if (issueTarget != null) 'issueTarget': issueTarget!.name,
        if (approvedBy != null) 'approvedBy': approvedBy,
        if (reason != null) 'reason': reason,
        if (notes != null) 'notes': notes,
        if (schoolId != null) 'schoolId': schoolId,
        if (invoiceAttachmentPath != null)
          'invoiceAttachmentPath': invoiceAttachmentPath,
      };

  static StockTransaction fromMap(Map<String, dynamic> map) {
    return StockTransaction(
      id: map['id'] as String,
      direction: InventoryStockDirection.values.firstWhere(
        (e) => e.name == map['direction'],
        orElse: () => InventoryStockDirection.stockIn,
      ),
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      actorName: map['actorName'] as String? ?? '',
      supplierOrDonor: map['supplierOrDonor'] as String?,
      invoiceNumber: map['invoiceNumber'] as String?,
      receivedBy: map['receivedBy'] as String?,
      issuedTo: map['issuedTo'] as String?,
      issueTarget: map['issueTarget'] == null
          ? null
          : InventoryIssueTarget.values.firstWhere(
              (e) => e.name == map['issueTarget'],
              orElse: () => InventoryIssueTarget.department,
            ),
      approvedBy: map['approvedBy'] as String?,
      reason: map['reason'] as String?,
      notes: map['notes'] as String?,
      schoolId: map['schoolId'] as String?,
      invoiceAttachmentPath: map['invoiceAttachmentPath'] as String?,
    );
  }
}

class StudentIssuedItem {
  StudentIssuedItem({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.gradeClass,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.dateIssued,
    this.returnStatus = StudentIssueReturnStatus.notReturned,
    this.schoolId,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String gradeClass;
  final String itemId;
  final String itemName;
  final int quantity;
  final DateTime dateIssued;
  StudentIssueReturnStatus returnStatus;
  final String? schoolId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'studentId': studentId,
        'studentName': studentName,
        'gradeClass': gradeClass,
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'dateIssued': dateIssued.toIso8601String(),
        'returnStatus': returnStatus.name,
        if (schoolId != null) 'schoolId': schoolId,
      };

  static StudentIssuedItem fromMap(Map<String, dynamic> map) {
    return StudentIssuedItem(
      id: map['id'] as String,
      studentId: map['studentId'] as String? ?? '',
      studentName: map['studentName'] as String? ?? '',
      gradeClass: map['gradeClass'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 1,
      dateIssued:
          DateTime.tryParse(map['dateIssued'] as String? ?? '') ?? DateTime.now(),
      returnStatus: StudentIssueReturnStatus.values.firstWhere(
        (e) => e.name == map['returnStatus'],
        orElse: () => StudentIssueReturnStatus.notReturned,
      ),
      schoolId: map['schoolId'] as String?,
    );
  }
}

class ClassroomInventoryEntry {
  ClassroomInventoryEntry({
    required this.id,
    required this.classroomName,
    required this.grade,
    required this.itemId,
    required this.itemName,
    required this.quantity,
    required this.condition,
    this.schoolId,
  });

  final String id;
  final String classroomName;
  final String grade;
  final String itemId;
  final String itemName;
  final int quantity;
  final String condition;
  final String? schoolId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'classroomName': classroomName,
        'grade': grade,
        'itemId': itemId,
        'itemName': itemName,
        'quantity': quantity,
        'condition': condition,
        if (schoolId != null) 'schoolId': schoolId,
      };

  static ClassroomInventoryEntry fromMap(Map<String, dynamic> map) {
    return ClassroomInventoryEntry(
      id: map['id'] as String,
      classroomName: map['classroomName'] as String? ?? '',
      grade: map['grade'] as String? ?? '',
      itemId: map['itemId'] as String? ?? '',
      itemName: map['itemName'] as String? ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
      condition: map['condition'] as String? ?? 'Good',
      schoolId: map['schoolId'] as String?,
    );
  }
}

class SchoolAsset {
  SchoolAsset({
    required this.id,
    required this.name,
    required this.category,
    required this.serialNumber,
    required this.purchaseDate,
    required this.purchasePrice,
    required this.location,
    required this.assignedPerson,
    this.condition = AssetCondition.good,
    this.schoolId,
    this.imagePath,
  });

  final String id;
  final String name;
  final String category;
  final String serialNumber;
  final DateTime purchaseDate;
  final double purchasePrice;
  final String location;
  final String assignedPerson;
  AssetCondition condition;
  final String? schoolId;
  final String? imagePath;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'category': category,
        'serialNumber': serialNumber,
        'purchaseDate': purchaseDate.toIso8601String(),
        'purchasePrice': purchasePrice,
        'location': location,
        'assignedPerson': assignedPerson,
        'condition': condition.name,
        if (schoolId != null) 'schoolId': schoolId,
        if (imagePath != null) 'imagePath': imagePath,
      };

  static SchoolAsset fromMap(Map<String, dynamic> map) {
    return SchoolAsset(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      category: map['category'] as String? ?? 'Electronics',
      serialNumber: map['serialNumber'] as String? ?? '',
      purchaseDate:
          DateTime.tryParse(map['purchaseDate'] as String? ?? '') ?? DateTime.now(),
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0,
      location: map['location'] as String? ?? '',
      assignedPerson: map['assignedPerson'] as String? ?? '',
      condition: AssetCondition.values.firstWhere(
        (e) => e.name == map['condition'],
        orElse: () => AssetCondition.good,
      ),
      schoolId: map['schoolId'] as String?,
      imagePath: map['imagePath'] as String?,
    );
  }
}

class InventorySupplier {
  InventorySupplier({
    required this.id,
    required this.name,
    required this.contact,
    required this.address,
    required this.productsSupplied,
    this.purchaseHistory = const [],
    this.schoolId,
  });

  final String id;
  final String name;
  final String contact;
  final String address;
  final String productsSupplied;
  final List<String> purchaseHistory;
  final String? schoolId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'contact': contact,
        'address': address,
        'productsSupplied': productsSupplied,
        'purchaseHistory': purchaseHistory,
        if (schoolId != null) 'schoolId': schoolId,
      };

  static InventorySupplier fromMap(Map<String, dynamic> map) {
    return InventorySupplier(
      id: map['id'] as String,
      name: map['name'] as String? ?? '',
      contact: map['contact'] as String? ?? '',
      address: map['address'] as String? ?? '',
      productsSupplied: map['productsSupplied'] as String? ?? '',
      purchaseHistory: (map['purchaseHistory'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      schoolId: map['schoolId'] as String?,
    );
  }
}

class InventoryMaintenanceReport {
  InventoryMaintenanceReport({
    required this.id,
    required this.itemOrAsset,
    required this.reportedBy,
    required this.date,
    required this.description,
    this.status = MaintenanceReportStatus.pending,
    this.schoolId,
  });

  final String id;
  final String itemOrAsset;
  final String reportedBy;
  final DateTime date;
  final String description;
  MaintenanceReportStatus status;
  final String? schoolId;

  Map<String, dynamic> toMap() => {
        'id': id,
        'itemOrAsset': itemOrAsset,
        'reportedBy': reportedBy,
        'date': date.toIso8601String(),
        'description': description,
        'status': status.name,
        if (schoolId != null) 'schoolId': schoolId,
      };

  static InventoryMaintenanceReport fromMap(Map<String, dynamic> map) {
    return InventoryMaintenanceReport(
      id: map['id'] as String,
      itemOrAsset: map['itemOrAsset'] as String? ?? '',
      reportedBy: map['reportedBy'] as String? ?? '',
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime.now(),
      description: map['description'] as String? ?? '',
      status: MaintenanceReportStatus.values.firstWhere(
        (e) => e.name == map['status'],
        orElse: () => MaintenanceReportStatus.pending,
      ),
      schoolId: map['schoolId'] as String?,
    );
  }
}

/// Role-based inventory permissions.
abstract final class InventoryPermissions {
  static String? get currentRole => AuthService.currentUser?.roleKey;

  /// Item catalog edits: owner, or staff who can register purchases /
  /// correct stock (procurement officer, storekeeper).
  static bool get canManageInventory =>
      currentRole == AuthService.roleAdmin ||
      AuthService.hasAnyPermission(const [
        SchoolPermissions.enterPurchasedItems,
        SchoolPermissions.adjustStock,
      ]);

  /// Physical stock movements belong to the storekeeper role.
  static bool get canStockInOut =>
      currentRole == AuthService.roleAdmin ||
      AuthService.hasAnyPermission(const [
        SchoolPermissions.receiveStock,
        SchoolPermissions.issueStock,
      ]);

  static bool get canViewClassroomInventory =>
      currentRole == AuthService.roleAdmin ||
      currentRole == AuthService.roleTeacher;

  static bool get canViewIssuedItems =>
      currentRole == AuthService.roleAdmin ||
      currentRole == AuthService.roleParent ||
      currentRole == AuthService.roleStudent;

  static bool get canViewReports =>
      currentRole == AuthService.roleAdmin ||
      AuthService.hasAnyPermission(const [
        SchoolPermissions.viewInventory,
        SchoolPermissions.viewAllDepartments,
      ]);
}
