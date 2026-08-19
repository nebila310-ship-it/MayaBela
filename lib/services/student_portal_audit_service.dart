import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class StudentPortalAuditService {
  StudentPortalAuditService._();
  static final instance = StudentPortalAuditService._();

  static const _key = 'student_portal_audit_v1';
  static const maxEntries = 500;

  final List<StudentPortalAuditEntry> _entries = [];
  int _nextId = 1;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    final rows = await LocalJsonStore.readList(_key);
    _entries
      ..clear()
      ..addAll(rows.map(StudentPortalAuditEntry.fromMap));
    if (_entries.isNotEmpty) {
      final max = _entries
          .map((entry) => int.tryParse(entry.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
          .fold<int>(0, (a, b) => a > b ? a : b);
      if (max >= _nextId) _nextId = max + 1;
    }
    _loaded = true;
  }

  Future<void> log({
    required StudentPortalAuditAction action,
    required String schoolId,
    String? studentId,
    String? username,
    String? actor,
    String? detail,
  }) async {
    await load();
    _entries.insert(
      0,
      StudentPortalAuditEntry(
        id: 'sp-audit-$_nextId',
        at: DateTime.now(),
        action: action,
        schoolId: schoolId.trim().toUpperCase(),
        studentId: studentId?.trim().toUpperCase(),
        username: username?.trim().toLowerCase(),
        actor: actor,
        detail: detail,
      ),
    );
    _nextId++;
    if (_entries.length > maxEntries) {
      _entries.removeRange(maxEntries, _entries.length);
    }
    await LocalJsonStore.writeList(
      _key,
      _entries.map((entry) => entry.toMap()).toList(),
    );
  }

  List<StudentPortalAuditEntry> recentForSchool(String schoolId, {int limit = 100}) {
    final id = schoolId.trim().toUpperCase();
    return _entries.where((entry) => entry.schoolId == id).take(limit).toList();
  }

  List<StudentPortalAuditEntry> recentForStudent(String studentId, {int limit = 50}) {
    final id = studentId.trim().toUpperCase();
    return _entries.where((entry) => entry.studentId == id).take(limit).toList();
  }
}
