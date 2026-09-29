import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/app_collections.dart';
import 'package:mayabela/services/cloud/document_store.dart';
import 'package:mayabela/utils/phone_utils.dart';

/// School-wide online status for messaging.
///
/// The signed-in user is always online. Peers are online when they heartbeated
/// in the last two minutes (local cache, optional cloud row, or a recent
/// message they sent).
class PresenceService extends ChangeNotifier {
  PresenceService._();
  static final instance = PresenceService._();

  static const onlineWindow = Duration(minutes: 2);
  static const _heartbeatEvery = Duration(seconds: 45);
  static const _prefsKey = 'user_presence_v1';

  final Map<String, DateTime> _lastSeen = {};
  Timer? _timer;
  var _started = false;
  final _crud = DocumentStore();

  static String _key(String schoolId, String identity) {
    return '${schoolId.trim().toUpperCase()}|${identity.trim().toLowerCase()}';
  }

  bool get isCurrentUserOnline => AuthService.currentUser != null;

  void startForCurrentUser() {
    if (AuthService.currentUser == null) return;
    _started = true;
    unawaited(_restore());
    _beat();
    _timer?.cancel();
    _timer = Timer.periodic(_heartbeatEvery, (_) => _beat());
  }

  void stop() {
    _started = false;
    _timer?.cancel();
    _timer = null;
  }

  void noteIdentity(String? identity, {DateTime? at}) {
    final schoolId =
        AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '';
    final id = identity?.trim() ?? '';
    if (schoolId.isEmpty || id.isEmpty) return;
    final when = at ?? DateTime.now().toUtc();
    _lastSeen[_key(schoolId, id)] = when;
    notifyListeners();
  }

  void noteFromConversations(Iterable<Conversation> conversations) {
    for (final chat in conversations) {
      if (chat.messages.isEmpty) continue;
      final last = chat.messages.last;
      final when = last.time.toUtc();
      if (DateTime.now().toUtc().difference(when) > onlineWindow) continue;
      noteIdentity(last.senderUsername, at: when);
      noteIdentity(last.senderStaffId, at: when);
    }
  }

  bool isOnline({String? username, String? staffId, String? phone}) {
    final me = AuthService.currentUser;
    if (me != null) {
      if (_sameIdentity(username, me.username) ||
          _sameIdentity(phone, me.phone) ||
          _sameIdentity(phone, me.username) ||
          _sameIdentity(username, me.phone)) {
        return true;
      }
      final myStaff = StaffMemberOption.viewerCompositeStaffId(me.roleKey);
      if (staffId != null &&
          myStaff != null &&
          StaffMemberOption.idsEqual(staffId, myStaff)) {
        return true;
      }
    }
    final schoolId = AuthService.activeSchoolId ?? me?.schoolId ?? '';
    if (schoolId.isEmpty) return false;
    final now = DateTime.now().toUtc();
    bool fresh(String? id) {
      if (id == null || id.trim().isEmpty) return false;
      final seen = _lastSeen[_key(schoolId, id)];
      return seen != null && now.difference(seen) <= onlineWindow;
    }

    return fresh(username) || fresh(staffId) || fresh(phone);
  }

  bool isStaffOnline(StaffMemberOption member) {
    return isOnline(
      username: member.presenceUsername,
      staffId: member.id,
      phone: member.presencePhone,
    );
  }

  bool isParentOnline(ParentRecipientOption parent) {
    for (final username in parent.participantUsernames) {
      if (isOnline(username: username, phone: username)) return true;
    }
    return isOnline(
      username: parent.parentUsername,
      phone: parent.parentUsername,
    );
  }

