import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

enum LibraryCopyStatus { available, checkedOut, lost }

class LibraryCopy {
  LibraryCopy({
    required this.id,
    required this.materialId,
    required this.bookTitle,
    required this.copyCode,
    required this.status,
  });

  final String id;
  final String materialId;
  final String bookTitle;
  final String copyCode;
  LibraryCopyStatus status;

  bool get isAvailable => status == LibraryCopyStatus.available;

  Map<String, dynamic> toMap() => {
        'id': id,
        'materialId': materialId,
        'bookTitle': bookTitle,
        'copyCode': copyCode,
        'status': status.name,
        if (AuthService.activeSchoolId != null)
          'schoolId': AuthService.activeSchoolId,
      };

  static LibraryCopy? fromMap(Map<String, dynamic> map) {
    try {
      final raw = (map['status'] as String? ?? 'available').toLowerCase();
      final status = LibraryCopyStatus.values.firstWhere(
        (s) => s.name == raw,
        orElse: () => LibraryCopyStatus.available,
      );
      return LibraryCopy(
        id: map['id'] as String,
        materialId: map['materialId'] as String? ?? '',
        bookTitle: map['bookTitle'] as String? ?? '',
        copyCode: map['copyCode'] as String? ?? map['id'] as String,
        status: status,
      );
    } catch (_) {
      return null;
    }
  }
}

class LibraryRental {
  LibraryRental({
    required this.id,
    required this.materialId,
    required this.bookTitle,
    required this.studentId,
    required this.studentName,
    required this.isPaid,
    required this.rentedAt,
    this.price,
    this.returnedAt,
    this.notes,
    this.copyId,
    this.copyCode,
    this.dueDate,
  });

  final String id;
  final String materialId;
  final String bookTitle;
  final String studentId;
  final String studentName;
  final bool isPaid;
  final double? price;
  final DateTime rentedAt;
  DateTime? returnedAt;
  final String? notes;
  final String? copyId;
  final String? copyCode;
  final DateTime? dueDate;

  bool get isActive => returnedAt == null;

  bool get isPhysical => (copyId ?? '').trim().isNotEmpty;

  bool isOverdue([DateTime? asOf]) {
    if (!isActive || dueDate == null) return false;
    final now = asOf ?? DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final day = DateTime(now.year, now.month, now.day);
    return due.isBefore(day);
  }

  int daysOverdue([DateTime? asOf]) {
    if (!isOverdue(asOf) || dueDate == null) return 0;
    final now = asOf ?? DateTime.now();
    final due = DateTime(dueDate!.year, dueDate!.month, dueDate!.day);
    final day = DateTime(now.year, now.month, now.day);
    return day.difference(due).inDays;
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'materialId': materialId,
        'bookTitle': bookTitle,
        'studentId': studentId,
        'studentName': studentName,
        'isPaid': isPaid,
        if (price != null) 'price': price,
        'rentedAt': rentedAt.toIso8601String(),
        if (returnedAt != null) 'returnedAt': returnedAt!.toIso8601String(),
        if (notes != null) 'notes': notes,
        if (copyId != null) 'copyId': copyId,
        if (copyCode != null) 'copyCode': copyCode,
        if (dueDate != null) 'dueDate': dueDate!.toIso8601String(),
        if (AuthService.activeSchoolId != null)
          'schoolId': AuthService.activeSchoolId,
      };

