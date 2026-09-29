import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/admin_registry_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/phone_launch_service.dart';
import 'package:mayabela/services/presence_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/messages_ui.dart';

class ChatContactProfile {
  const ChatContactProfile({
    required this.name,
    required this.roleLabel,
    this.email,
    this.phone,
    this.subtitle,
    this.photoPath,
    this.staffId,
    this.username,
  });

  final String name;
  final String roleLabel;
  final String? email;
  final String? phone;
  final String? subtitle;
  final String? photoPath;
  final String? staffId;
  final String? username;

  bool get online =>
      PresenceService.instance.isOnline(staffId: staffId, username: username);
}

/// Looks up a chat participant's public contact details (email / phone).
abstract final class ChatContactDirectory {
  static ChatContactProfile fromMessage(
    ChatMessage message, {
    Conversation? conversation,
  }) {
    final username = message.senderUsername?.trim();
    if (username != null && username.isNotEmpty) {
      final account = AuthService.findUser(username);
      if (account != null) {
        return fromAccount(
          account,
          staffId: message.senderStaffId,
          fallbackName: message.resolveDisplayName(),
          fallbackRole: _roleLabel(message.senderRole),
        );
      }
    }

    final staffId = message.senderStaffId?.trim();
    if (staffId != null && staffId.isNotEmpty) {
      return fromStaffId(
        staffId,
        fallbackName: message.resolveDisplayName(),
        fallbackRole: _roleLabel(message.senderRole),
      );
    }

    if (message.senderRole == AuthService.roleParent && conversation != null) {
      final usernames = conversation.parentParticipantUsernames
          .map((u) => u.trim())
          .where((u) => u.isNotEmpty);
      if (usernames.isNotEmpty) {
        return fromParentUsername(
          usernames.first,
          fallbackName: message.resolveDisplayName(),
        );
      }
      final parentName = conversation.parentParticipantName?.trim();
      if (parentName != null && parentName.isNotEmpty) {
        return fromParentName(
          parentName,
        ).copyWith(name: message.resolveDisplayName());
      }
    }

    return ChatContactProfile(
      name: message.resolveDisplayName(),
      roleLabel: _roleLabel(message.senderRole),
    );
  }

  static ChatContactProfile fromConversationPeer(Conversation conversation) {
    if (conversation.isGroup || conversation.isBroadcast) {
      return ChatContactProfile(
        name: conversation.inboxTitleForViewer(),
        roleLabel: conversation.isBroadcast ? 'Broadcast' : 'Group',
        photoPath: conversation.photoPath,
        subtitle: conversation.isBroadcast
            ? conversation.broadcastAudienceKeys.join(', ')
            : null,
      );
    }

    final viewerRole = AuthService.currentUser?.roleKey;
    final viewerStaffId = StaffMemberOption.viewerCompositeStaffId(viewerRole);
    final viewerUsername = AuthService.currentUser?.username;
    for (var i = conversation.messages.length - 1; i >= 0; i--) {
      final msg = conversation.messages[i];
      if (msg.isOutgoingFor(
        viewerRole,
        viewerStaffId: viewerStaffId,
        viewerUsername: viewerUsername,
      )) {
        continue;
      }
      return fromMessage(msg, conversation: conversation);
    }

    if (viewerRole == AuthService.roleParent) {
      final staffId =
          conversation.staffParticipantId ?? conversation.counterpartyStaffId;
      if (staffId != null && staffId.trim().isNotEmpty) {
        return fromStaffId(
          staffId,
          fallbackName: conversation.inboxTitleForViewer(),
        );
      }
    }

    for (final username in conversation.parentParticipantUsernames) {
      final trimmed = username.trim();
      if (trimmed.isEmpty) continue;
      return fromParentUsername(
        trimmed,
        fallbackName:
            conversation.parentParticipantName ??
            conversation.inboxTitleForViewer(),
      );
    }

    if (conversation.parentParticipantName != null &&
        conversation.parentParticipantName!.trim().isNotEmpty) {
      return fromParentName(conversation.parentParticipantName!);
    }

    final peerId = _peerStaffId(conversation, viewerRole);
    if (peerId != null) {
      return fromStaffId(
        peerId,
        fallbackName: conversation.inboxTitleForViewer(),
      );
    }

    return ChatContactProfile(
      name: conversation.inboxTitleForViewer(),
      roleLabel: conversation.inboxPeerRoleLabel() ?? conversation.role,
    );
  }

