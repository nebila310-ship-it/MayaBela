import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One queued cloud write. Same [collection]+[docId] is coalesced (last wins).
class CloudOutboxMutation {
  CloudOutboxMutation({
    required this.id,
    required this.collection,
    required this.docId,
    required this.op,
    this.schoolId,
    this.data,
    required this.updatedAt,
  });

  final String id;
  final String collection;
  final String docId;
  /// `upsert` or `delete`
  final String op;
  final String? schoolId;
  final Map<String, dynamic>? data;
  final String updatedAt;

  Map<String, dynamic> toJson() => {
        'id': id,
        'collection': collection,
        'docId': docId,
        'op': op,
        if (schoolId != null) 'schoolId': schoolId,
        if (data != null) 'data': data,
        'updatedAt': updatedAt,
      };

  factory CloudOutboxMutation.fromJson(Map<String, dynamic> json) {
    return CloudOutboxMutation(
      id: json['id'] as String? ?? '',
      collection: json['collection'] as String? ?? '',
      docId: json['docId'] as String? ?? '',
      op: json['op'] as String? ?? 'upsert',
      schoolId: json['schoolId'] as String?,
      data: json['data'] is Map
          ? Map<String, dynamic>.from(json['data'] as Map)
          : null,
      updatedAt: json['updatedAt'] as String? ?? '',
    );
  }
}

/// Write-behind outbox: per-document mutations, with full-snapshot fallback.
class CloudOutboxService extends ChangeNotifier {
  CloudOutboxService._();
  static final instance = CloudOutboxService._();

  static const _pendingKey = 'cloud_outbox_full_push_pending_v1';
  static const _mutationsKey = 'cloud_outbox_mutations_v1';
  static const maxMutations = 400;

  bool _loaded = false;
  bool _pending = false;
  bool _flushing = false;
  List<CloudOutboxMutation> _mutations = [];

  bool get isLoaded => _loaded;
  bool get hasPending => _pending || _mutations.isNotEmpty;
  bool get hasFullPush => _pending;
  bool get isFlushing => _flushing;
  int get mutationCount => _mutations.length;

  /// Mutations plus a full-snapshot marker, for "N changes waiting" copy.
  int get pendingCount => _mutations.length + (_pending ? 1 : 0);

  List<CloudOutboxMutation> snapshotMutations() =>
      List<CloudOutboxMutation>.unmodifiable(_mutations);

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _pending = prefs.getBool(_pendingKey) ?? false;
    final raw = prefs.getString(_mutationsKey);
    _mutations = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          for (final row in decoded) {
            if (row is Map) {
              _mutations.add(
                CloudOutboxMutation.fromJson(Map<String, dynamic>.from(row)),
              );
            }
          }
        }
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[CloudOutbox] mutations parse failed: $e');
        }
      }
    }
    _loaded = true;
    notifyListeners();
  }

  /// Queue one document write. Coalesces prior rows for the same doc.
  Future<void> enqueue({
    required String collection,
    required String docId,
    String op = 'upsert',
    String? schoolId,
    Map<String, dynamic>? data,
    String? reason,
  }) async {
    await ensureLoaded();
    final col = collection.trim();
    final id = docId.trim();
    if (col.isEmpty || id.isEmpty) return;

    _mutations.removeWhere((m) => m.collection == col && m.docId == id);
    _mutations.add(
      CloudOutboxMutation(
        id: '${DateTime.now().microsecondsSinceEpoch}-${Random().nextInt(1 << 20)}',
        collection: col,
        docId: id,
        op: op == 'delete' ? 'delete' : 'upsert',
        schoolId: schoolId?.trim().toUpperCase(),
        data: data == null ? null : Map<String, dynamic>.from(data),
        updatedAt: DateTime.now().toUtc().toIso8601String(),
      ),
    );

    if (_mutations.length > maxMutations) {
      _mutations = _mutations.sublist(_mutations.length - (maxMutations ~/ 2));
      _pending = true;
      if (kDebugMode) {
        debugPrint(
          '[CloudOutbox] mutation cap — falling back to full snapshot'
          '${reason == null ? '' : ': $reason'}',
        );
      }
    } else if (kDebugMode) {
      debugPrint(
        '[CloudOutbox] enqueue $op $col/$id'
        '${reason == null ? '' : ' ($reason)'} n=${_mutations.length}',
      );
    }
    await _persist();
    notifyListeners();
  }

  Future<void> ack(String collection, String docId) async {
    await ensureLoaded();
    final before = _mutations.length;
    _mutations.removeWhere(
      (m) => m.collection == collection && m.docId == docId,
    );
    if (_mutations.length == before) return;
    await _persistMutationsOnly();
    notifyListeners();
  }

  Future<void> markFullPushNeeded({String? reason}) async {
    await ensureLoaded();
    if (_pending) return;
    _pending = true;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, true);
    if (kDebugMode) {
      debugPrint(
        '[CloudOutbox] marked full push'
        '${reason == null ? '' : ': $reason'}',
      );
    }
    notifyListeners();
  }

  Future<void> clearFullPush() async {
    await ensureLoaded();
    if (!_pending) return;
    _pending = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, false);
    notifyListeners();
  }

  Future<void> clear() async {
    await ensureLoaded();
    if (!_pending && _mutations.isEmpty) return;
    _pending = false;
    _mutations = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, false);
    await prefs.remove(_mutationsKey);
    if (kDebugMode) {
      debugPrint('[CloudOutbox] cleared');
    }
    notifyListeners();
  }

  void setFlushing(bool value) {
    if (_flushing == value) return;
    _flushing = value;
    notifyListeners();
  }

  @visibleForTesting
  Future<void> resetForTest() async {
    _loaded = false;
    _pending = false;
    _flushing = false;
    _mutations = [];
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_pendingKey, _pending);
    await _persistMutationsOnly(prefs);
  }

  Future<void> _persistMutationsOnly([SharedPreferences? existing]) async {
    final prefs = existing ?? await SharedPreferences.getInstance();
    if (_mutations.isEmpty) {
      await prefs.remove(_mutationsKey);
      return;
    }
    await prefs.setString(
      _mutationsKey,
      jsonEncode(_mutations.map((m) => m.toJson()).toList()),
    );
  }
}
