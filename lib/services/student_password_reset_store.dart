import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class StudentPasswordResetStore {
  StudentPasswordResetStore._();
  static final instance = StudentPasswordResetStore._();

  static const _key = 'student_password_reset_requests_v1';

  final List<StudentPasswordResetRequest> _requests = [];
  int _nextId = 1;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final rows = await LocalJsonStore.readList(_key);
    _requests
      ..clear()
      ..addAll(rows.map(StudentPasswordResetRequest.fromMap));
    if (_requests.isNotEmpty) {
      final max = _requests
          .map((entry) => int.tryParse(entry.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (max >= _nextId) _nextId = max + 1;
    }
    _loaded = true;
  }

  Future<void> _persist() async {
    await LocalJsonStore.writeList(
      _key,
      _requests.map((entry) => entry.toMap()).toList(),
    );
  }

  Future<StudentPasswordResetRequest> submit({
    required String studentId,
    required String schoolId,
    String? username,
    String? studentName,
  }) async {
    await load();
    final pending = _requests.where(
      (request) =>
          request.studentId == studentId.trim().toUpperCase() &&
          request.status == 'pending',
    );
    if (pending.isNotEmpty) return pending.first;

    final request = StudentPasswordResetRequest(
      id: 'spr-$_nextId',
      studentId: studentId.trim().toUpperCase(),
      schoolId: schoolId.trim().toUpperCase(),
      requestedAt: DateTime.now(),
      username: username?.trim().toLowerCase(),
      studentName: studentName,
    );
    _nextId++;
    _requests.insert(0, request);
    await _persist();
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
    _requests[index] = StudentPasswordResetRequest(
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
    await _persist();
  }
}