  /// The signed-in person who sent/owns this account, not the registry role owner.
  static ChatContactProfile fromAccount(
    RegisteredUser account, {
    String? staffId,
    String? fallbackName,
    String? fallbackRole,
  }) {
    final personName =
        _personName(account.fullName) ??
        _personName(fallbackName) ??
        account.username;
    var email = _trim(account.email);
    var phone = _trim(account.phone);
    var roleLabel = fallbackRole ?? _roleLabel(account.roleKey);
    String? photoPath;
    String? subtitle;
    final resolvedStaffId = staffId?.trim().isNotEmpty == true
        ? staffId!.trim()
        : _staffIdForAccount(account);
    if (resolvedStaffId != null) {
      final registry = fromStaffId(
        resolvedStaffId,
        fallbackName: personName,
        fallbackRole: roleLabel,
        preferAccount: false,
      );
      email = _firstEmail(email, registry.email);
      phone = _firstPhone(phone, registry.phone);
      roleLabel = registry.roleLabel;
      photoPath = registry.photoPath;
      subtitle = registry.subtitle;
    }
    return ChatContactProfile(
      name: personName,
      roleLabel: roleLabel,
      email: email,
      phone: phone,
      subtitle: subtitle,
      photoPath: photoPath,
      staffId: resolvedStaffId,
      username: account.username,
    );
  }

  static ChatContactProfile fromStaffId(
    String staffId, {
    String? fallbackName,
    String? fallbackRole,
    bool preferAccount = true,
  }) {
    if (preferAccount) {
      final account = _accountForStaffId(staffId);
      if (account != null) {
        return fromAccount(
          account,
          staffId: staffId,
          fallbackName: fallbackName,
          fallbackRole: fallbackRole,
        );
      }
    }

    final member = StaffMemberOption.resolve(staffId);
    var email = _userEmail(member?.presenceUsername);
    var phone = member?.presencePhone;
    String? photoPath;
    var name =
        _personName(fallbackName) ??
        _personName(member?.displayName) ??
        fallbackName ??
        member?.displayName ??
        staffId;
    var roleLabel = fallbackRole ?? member?.roleLabel ?? 'Staff';

    if (member != null) {
      roleLabel = member.roleLabel;
      if (_personName(member.displayName) != null) {
        name = member.displayName;
      }
      switch (member.kind) {
        case StaffKind.teacher:
          final teacher = TeacherRegistryService.instance.lookupById(
            member.rawId,
          );
          email = _firstEmail(email, teacher?.email);
          phone = _firstPhone(phone, teacher?.phone);
          photoPath = teacher?.photoPath;
        case StaffKind.driver:
          final driver = DriverRegistryService.instance.lookupById(
            member.rawId,
          );
          email = _firstEmail(email, driver?.email);
          phone = _firstPhone(phone, driver?.phone);
        case StaffKind.adminStaff:
          final admin = AdminRegistryService.instance.lookupById(member.rawId);
          email = _firstEmail(email, admin?.email);
          phone = _firstPhone(phone, admin?.phone);
      }
    }

    return ChatContactProfile(
      name: name,
      roleLabel: roleLabel,
      email: email,
      phone: phone,
      subtitle: member?.subtitle,
      photoPath: photoPath,
      staffId: staffId,
      username: member?.presenceUsername,
    );
  }

  static ChatContactProfile fromParentUsername(
    String username, {
    String? fallbackName,
  }) {
    final user = AuthService.findUser(username);
    String? phone = user?.phone;
    String? email = user?.email;
    final name = (user?.fullName?.trim().isNotEmpty ?? false)
        ? user!.fullName!.trim()
        : (fallbackName ?? username);

    EnrollmentService.instance.ensureSeeded();
    for (final link in EnrollmentService.instance.linksForParent(username)) {
      final student = StudentRegistryService.instance.lookupById(
        link.studentId,
      );
      if (student == null) continue;
      phone ??=
          student.phoneForRelationship(link.relationship) ??
          student.primaryContactPhone;
    }

    return ChatContactProfile(
      name: name,
      roleLabel: _roleLabel(AuthService.roleParent),
      email: email,
      phone: phone,
      username: username,
    );
  }

