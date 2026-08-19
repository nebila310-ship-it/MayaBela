import 'package:mayabela/models/grade_workflow.dart';

import 'package:mayabela/services/persistence/grade_audit_persistence_service.dart';



class GradeAuditService {

  GradeAuditService._();

  static final instance = GradeAuditService._();



  static const maxEntries = 1000;



  final List<GradeAuditEntry> _entries = [];

  int _nextId = 1;

  bool _loaded = false;



  static GradeAuditEntry entryFromMap(Map<String, dynamic> map) =>

      GradeAuditEntry.fromMap(map);



  Future<void> load() async {

    if (_loaded) return;

    await GradeAuditPersistenceService.instance.loadIntoService();

    _loaded = true;

  }



  void applyPersistedEntries(List<GradeAuditEntry> entries) {

    for (final entry in entries) {

      final index = _entries.indexWhere((item) => item.id == entry.id);

      if (index >= 0) {

        _entries[index] = entry;

      } else {

        _entries.add(entry);

      }

      final numeric =

          int.tryParse(entry.id.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;

      if (numeric >= _nextId) _nextId = numeric + 1;

    }

    _entries.sort((a, b) => b.at.compareTo(a.at));

    if (_entries.length > maxEntries) {

      _entries.removeRange(maxEntries, _entries.length);

    }

    _loaded = true;

  }



  List<Map<String, dynamic>> snapshotMaps() =>

      _entries.map((entry) => entry.toMap()).toList();



  int nextIdSnapshot() => _nextId;



  Future<void> log({

    required GradeAuditAction action,

    required String schoolId,

    required String className,

    required String subject,

    required String studentName,

    String? studentId,

    String? actorId,

    String? actorName,

    String? actorRole,

    String? detail,

    SubjectGradeStatus? statusBefore,

    SubjectGradeStatus? statusAfter,

  }) async {

    await load();

    final entry = GradeAuditEntry(

      id: 'grade-audit-$_nextId',

      at: DateTime.now(),

      action: action,

      schoolId: schoolId.trim().toUpperCase(),

      className: className,

      subject: subject,

      studentName: studentName,

      studentId: studentId?.trim().toUpperCase(),

      actorId: actorId,

      actorName: actorName,

      actorRole: actorRole,

      detail: detail,

      statusBefore: statusBefore?.name,

      statusAfter: statusAfter?.name,

    );

    _entries.insert(0, entry);

    _nextId++;

    if (_entries.length > maxEntries) {

      _entries.removeRange(maxEntries, _entries.length);

    }

    await GradeAuditPersistenceService.instance.saveFromService();

  }



  List<GradeAuditEntry> recentForSchool(String schoolId, {int limit = 200}) {

    final id = schoolId.trim().toUpperCase();

    return _entries.where((entry) => entry.schoolId == id).take(limit).toList();

  }



  List<GradeAuditEntry> forStudent({

    required String studentName,

    String? className,

    String? subject,

    int limit = 50,

  }) {

    return _entries

        .where(

          (entry) =>

              entry.studentName == studentName &&

              (className == null || entry.className == className) &&

              (subject == null || entry.subject == subject),

        )

        .take(limit)

        .toList();

  }

}

