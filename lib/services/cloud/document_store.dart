import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';

/// Generic document CRUD against Supabase `app_documents`
/// (Firestore-compatible API for existing stores).
class DocumentStore {
  DocumentStore({SupabaseClient? client})
      : _db = client ??
            (SupabaseBootstrap.isInitialized
                ? SupabaseBootstrap.client
                : null);

  final SupabaseClient? _db;

  bool get available =>
      SupabaseBootstrap.isInitialized && _db != null;

  SupabaseClient get db {
    final c = _db;
    if (c == null) {
      throw StateError('Supabase is not initialized');
    }
    return c;
  }

  Map<String, dynamic> _withSchoolScope(Map<String, dynamic> data) {
    final existing = data['schoolId'] ?? data['school_id'];
    if (existing is String && existing.trim().isNotEmpty) {
      data['schoolId'] = existing.trim().toUpperCase();
      return data;
    }
    final sid = _resolvedSchoolId();
    if (sid == null || sid.isEmpty) return data;
    return {...data, 'schoolId': sid};
  }

  /// Column value for RLS. Must match `jwt_school_id()` (uppercased).
  String? _schoolIdOf(Map<String, dynamic> data) {
    final v = data['schoolId'] ?? data['school_id'];
    if (v is String && v.trim().isNotEmpty) return v.trim().toUpperCase();
    return _resolvedSchoolId();
  }

  String? _resolvedSchoolId() {
    final active = AuthService.activeSchoolId?.trim();
    if (active != null && active.isNotEmpty) return active.toUpperCase();
    final fromUser = AuthService.currentUser?.schoolId?.trim();
    if (fromUser != null && fromUser.isNotEmpty) return fromUser.toUpperCase();
    final meta = _db?.auth.currentUser?.appMetadata;
    final fromMeta = '${meta?['schoolId'] ?? meta?['school_id'] ?? ''}'.trim();
    if (fromMeta.isNotEmpty) return fromMeta.toUpperCase();
    return null;
  }

  Map<String, dynamic> _rowToDoc(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(
      (row['data'] as Map?)?.cast<String, dynamic>() ?? const {},
    );
    data['_docId'] = row['doc_id'];
    return data;
  }

  /// Fees and inventory use an integer [rowVersion] so two editors cannot
  /// silently last-write-wins. The server increments on accept.
  static const versionedCollections = {
    'fees',
    'inventory_items',
    'classroom_inventory',
  };

  @visibleForTesting
  static int clientRowVersion(Map<String, dynamic> data) {
    final v = data['rowVersion'];
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? 0;
  }

  static const _payloadEquality = DeepCollectionEquality();

  static bool _isVersioned(String collection) =>
      versionedCollections.contains(collection);

  /// True when two documents match aside from sync timestamps / local ids.
  /// Used so republishing an unchanged directory does not bump `updated_at`
  /// and wake every other signed-in client.
  @visibleForTesting
  static bool sameDocumentPayload(
    Map<String, dynamic> a,
    Map<String, dynamic> b,
  ) {
    return _payloadEquality.equals(_stripVolatile(a), _stripVolatile(b));
  }

  static Map<String, dynamic> _stripVolatile(Map<String, dynamic> data) {
    final copy = Map<String, dynamic>.from(data);
    copy.remove('_docId');
    copy.remove('updatedAt');
    copy.remove('updated_at');
    copy.remove('rowVersion');
    return copy;
  }

  /// Optimistic-concurrency reject from `app_documents_reject_stale`.
  @visibleForTesting
  static bool isStaleWrite(Object e) {
    final s = '$e'.toLowerCase();
    return s.contains('stale_write') || s.contains('updated elsewhere');
  }

  static bool _isGuardError(Object e) {
    final s = '$e'.toLowerCase();
    return isStaleWrite(e) || s.contains('write_denied');
  }

  /// Version the server expects: the value last stored, not a local 0 default.
  @visibleForTesting
  static int writeRowVersion({
    required String collection,
    Map<String, dynamic>? existing,
    required Map<String, dynamic> incoming,
  }) {
    if (!_isVersioned(collection)) return clientRowVersion(incoming);
    if (existing != null) return clientRowVersion(existing);
    return clientRowVersion(incoming);
  }

  static StateError _guardError(String collection, Object e) {
    final s = '$e'.toLowerCase();
    if (s.contains('stale_write')) {
      return StateError(
        'This $collection record was updated elsewhere. Reload and try again.',
      );
    }
    return StateError('Not allowed to save this $collection record.');
  }