  static ChatContactProfile fromParentName(String parentName) {
    final target = parentName.trim().toLowerCase();
    for (final user in AuthService.allUsers.values) {
      if (user.roleKey != AuthService.roleParent) continue;
      if ((user.fullName ?? '').trim().toLowerCase() == target) {
        return fromParentUsername(user.username, fallbackName: parentName);
      }
    }
    return ChatContactProfile(
      name: parentName,
      roleLabel: _roleLabel(AuthService.roleParent),
    );
  }

  static ChatContactProfile fromGroupMember(GroupMemberEntry member) {
    if (member.isParent) {
      return fromParentUsername(member.key, fallbackName: member.displayName);
    }
    return fromStaffId(member.key, fallbackName: member.displayName);
  }

  static RegisteredUser? _accountForStaffId(String staffId) {
    final trimmed = staffId.trim();
    if (trimmed.isEmpty) return null;
    final member = StaffMemberOption.resolve(trimmed);
    if (member?.presenceUsername != null &&
        member!.presenceUsername!.trim().isNotEmpty) {
      final byPresence = AuthService.findUser(member.presenceUsername!);
      if (byPresence != null) return byPresence;
    }
    final raw = trimmed.contains(':') ? trimmed.split(':').last : trimmed;
    final kind = trimmed.contains(':')
        ? trimmed.split(':').first.toLowerCase()
        : '';
    RegisteredUser? fallback;
    for (final user in AuthService.allUsers.values) {
      final linkedTeacher = (user.linkedTeacherId ?? '').trim().toUpperCase();
      final linkedAdmin = (user.linkedAdminId ?? '').trim().toUpperCase();
      final linkedDriver = (user.linkedDriverId ?? '').trim().toUpperCase();
      final id = raw.toUpperCase();
      final matches =
          ((kind == 'teacher' || kind.isEmpty) && linkedTeacher == id) ||
          (kind == 'admin' && linkedAdmin == id) ||
          ((kind == 'driver' || kind.isEmpty) && linkedDriver == id);
      if (!matches) continue;
      if (_personName(user.fullName) != null) return user;
      fallback ??= user;
    }
    return fallback;
  }

  static String? _staffIdForAccount(RegisteredUser account) {
    final teacher = account.linkedTeacherId?.trim();
    if (teacher != null && teacher.isNotEmpty) {
      return StaffMemberOption.teacherKey(teacher);
    }
    final admin = account.linkedAdminId?.trim();
    if (admin != null && admin.isNotEmpty) {
      return StaffMemberOption.adminKey(admin);
    }
    final driver = account.linkedDriverId?.trim();
    if (driver != null && driver.isNotEmpty) {
      return StaffMemberOption.driverKey(driver);
    }
    return null;
  }

  static String? _personName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return null;
    if (isGenericRoleOwnerName(name)) return null;
    return name;
  }

  static String? _trim(String? value) {
    final text = value?.trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static String? _peerStaffId(Conversation conversation, String? viewerRole) {
    final viewerId = StaffMemberOption.viewerCompositeStaffId(viewerRole);
    final staff = conversation.staffParticipantId?.trim();
    final other = conversation.counterpartyStaffId?.trim();
    if (viewerId != null && staff != null && other != null) {
      if (StaffMemberOption.idsEqual(viewerId, staff)) return other;
      if (StaffMemberOption.idsEqual(viewerId, other)) return staff;
    }
    if (other != null && other.isNotEmpty) return other;
    if (staff != null &&
        staff.isNotEmpty &&
        !StaffMemberOption.idsEqual(viewerId, staff)) {
      return staff;
    }
    return null;
  }

  static String _roleLabel(String roleKey) {
    return AppLocale.instance.strings.roleLabel(roleKey);
  }

  static String? _userEmail(String? username) {
    if (username == null || username.trim().isEmpty) return null;
    return AuthService.findUser(username)?.email;
  }

  static String? _firstEmail(String? a, String? b) {
    final first = a?.trim();
    if (first != null && first.isNotEmpty) return first;
    final second = b?.trim();
    if (second != null && second.isNotEmpty) return second;
    return null;
  }

  static String? _firstPhone(String? a, String? b) {
    return _firstEmail(a, b);
  }
}

