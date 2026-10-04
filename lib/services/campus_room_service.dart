import 'package:flutter/foundation.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/services/persistence/local_json_store.dart';

class CampusRoom {
  const CampusRoom({
    required this.id,
    required this.campusName,
    required this.roomName,
  });

  final String id;
  final String campusName;
  final String roomName;

  String get label => '$campusName · $roomName';

  Map<String, dynamic> toMap() => {
        'id': id,
        'campusName': campusName,
        'roomName': roomName,
        if (AuthService.activeSchoolId != null)
          'schoolId': AuthService.activeSchoolId,
      };

  static CampusRoom? fromMap(Map<String, dynamic> map) {
    try {
      final room = (map['roomName'] as String? ?? '').trim();
      if (room.isEmpty) return null;
      return CampusRoom(
        id: map['id'] as String,
        campusName: (map['campusName'] as String? ?? 'Main Campus').trim(),
        roomName: room,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Rooms live on the Campus Management list — not a second campus ledger.
class CampusRoomService extends ChangeNotifier {
  CampusRoomService._();
  static final instance = CampusRoomService._();

  static const collection = 'campus_rooms';
  static const _localKey = 'persisted_campus_rooms';

  final List<CampusRoom> _rooms = [];
  bool _loaded = false;

  List<CampusRoom> get all => List.unmodifiable(_rooms);

  @visibleForTesting
  void resetForTests() {
    _rooms.clear();
    _loaded = false;
  }

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    final local = await LocalJsonStore.readList(_localKey);
    _rooms
      ..clear()
      ..addAll(local.map(CampusRoom.fromMap).whereType<CampusRoom>());

    final crud = DocumentStore();
    if (crud.available) {
      try {
        final rows = await crud.readBySchool(
          collection,
          schoolId: AuthService.activeSchoolId,
        );
        applyPersisted(
          rows.map(CampusRoom.fromMap).whereType<CampusRoom>().toList(),
        );
      } catch (e) {
        if (kDebugMode) debugPrint('CampusRoomService cloud load: $e');
      }
    }
    _sort();
    _loaded = true;
    notifyListeners();
  }

  void applyPersisted(List<CampusRoom> rows, {bool merge = true}) {
    if (!merge) _rooms.clear();
    for (final room in rows) {
      final idx = _rooms.indexWhere((r) => r.id == room.id);
      if (idx >= 0) {
        _rooms[idx] = room;
      } else {
        _rooms.add(room);
      }
    }
    _sort();
    _loaded = true;
    notifyListeners();
  }

  List<CampusRoom> roomsForCampus(String campusName) {
    return _rooms
        .where((r) => r.campusName.toLowerCase() == campusName.toLowerCase())
        .toList(growable: false);
  }

  Future<CampusRoom?> addRoom({
    required String campusName,
    required String roomName,
  }) async {
    final campus = campusName.trim();
    final room = roomName.trim();
    if (campus.isEmpty || room.isEmpty) return null;
    if (_rooms.any(
      (r) =>
          r.campusName.toLowerCase() == campus.toLowerCase() &&
          r.roomName.toLowerCase() == room.toLowerCase(),
    )) {
      return null;
    }
    final created = CampusRoom(
      id: 'room-${DateTime.now().millisecondsSinceEpoch}',
      campusName: campus,
      roomName: room,
    );
    _rooms.add(created);
    _sort();
    notifyListeners();
    await _persist(created);
    return created;
  }

  Future<void> renameCampus({
    required String from,
    required String to,
  }) async {
    final target = to.trim();
    if (target.isEmpty || target == from) return;
    var changed = false;
    for (var i = 0; i < _rooms.length; i++) {
      if (_rooms[i].campusName == from) {
        _rooms[i] = CampusRoom(
          id: _rooms[i].id,
          campusName: target,
          roomName: _rooms[i].roomName,
        );
        changed = true;
      }
    }
    if (!changed) return;
    notifyListeners();
    for (final room in _rooms.where((r) => r.campusName == target)) {
      await _persist(room);
    }
  }

  Future<bool> removeRoom(String id) async {
    final idx = _rooms.indexWhere((r) => r.id == id);
    if (idx < 0) return false;
    _rooms.removeAt(idx);
    notifyListeners();
    await LocalJsonStore.writeList(
      _localKey,
      _rooms.map((r) => r.toMap()).toList(),
    );
    return true;
  }

  Future<void> _persist(CampusRoom room) async {
    await LocalJsonStore.writeList(
      _localKey,
      _rooms.map((r) => r.toMap()).toList(),
    );
    final crud = DocumentStore();
    if (!crud.available) return;
    try {
      await crud.createOrUpdate(
        collection: collection,
        docId: room.id,
        data: room.toMap(),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('CampusRoomService persist: $e');
    }
  }

  void _sort() {
    _rooms.sort((a, b) {
      final campus = a.campusName.compareTo(b.campusName);
      if (campus != 0) return campus;
      return a.roomName.compareTo(b.roomName);
    });
  }
}
