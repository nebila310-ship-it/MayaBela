import 'package:flutter/foundation.dart';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';

class StudentPasswordResetStore extends ChangeNotifier {
  StudentPasswordResetStore._();
  static final instance = StudentPasswordResetStore._();

  static const _key = 'student_password_reset_requests_v1';
  static const collection = AppCollections.studentPasswordResets;

  final List<StudentPasswordResetRequest> _requests = [];
  int _nextId = 1;
  bool _loaded = false;

  List<StudentPasswordResetRequest> get all => List.unmodifiable(_requests);

  Future<void> load() async {
    if (_loaded) return;
    final rows = await LocalJsonStore.readList(_key);
    _requests
      ..clear()
      ..addAll(rows.map(StudentPasswordResetRequest.fromMap));
    _bumpNextId();
    await _mergeCloud();
    _loaded = true;
    notifyListeners();
  }

  void applyPersisted(
    List<StudentPasswordResetRequest> rows, {
    bool merge = true,
  }) {
    if (!merge) _requests.clear();
    for (final row in rows) {
      if (row.id.trim().isEmpty) continue;
      final idx = _requests.indexWhere((item) => item.id == row.id);
      if (idx >= 0) {
        _requests[idx] = _newer(row, _requests[idx]);
      } else {
        _requests.add(row);
      }
    }
    _bumpNextId();
    _loaded = true;
    notifyListeners();
  }

  @visibleForTesting
  void resetForTests() {
    _requests.clear();
    _nextId = 1;
    _loaded = true;
  }

  Future<void> _persistLocal() async {
    await LocalJsonStore.writeList(
      _key,
      _requests.map((entry) => entry.toMap()).toList(),
    );
  }

  Future<void> _mergeCloud() async {
    final crud = DocumentStore();
    if (!crud.available) return;
    try {
      final rows = await crud.readBySchool(
        collection,
        schoolId: AuthService.activeSchoolId,
      );
      applyPersisted(
        rows.map(StudentPasswordResetRequest.fromMap).toList(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StudentPasswordResetStore cloud load: $e');
      }
    }
  }

  Future<void> _requestCloud(StudentPasswordResetRequest request) async {
    try {
      await SchoolAuthCloudService.instance.requestStudentPasswordReset(
        schoolId: request.schoolId,
        identifier: request.username ?? request.studentId,
        studentId: request.studentId,
        studentName: request.studentName,
        username: request.username,
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StudentPasswordResetStore cloud request: $e');
      }
    }
  }

  Future<void> _pushCloud(StudentPasswordResetRequest request) async {
    final crud = DocumentStore();
    if (!crud.available) return;
    try {
      await crud.createOrUpdate(
        collection: collection,
        docId: request.id,
        data: request.toMap(),
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('StudentPasswordResetStore cloud save: $e');
      }
    }
  }

  static String requestIdFor({
    required String schoolId,
    required String studentId,
  }) {
    return 'spr-${schoolId.trim().toUpperCase()}-${studentId.trim().toUpperCase()}';
  }

  Future<StudentPasswordResetRequest> submit({
    required String studentId,
    required String schoolId,
    String? username,
    String? studentName,
  }) async {
    await load();
    final sid = studentId.trim().toUpperCase();
    final school = schoolId.trim().toUpperCase();
    final pending = _requests.where(
      (request) => request.studentId == sid && request.status == 'pending',
    );
    if (pending.isNotEmpty) {
      await _requestCloud(pending.first);
      await _pushCloud(pending.first);
      return pending.first;
    }

    final request = StudentPasswordResetRequest(
      id: requestIdFor(schoolId: school, studentId: sid),
      studentId: sid,
      schoolId: school,
      requestedAt: DateTime.now(),
      username: username?.trim().toLowerCase(),
      studentName: studentName,
    );
    _nextId++;
    _requests.insert(0, request);
    await _persistLocal();
    await _requestCloud(request);
    await _pushCloud(request);
    notifyListeners();
    return request;
  }

  List<StudentPasswordResetRequest> pendingForSchool(String schoolId) {
    final id = schoolId.trim().toUpperCase();
    return _requests
        .where((request) => request.schoolId == id && request.status == 'pending')
        .toList();
  }

  Future<void> resolve(String requestId, {required String resolvedBy}) async {
    await load();
    final index = _requests.indexWhere((request) => request.id == requestId);
    if (index < 0) return;
    final current = _requests[index];
    final updated = StudentPasswordResetRequest(
      id: current.id,
      studentId: current.studentId,
      schoolId: current.schoolId,
      requestedAt: current.requestedAt,
      username: current.username,
      studentName: current.studentName,
      status: 'resolved',
      resolvedAt: DateTime.now(),
      resolvedBy: resolvedBy,
    );
    _requests[index] = updated;
    await _persistLocal();
    await _pushCloud(updated);
    notifyListeners();
  }

  void _bumpNextId() {
    if (_requests.isEmpty) return;
    final max = _requests
        .map((entry) => int.tryParse(entry.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    if (max >= _nextId) _nextId = max + 1;
  }

  StudentPasswordResetRequest _newer(
    StudentPasswordResetRequest incoming,
    StudentPasswordResetRequest existing,
  ) {
    final incomingStamp = incoming.resolvedAt ?? incoming.requestedAt;
    final existingStamp = existing.resolvedAt ?? existing.requestedAt;
    if (incoming.status == 'resolved' && existing.status != 'resolved') {
      return incoming;
    }
    if (incomingStamp.isAfter(existingStamp)) return incoming;
    return existing;
  }
}