extension on ChatContactProfile {
  ChatContactProfile copyWith({String? name}) {
    return ChatContactProfile(
      name: name ?? this.name,
      roleLabel: roleLabel,
      email: email,
      phone: phone,
      subtitle: subtitle,
      photoPath: photoPath,
      staffId: staffId,
      username: username,
    );
  }
}

class ChatContactProfileScreen extends StatelessWidget {
  const ChatContactProfileScreen({super.key, required this.profile});

  final ChatContactProfile profile;

  static const screenKey = Key('chat-contact-profile');

  static Future<void> open(BuildContext context, ChatContactProfile profile) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChatContactProfileScreen(profile: profile),
      ),
    );
  }

  static Future<void> openFromMessage(
    BuildContext context,
    ChatMessage message, {
    Conversation? conversation,
  }) {
    return open(
      context,
      ChatContactDirectory.fromMessage(message, conversation: conversation),
    );
  }

  static Future<void> openPeer(
    BuildContext context,
    Conversation conversation,
  ) {
    return open(
      context,
      ChatContactDirectory.fromConversationPeer(conversation),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final email = profile.email?.trim();
    final phone = profile.phone?.trim();
    final hasEmail = email != null && email.isNotEmpty;
    final hasPhone = phone != null && phone.isNotEmpty;

    return Scaffold(
      key: screenKey,
      backgroundColor: MessagesPalette.listBg,
      appBar: AppBar(
        backgroundColor: MessagesPalette.appBar,
        foregroundColor: Colors.white,
        title: Text(s.contactInfo),
      ),
      body: ListView(
        children: [
          Container(
            width: double.infinity,
            color: MessagesPalette.appBar,
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
            child: Column(
              children: [
                ChatPersonAvatar(
                  name: profile.name,
                  photoPath: profile.photoPath,
                  size: 96,
                  online: profile.online,
                  showOnline: true,
                ),
                const SizedBox(height: 16),
                Text(
                  profile.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.roleLabel,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.85),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                PresenceLabel(online: profile.online, light: true),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _infoTile(
            icon: Icons.email_outlined,
            label: s.email,
            value: hasEmail ? email : s.contactNotOnFile,
            enabled: hasEmail,
            onTap: hasEmail ? () => _mail(context, email) : null,
          ),
          _infoTile(
            icon: Icons.phone_outlined,
            label: s.phone,
            value: hasPhone ? phone : s.contactNotOnFile,
            enabled: hasPhone,
            onTap: hasPhone ? () => _dial(context, phone) : null,
          ),
          if (profile.subtitle != null && profile.subtitle!.trim().isNotEmpty)
            _infoTile(
              icon: Icons.info_outline,
              label: s.profile,
              value: profile.subtitle!,
              enabled: false,
            ),
        ],
      ),
    );
  }

  Widget _infoTile({
    required IconData icon,
    required String label,
    required String value,
    required bool enabled,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.white,
      child: ListTile(
        leading: Icon(icon, color: MessagesPalette.appBar),
        title: Text(label, style: const TextStyle(fontSize: 12)),
        subtitle: Text(
          value,
          style: TextStyle(
            fontSize: 16,
            color: enabled ? const Color(0xFF111B21) : const Color(0xFF8696A0),
            fontWeight: FontWeight.w500,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _dial(BuildContext context, String phone) async {
    final ok = await PhoneLaunchService.instance.dial(phone);
    if (ok || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: phone));
  }

  Future<void> _mail(BuildContext context, String email) async {
    final uri = Uri(scheme: 'mailto', path: email);
    final ok = await launchUrl(uri);
    if (ok || !context.mounted) return;
    await Clipboard.setData(ClipboardData(text: email));
  }
}