  Future<void> createOrUpdate({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
    bool merge = true,
  }) async {
    final scoped = _withSchoolScope(Map<String, dynamic>.from(data));
    scoped.remove('_docId');

    Map<String, dynamic> payload = scoped;
    Map<String, dynamic>? existing;
    var existingReadFailed = false;
    if (merge) {
      try {
        existing = await readDoc(collection: collection, docId: docId);
        if (existing != null) {
          payload = {...existing, ...scoped};
          payload.remove('_docId');
        }
      } catch (_) {
        existingReadFailed = true;
      }
    }
    if (_isVersioned(collection) && existingReadFailed) {
      await CloudOutboxService.instance.enqueue(
        collection: collection,
        docId: docId,
        op: 'upsert',
        schoolId: _schoolIdOf(payload),
        data: payload,
        reason: 'could not read current rowVersion',
      );
      return;
    }
    if (existing != null && sameDocumentPayload(existing, payload)) {
      await CloudOutboxService.instance.ack(collection, docId);
      return;
    }
    payload['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    if (_isVersioned(collection)) {
      payload['rowVersion'] = writeRowVersion(
        collection: collection,
        existing: existing,
        incoming: payload,
      );
    }

    final schoolId = _schoolIdOf(payload);
    if (schoolId == null || schoolId.isEmpty) {
      throw StateError(
        'Cannot save $collection/$docId without schoolId — sign in to a school first.',
      );
    }

    if (!available) {
      await CloudOutboxService.instance.enqueue(
        collection: collection,
        docId: docId,
        op: 'upsert',
        schoolId: schoolId,
        data: payload,
        reason: 'cloud unavailable',
      );
      return;
    }

    if (collection == 'conversations') {
      try {
        await db.rpc(
          'upsert_school_conversation',
          params: {
            'p_doc_id': docId,
            'p_data': payload,
          },
        );
        await CloudOutboxService.instance.ack(collection, docId);
        return;
      } catch (e) {
        final s = '$e'.toLowerCase();
        final rpcMissing = s.contains('upsert_school_conversation') ||
            s.contains('pgrst202') ||
            s.contains('does not exist') ||
            s.contains('42883') ||
            s.contains('404');
        if (!rpcMissing && _isGuardError(e)) {
          throw _guardError(collection, e);
        }
        if (!rpcMissing && kDebugMode) {
          debugPrint('upsert_school_conversation fallback: $e');
        }
      }
    }

    try {
      await db.from('app_documents').upsert(
        {
          'collection': collection,
          'doc_id': docId,
          'school_id': schoolId,
          'data': payload,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        },
        onConflict: 'collection,school_id,doc_id',
      );
      await CloudOutboxService.instance.ack(collection, docId);
    } catch (e) {
      if (_isGuardError(e)) {
        throw _guardError(collection, e);
      }
      await CloudOutboxService.instance.enqueue(
        collection: collection,
        docId: docId,
        op: 'upsert',
        schoolId: schoolId,
        data: payload,
        reason: '$e',
      );
      rethrow;
    }
  }

  /// Insert-only helper for append-only collections (e.g. school_audit_log).
  /// Skips quietly when the doc already exists so upsert cannot tamper.
  Future<void> insertIfAbsent({
    required String collection,
    required String docId,
    required Map<String, dynamic> data,
  }) async {
    if (!available) return;
    final existing = await readDoc(collection: collection, docId: docId);
    if (existing != null) return;
    final scoped = _withSchoolScope(Map<String, dynamic>.from(data));
    scoped.remove('_docId');
    scoped['updatedAt'] = DateTime.now().toUtc().toIso8601String();
    await db.from('app_documents').insert({
      'collection': collection,
      'doc_id': docId,
      'school_id': _schoolIdOf(scoped),
      'data': scoped,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    });
  }

