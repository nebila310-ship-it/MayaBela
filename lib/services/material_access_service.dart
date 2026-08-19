import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/document_store.dart';

/// Per-student entitlements for paid learning materials.
///
/// Grants live in the `material_access` collection (doc id
/// `<materialId>__<studentId>`). The server-side write guard only lets
/// admins and teachers create or remove grants, so students/parents cannot
/// unlock materials themselves.
class MaterialAccessService extends ChangeNotifier {
  MaterialAccessService._();
  static final instance = MaterialAccessService._();

  static const collection = 'material_access';

  DocumentStore get _crud => DocumentStore();

  /// materialId -> set of unlocked student IDs (uppercase).
  final Map<String, Set<String>> _grants = {};
  bool _loaded = false;
  Future<void>? _loading;

  static String _docId(String materialId, String studentId) =>
      '${materialId}__${studentId.toUpperCase()}';

  /// Loads all grants for the active school. Cheap to call repeatedly.
  Future<void> ensureLoaded({bool forceRefresh = false}) async {
    if (_loaded && !forceRefresh) return;
    final inFlight = _loading;
    if (inFlight != null && !forceRefresh) return inFlight;
    final future = _loadFromCloud();
    _loading = future;
    try {
      await future;
    } finally {
      _loading = null;
    }
  }

  Future<void> _loadFromCloud() async {
    if (!_crud.available) return;
    try {
      final rows = await _crud.readBySchool(
        collection,
        schoolId: AuthService.activeSchoolId,
      );
      _grants.clear();
      for (final row in rows) {
        final materialId = (row['materialId'] as String?)?.trim() ?? '';
        final studentId =
            (row['studentId'] as String?)?.trim().toUpperCase() ?? '';
        if (materialId.isEmpty || studentId.isEmpty) continue;
        _grants.putIfAbsent(materialId, () => <String>{}).add(studentId);
      }
      _loaded = true;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('MaterialAccessService.load failed: $e');
      }
    }
  }

  /// Whether the given viewer (any of [studentIds]) can open [item].
  bool hasAccess(LearningMaterialItem item, {required List<String> studentIds}) {
    if (item.isFree) return true;
    final unlocked = _grants[item.id];
    if (unlocked == null || unlocked.isEmpty) return false;
    return studentIds.any((id) => unlocked.contains(id.toUpperCase()));
  }

  Set<String> unlockedStudentIds(String materialId) =>
      Set.unmodifiable(_grants[materialId] ?? const <String>{});

  Future<void> grant({
    required String materialId,
    required String studentId,
    required String grantedBy,
  }) async {
    final sid = studentId.trim().toUpperCase();
    if (sid.isEmpty) return;
    _grants.putIfAbsent(materialId, () => <String>{}).add(sid);
    notifyListeners();
    if (!_crud.available) return;
    await _crud.createOrUpdate(
      collection: collection,
      docId: _docId(materialId, sid),
      data: {
        'materialId': materialId,
        'studentId': sid,
        'grantedBy': grantedBy,
        'grantedAt': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<void> revoke({
    required String materialId,
    required String studentId,
  }) async {
    final sid = studentId.trim().toUpperCase();
    _grants[materialId]?.remove(sid);
    notifyListeners();
    if (!_crud.available) return;
    await _crud.deleteDoc(
      collection: collection,
      docId: _docId(materialId, sid),
    );
  }

  /// Clears cached grants (e.g. on logout / school switch).
  void reset() {
    _grants.clear();
    _loaded = false;
    notifyListeners();
  }
}