  static LibraryRental? fromMap(Map<String, dynamic> map) {
    try {
      return LibraryRental(
        id: map['id'] as String,
        materialId: map['materialId'] as String? ?? '',
        bookTitle: map['bookTitle'] as String? ?? '',
        studentId: (map['studentId'] as String? ?? '').toUpperCase(),
        studentName: map['studentName'] as String? ?? '',
        isPaid: map['isPaid'] as bool? ?? false,
        price: (map['price'] as num?)?.toDouble(),
        rentedAt: DateTime.parse(map['rentedAt'] as String),
        returnedAt: map['returnedAt'] == null
            ? null
            : DateTime.tryParse(map['returnedAt'] as String),
        notes: map['notes'] as String?,
        copyId: map['copyId'] as String?,
        copyCode: map['copyCode'] as String?,
        dueDate: map['dueDate'] == null
            ? null
            : DateTime.tryParse(map['dueDate'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

class LibraryCopyCounts {
  const LibraryCopyCounts({
    required this.total,
    required this.available,
    required this.checkedOut,
  });

  final int total;
  final int available;
  final int checkedOut;
}

/// Physical copies plus digital / paid book rentals for the Library module.
class LibraryRentalService extends ChangeNotifier {
  LibraryRentalService._();
  static final instance = LibraryRentalService._();

  static const defaultLoanDays = 14;
  static const _localKey = 'persisted_library_rentals';
  static const _copiesLocalKey = 'persisted_library_copies';
  static const collection = 'library_rentals';
  static const copiesCollection = 'library_copies';

  final List<LibraryRental> _rentals = [];
  final List<LibraryCopy> _copies = [];
  bool _loaded = false;

  List<LibraryRental> get all => List.unmodifiable(_rentals);

  List<LibraryCopy> get copies => List.unmodifiable(_copies);

  List<LibraryRental> get active =>
      _rentals.where((r) => r.isActive).toList(growable: false);

  @visibleForTesting
  void resetForTests() {
    _rentals.clear();
    _copies.clear();
    _loaded = false;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final local = await LocalJsonStore.readList(_localKey);
    _rentals
      ..clear()
      ..addAll(
        local.map(LibraryRental.fromMap).whereType<LibraryRental>(),
      );
    final localCopies = await LocalJsonStore.readList(_copiesLocalKey);
    _copies
      ..clear()
      ..addAll(
        localCopies.map(LibraryCopy.fromMap).whereType<LibraryCopy>(),
      );

    final crud = DocumentStore();
    if (crud.available) {
      try {
        final rows = await crud.readBySchool(
          collection,
          schoolId: AuthService.activeSchoolId,
        );
        for (final row in rows) {
          final rental = LibraryRental.fromMap(row);
          if (rental == null) continue;
          final idx = _rentals.indexWhere((r) => r.id == rental.id);
          if (idx >= 0) {
            _rentals[idx] = rental;
          } else {
            _rentals.add(rental);
          }
        }
        final copyRows = await crud.readBySchool(
          copiesCollection,
          schoolId: AuthService.activeSchoolId,
        );
        for (final row in copyRows) {
          final copy = LibraryCopy.fromMap(row);
          if (copy == null) continue;
          final idx = _copies.indexWhere((c) => c.id == copy.id);
          if (idx >= 0) {
            _copies[idx] = copy;
          } else {
            _copies.add(copy);
          }
        }
      } catch (e) {
        if (kDebugMode) debugPrint('LibraryRentalService cloud load: $e');
      }
    }

    _rentals.sort((a, b) => b.rentedAt.compareTo(a.rentedAt));
    _sortCopies();
    _loaded = true;
    notifyListeners();
  }

  void applyPersisted(List<LibraryRental> rows, {bool merge = true}) {
    if (!merge) _rentals.clear();
    for (final rental in rows) {
      final idx = _rentals.indexWhere((item) => item.id == rental.id);
      if (idx >= 0) {
        _rentals[idx] = rental;
      } else {
        _rentals.add(rental);
      }
    }
    _rentals.sort((a, b) => b.rentedAt.compareTo(a.rentedAt));
    _loaded = true;
    notifyListeners();
  }

  void applyPersistedCopies(List<LibraryCopy> rows, {bool merge = true}) {
    if (!merge) _copies.clear();
    for (final copy in rows) {
      final idx = _copies.indexWhere((item) => item.id == copy.id);
      if (idx >= 0) {
        _copies[idx] = copy;
      } else {
        _copies.add(copy);
      }
    }
    _sortCopies();
    _loaded = true;
    notifyListeners();
  }

  List<LibraryCopy> copiesFor(String materialId) {
    return _copies
        .where((c) => c.materialId == materialId)
        .toList(growable: false);
  }

  List<LibraryCopy> availableCopies(String materialId) {
    return copiesFor(materialId).where((c) => c.isAvailable).toList();
  }

  LibraryCopyCounts copyCounts(String materialId) {
    final rows = copiesFor(materialId);
    return LibraryCopyCounts(
      total: rows.length,
      available: rows.where((c) => c.isAvailable).length,
      checkedOut: rows.where((c) => c.status == LibraryCopyStatus.checkedOut).length,
    );
  }

  List<LibraryRental> loansForStudent(String studentId) {
    final id = studentId.trim().toUpperCase();
    return _rentals
        .where((r) => r.studentId == id)
        .toList(growable: false);
  }

  List<LibraryRental> overdue({DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    return _rentals.where((r) => r.isOverdue(now)).toList(growable: false)
      ..sort((a, b) => (a.dueDate ?? a.rentedAt).compareTo(b.dueDate ?? b.rentedAt));
  }

  String overdueCsv({DateTime? asOf}) {
    final now = asOf ?? DateTime.now();
    final rows = <List<String>>[
      ['Copy', 'Title', 'Student ID', 'Name', 'Due', 'Days overdue'],
    ];
    for (final loan in overdue(asOf: now)) {
      rows.add([
        loan.copyCode ?? '',
        loan.bookTitle,
        loan.studentId,
        loan.studentName,
        loan.dueDate == null ? '' : _isoDay(loan.dueDate!),
        '${loan.daysOverdue(now)}',
      ]);
    }
    return rows.map(_csvLine).join('\n');
  }

  Future<List<LibraryCopy>> addCopies({
    required String materialId,
    required String bookTitle,
    required int count,
  }) async {
    if (count <= 0) return const [];
    final existing = copiesFor(materialId).length;
    final created = <LibraryCopy>[];
    final stamp = DateTime.now().millisecondsSinceEpoch;
    for (var i = 0; i < count; i++) {
      final n = existing + i + 1;
      final copy = LibraryCopy(
        id: 'copy-$stamp-$n',
        materialId: materialId,
        bookTitle: bookTitle,
        copyCode: _copyCode(bookTitle, n),
        status: LibraryCopyStatus.available,
      );
      _copies.add(copy);
      created.add(copy);
    }
    _sortCopies();
    notifyListeners();
    for (final copy in created) {
      await _persistCopy(copy);
    }
    return created;
  }

  Future<LibraryRental> checkout({
    required String copyId,
    required String studentId,
    required String studentName,
    DateTime? dueDate,
    bool isPaid = false,
    double? price,
    String? notes,
  }) async {
    final idx = _copies.indexWhere((c) => c.id == copyId);
    if (idx < 0) {
      throw StateError('Library copy was not found.');
    }
    final copy = _copies[idx];
    if (!copy.isAvailable) {
      throw StateError('That copy is already checked out.');
    }
    copy.status = LibraryCopyStatus.checkedOut;
    final loan = LibraryRental(
      id: 'loan-${DateTime.now().millisecondsSinceEpoch}',
      materialId: copy.materialId,
      bookTitle: copy.bookTitle,
      studentId: studentId.trim().toUpperCase(),
      studentName: studentName.trim(),
      isPaid: isPaid,
      price: isPaid ? price : null,
      rentedAt: DateTime.now(),
      notes: notes,
      copyId: copy.id,
      copyCode: copy.copyCode,
      dueDate: dueDate ?? DateTime.now().add(const Duration(days: defaultLoanDays)),
    );
    _rentals.insert(0, loan);
    notifyListeners();
    await _persistCopy(copy);
    await _persist(loan);
    return loan;
  }

  Future<LibraryRental> rent({
    required String materialId,
    required String bookTitle,
    required String studentId,
    required String studentName,
    required bool isPaid,
    double? price,
    String? notes,
  }) async {
    final rental = LibraryRental(
      id: 'rent-${DateTime.now().millisecondsSinceEpoch}',
      materialId: materialId,
      bookTitle: bookTitle,
      studentId: studentId.trim().toUpperCase(),
      studentName: studentName.trim(),
      isPaid: isPaid,
      price: isPaid ? price : null,
      rentedAt: DateTime.now(),
      notes: notes,
    );
    _rentals.insert(0, rental);
    notifyListeners();
    await _persist(rental);
    return rental;
  }

  Future<void> markReturned(String rentalId) async {
    final idx = _rentals.indexWhere((r) => r.id == rentalId);
    if (idx < 0) return;
    _rentals[idx].returnedAt = DateTime.now();
    final copyId = _rentals[idx].copyId;
    if (copyId != null) {
      final copyIdx = _copies.indexWhere((c) => c.id == copyId);
      if (copyIdx >= 0) {
        _copies[copyIdx].status = LibraryCopyStatus.available;
        await _persistCopy(_copies[copyIdx]);
      }
    }
    notifyListeners();
    await _persist(_rentals[idx]);
  }

  Future<void> _persist(LibraryRental rental) async {
    await LocalJsonStore.writeList(
      _localKey,
      _rentals.map((r) => r.toMap()).toList(),
    );
    final crud = DocumentStore();
    if (!crud.available) return;
    try {
      await crud.createOrUpdate(
        collection: collection,
        docId: rental.id,
        data: rental.toMap(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('LibraryRentalService persist: $e');
    }
  }

  Future<void> _persistCopy(LibraryCopy copy) async {
    await LocalJsonStore.writeList(
      _copiesLocalKey,
      _copies.map((c) => c.toMap()).toList(),
    );
    final crud = DocumentStore();
    if (!crud.available) return;
    try {
      await crud.createOrUpdate(
        collection: copiesCollection,
        docId: copy.id,
        data: copy.toMap(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('LibraryRentalService copy persist: $e');
    }
  }

  void _sortCopies() {
    _copies.sort((a, b) {
      final title = a.bookTitle.compareTo(b.bookTitle);
      if (title != 0) return title;
      return a.copyCode.compareTo(b.copyCode);
    });
  }

  static String _copyCode(String bookTitle, int n) {
    final slug = bookTitle
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9]+'), '')
        .padRight(4, 'X')
        .substring(0, 4);
    return '$slug-${n.toString().padLeft(3, '0')}';
  }

  static String _isoDay(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _csvLine(List<String> cells) {
    return cells.map((cell) {
      if (cell.contains(',') || cell.contains('"') || cell.contains('\n')) {
        return '"${cell.replaceAll('"', '""')}"';
      }
      return cell;
    }).join(',');
  }
}