  Future<void> deleteDoc({
    required String collection,
    required String docId,
  }) async {
    if (!available) {
      await CloudOutboxService.instance.enqueue(
        collection: collection,
        docId: docId,
        op: 'delete',
        schoolId: AuthService.activeSchoolId,
        reason: 'cloud unavailable',
      );
      return;
    }
    final schoolId = AuthService.activeSchoolId?.trim().toUpperCase();
    var q = db
        .from('app_documents')
        .delete()
        .eq('collection', collection)
        .eq('doc_id', docId);
    if (schoolId != null && schoolId.isNotEmpty) {
      q = q.eq('school_id', schoolId);
    }
    try {
      await q;
      await CloudOutboxService.instance.ack(collection, docId);
    } catch (e) {
      await CloudOutboxService.instance.enqueue(
        collection: collection,
        docId: docId,
        op: 'delete',
        schoolId: schoolId,
        reason: '$e',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> readDoc({
    required String collection,
    required String docId,
  }) async {
    if (!available) return null;
    var q = db
        .from('app_documents')
        .select()
        .eq('collection', collection)
        .eq('doc_id', docId);
    final sid = _resolvedSchoolId();
    if (sid != null && sid.isNotEmpty) {
      q = q.eq('school_id', sid);
    }
    final row = await q.maybeSingle();
    if (row == null) return null;
    return _rowToDoc(Map<String, dynamic>.from(row));
  }

  Future<List<Map<String, dynamic>>> readAll(String collection) async {
    return readBySchool(collection, schoolId: null);
  }

  Future<List<Map<String, dynamic>>> readBySchool(
    String collection, {
    String? schoolId,
    String? whereInField,
    List<String>? whereInValues,
    String? arrayContainsAnyField,
    List<String>? arrayContainsAnyValues,
    Map<String, Object?> equals = const {},
    DateTime? updatedSince,
  }) async {
    if (!available) return const [];
    final sid = schoolId?.trim();
    final inValues = (whereInValues ?? const [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    final arrayValues = (arrayContainsAnyValues ?? const [])
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    if (whereInField != null && inValues.isEmpty) return const [];
    if (arrayContainsAnyField != null && arrayValues.isEmpty) {
      return const [];
    }

    try {
      var query = db.from('app_documents').select().eq('collection', collection);
      if (sid != null && sid.isNotEmpty) {
        query = query.eq('school_id', sid.trim().toUpperCase());
      }
      if (updatedSince != null) {
        query = query.gt('updated_at', updatedSince.toUtc().toIso8601String());
      }
      final rows = await query;
      var docs = rows
          .map((r) => _rowToDoc(Map<String, dynamic>.from(r as Map)))
          .toList();

      for (final entry in equals.entries) {
        docs = docs.where((d) => d[entry.key] == entry.value).toList();
      }
      if (whereInField != null) {
        final set = inValues.toSet();
        docs = docs.where((d) => set.contains('${d[whereInField]}')).toList();
      }
      if (arrayContainsAnyField != null) {
        final set = arrayValues.toSet();
        docs = docs.where((d) {
          final raw = d[arrayContainsAnyField];
          if (raw is List) {
            return raw.any((e) => set.contains('$e'));
          }
          return false;
        }).toList();
      }
      return docs;
    } catch (e) {
      if (kDebugMode) {
        debugPrint(
          '[FirestoreCrud] readBySchool($collection, $schoolId) failed: $e',
        );
      }
      rethrow;
    }
  }

  Future<({Map<String, Map<String, dynamic>> byId, bool loadFailed})>
      _existingDocsById(String collection) async {
    try {
      final existing = await readBySchool(
        collection,
        schoolId: _resolvedSchoolId(),
      );
      return (
        byId: {
          for (final doc in existing) '${doc['_docId']}': doc,
        },
        loadFailed: false,
      );
    } catch (_) {
      return (byId: const <String, Map<String, dynamic>>{}, loadFailed: true);
    }
  }

  Future<void> writeBatch({
    required String collection,
    required List<Map<String, dynamic>> items,
    required String Function(Map<String, dynamic> item) docIdFor,
  }) async {
    if (!available || items.isEmpty) return;
    final loaded = await _existingDocsById(collection);
    if (_isVersioned(collection) && loaded.loadFailed) {
      if (kDebugMode) {
        debugPrint(
          '[DocumentStore] skip $collection writeBatch — '
          'could not read current rowVersion',
        );
      }
      return;
    }
    final existingById = loaded.byId;
    const chunkSize = 200;
    for (var start = 0; start < items.length; start += chunkSize) {
      final end = start + chunkSize > items.length
          ? items.length
          : start + chunkSize;
      final chunk = items.sublist(start, end);
      final rows = <Map<String, dynamic>>[];
      for (final item in chunk) {
        final id = docIdFor(item);
        final scoped = _withSchoolScope(Map<String, dynamic>.from(item));
        scoped.remove('_docId');
        final existing = existingById[id];
        if (existing != null && sameDocumentPayload(existing, scoped)) {
          continue;
        }
        scoped['updatedAt'] = DateTime.now().toUtc().toIso8601String();
        if (_isVersioned(collection)) {
          scoped['rowVersion'] = writeRowVersion(
            collection: collection,
            existing: existing,
            incoming: scoped,
          );
        }
        rows.add({
          'collection': collection,
          'doc_id': id,
          'school_id': _schoolIdOf(scoped),
          'data': scoped,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        });
      }
      if (rows.isEmpty) continue;
      await db.from('app_documents').upsert(
        rows,
        onConflict: 'collection,school_id,doc_id',
      );
    }
  }

  Stream<List<Map<String, dynamic>>> watchAll(String collection) {
    if (!available) {
      return const Stream<List<Map<String, dynamic>>>.empty();
    }
    return db
        .from('app_documents')
        .stream(primaryKey: ['collection', 'school_id', 'doc_id'])
        .eq('collection', collection)
        .map(
          (rows) => rows
              .map((r) => _rowToDoc(Map<String, dynamic>.from(r)))
              .toList(),
        );
  }
}
