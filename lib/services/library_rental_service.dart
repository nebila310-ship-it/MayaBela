import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

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

  bool get isActive => returnedAt == null;

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
      );
    } catch (_) {
      return null;
    }
  }
}

/// Physical / digital book rentals for the Library module.
class LibraryRentalService extends ChangeNotifier {
  LibraryRentalService._();
  static final instance = LibraryRentalService._();

  static const _localKey = 'persisted_library_rentals';
  static const collection = 'library_rentals';

  final List<LibraryRental> _rentals = [];
  bool _loaded = false;

  List<LibraryRental> get all => List.unmodifiable(_rentals);

  List<LibraryRental> get active =>
      _rentals.where((r) => r.isActive).toList(growable: false);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final local = await LocalJsonStore.readList(_localKey);
    _rentals
      ..clear()
      ..addAll(
        local.map(LibraryRental.fromMap).whereType<LibraryRental>(),
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
      } catch (e) {
        if (kDebugMode) debugPrint('LibraryRentalService cloud load: $e');
      }
    }

    _rentals.sort((a, b) => b.rentedAt.compareTo(a.rentedAt));
    _loaded = true;
    notifyListeners();
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
}