  /// Direct-thread peer only. Groups and broadcasts have no single presence.
  bool isConversationPeerOnline(Conversation chat) {
    if (chat.isGroup || chat.isBroadcast) return false;
    final role = AuthService.currentUser?.roleKey;

    if (role == AuthService.roleParent) {
      final staffId = chat.staffParticipantId;
      if (staffId == null || staffId.trim().isEmpty) return false;
      final member = StaffMemberOption.resolve(staffId);
      if (member != null) return isStaffOnline(member);
      return isOnline(staffId: staffId);
    }

    final hasParent =
        (chat.parentParticipantName?.trim().isNotEmpty ?? false) ||
        chat.parentParticipantUsernames.isNotEmpty;
    if (hasParent) {
      final usernames = chat.parentParticipantUsernames;
      return isParentOnline(
        ParentRecipientOption(
          parentName: chat.parentParticipantName ?? chat.name,
          studentNames: const [],
          studentIds: chat.linkedStudentIds,
          parentUsername: usernames.isEmpty ? null : usernames.first,
          parentUsernames: usernames,
        ),
      );
    }

    final viewerId = StaffMemberOption.viewerCompositeStaffId(role);
    String? peerId;
    if (viewerId != null) {
      if (StaffMemberOption.idsEqual(chat.staffParticipantId, viewerId)) {
        peerId = chat.counterpartyStaffId;
      } else if (StaffMemberOption.idsEqual(
        chat.counterpartyStaffId,
        viewerId,
      )) {
        peerId = chat.staffParticipantId;
      }
    }
    peerId ??= chat.counterpartyStaffId ?? chat.staffParticipantId;
    if (peerId == null || peerId.trim().isEmpty) return false;
    if (viewerId != null && StaffMemberOption.idsEqual(peerId, viewerId)) {
      return true;
    }
    final member = StaffMemberOption.resolve(peerId);
    if (member != null) return isStaffOnline(member);
    return isOnline(staffId: peerId);
  }

  @visibleForTesting
  void resetForTests() {
    stop();
    _lastSeen.clear();
  }

  bool _sameIdentity(String? a, String? b) {
    final left = a?.trim().toLowerCase() ?? '';
    final right = b?.trim().toLowerCase() ?? '';
    if (left.isEmpty || right.isEmpty) return false;
    if (left == right) return true;
    return PhoneUtils.matches(left, right);
  }

  void _beat() {
    final user = AuthService.currentUser;
    if (!_started || user == null) return;
    final now = DateTime.now().toUtc();
    noteIdentity(user.username, at: now);
    if (user.phone != null) noteIdentity(user.phone, at: now);
    final staffId = StaffMemberOption.viewerCompositeStaffId(user.roleKey);
    if (staffId != null) noteIdentity(staffId, at: now);
    unawaited(_persist());
    unawaited(_pushCloud(now));
  }

  Future<void> _restore() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) return;
      final map = jsonDecode(raw);
      if (map is! Map) return;
      map.forEach((key, value) {
        final when = DateTime.tryParse(value.toString());
        if (key is String && when != null) {
          _lastSeen[key] = when.toUtc();
        }
      });
      notifyListeners();
    } catch (_) {}
    unawaited(_pullCloud());
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cutoff = DateTime.now().toUtc().subtract(const Duration(hours: 6));
      _lastSeen.removeWhere((_, when) => when.isBefore(cutoff));
      await prefs.setString(
        _prefsKey,
        jsonEncode(
          _lastSeen.map((key, value) => MapEntry(key, value.toIso8601String())),
        ),
      );
    } catch (_) {}
  }

  Future<void> _pushCloud(DateTime now) async {
    final user = AuthService.currentUser;
    if (user == null || !SupabaseBootstrap.isInitialized) return;
    final schoolId = (AuthService.activeSchoolId ?? user.schoolId ?? '')
        .trim()
        .toUpperCase();
    if (schoolId.isEmpty) return;
    try {
      await _crud.createOrUpdate(
        collection: AppCollections.userPresence,
        docId: user.username.trim().toLowerCase(),
        data: {
          'username': user.username,
          'phone': user.phone,
          'roleKey': user.roleKey,
          'staffId': StaffMemberOption.viewerCompositeStaffId(user.roleKey),
          'fullName': user.fullName,
          'schoolId': schoolId,
          'lastSeen': now.toIso8601String(),
        },
      );
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PresenceService push: $e');
      }
    }
  }

  Future<void> _pullCloud() async {
    if (!SupabaseBootstrap.isInitialized) return;
    final schoolId =
        (AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId ?? '')
            .trim()
            .toUpperCase();
    if (schoolId.isEmpty) return;
    try {
      final rows = await _crud.readBySchool(
        AppCollections.userPresence,
        schoolId: schoolId,
      );
      for (final row in rows) {
        final when = DateTime.tryParse(
          '${row['lastSeen'] ?? row['updatedAt'] ?? ''}',
        );
        if (when == null) continue;
        noteIdentity(row['username']?.toString(), at: when.toUtc());
        noteIdentity(row['phone']?.toString(), at: when.toUtc());
        noteIdentity(row['staffId']?.toString(), at: when.toUtc());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('PresenceService pull: $e');
      }
    }
  }
}
