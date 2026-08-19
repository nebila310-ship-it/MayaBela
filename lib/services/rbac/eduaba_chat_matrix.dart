import 'package:mayabela/services/rbac/staff_permissions.dart';

/// EDUABA hierarchical + operational chat wiring (staff-side keys).
///
/// Rule from the spec: every role chats with its direct superior and direct
/// reports; peers under the same manager chat with each other; cross-branch
/// chat is allowed where operationally linked. Parents/students still use
/// [ParentMessagingPolicy] / messaging access for endpoint checks.
abstract final class EduabaChatMatrix {
  /// Ownership / executive chain — may reach every staff member.
  static const executiveChain = <String>{
    StaffRoles.fullAccess,
    StaffRoles.schoolBoard,
    StaffRoles.generalManager,
    StaffRoles.deputyGeneralManager,
  };

  /// Peers under the Deputy GM (Principal ↔ QA ↔ Finance ↔ HR).
  static const deputyBranchPeers = <String>{
    StaffRoles.principal,
    StaffRoles.qualityAssurance,
    StaffRoles.accountant,
    StaffRoles.humanResource,
  };

  /// Peers under the Vice Principal.
  static const academicPeersUnderVp = <String>{
    StaffRoles.studentAffairs,
    StaffRoles.sectionDirector,
    StaffRoles.registrar,
  };

  /// QA audits every branch (compliance reviews & findings follow-up).
  static const qaAuditTargets = <String>{
    StaffRoles.principal,
    StaffRoles.vicePresident,
    StaffRoles.sectionDirector,
    StaffRoles.studentAffairs,
    StaffRoles.accountant,
    StaffRoles.humanResource,
    StaffRoles.registrar,
  };

  /// Staff roles allowed to chat with classroom teachers (operational links:
  /// section leadership, welfare, QA audits, employment, transport, requests).
  static const classroomTeacherContacts = <String>{
    StaffRoles.fullAccess,
    StaffRoles.schoolBoard,
    StaffRoles.generalManager,
    StaffRoles.deputyGeneralManager,
    StaffRoles.principal,
    StaffRoles.vicePresident,
    StaffRoles.sectionDirector,
    StaffRoles.studentAffairs,
    StaffRoles.qualityAssurance,
    StaffRoles.humanResource,
    StaffRoles.transportAdmin,
    StaffRoles.procurement,
    StaffRoles.storekeeper,
    StaffRoles.librarian,
    StaffRoles.staffs,
  };

  /// Librarian operational contacts (library / e-book coordination).
  static const librarianContacts = <String>{
    StaffRoles.vicePresident,
    StaffRoles.sectionDirector,
    StaffRoles.qualityAssurance,
  };

  /// Staff roles allowed to chat with drivers (transport ops + employment).
  static const driverContacts = <String>{
    StaffRoles.fullAccess,
    StaffRoles.generalManager,
    StaffRoles.deputyGeneralManager,
    StaffRoles.humanResource,
    StaffRoles.transportAdmin,
  };

  static bool canStaffChat({
    required Iterable<String> actorRoles,
    required Iterable<String> peerRoles,
  }) {
    final a = actorRoles.map(StaffRoles.canonicalize).toSet();
    final b = peerRoles.map(StaffRoles.canonicalize).toSet();
    if (a.isEmpty || b.isEmpty) return false;

    // Owner / Board / GM / Deputy GM reach everyone (and vice versa).
    if (_intersects(a, executiveChain) || _intersects(b, executiveChain)) {
      return true;
    }

    // Peer groups.
    if (_intersects(a, deputyBranchPeers) && _intersects(b, deputyBranchPeers)) {
      return true;
    }
    if (_intersects(a, academicPeersUnderVp) &&
        _intersects(b, academicPeersUnderVp)) {
      return true;
    }

    // Quality Assurance audit lines across all branches.
    if ((a.contains(StaffRoles.qualityAssurance) &&
            _intersects(b, qaAuditTargets)) ||
        (b.contains(StaffRoles.qualityAssurance) &&
            _intersects(a, qaAuditTargets))) {
      return true;
    }

    // Principal branch.
    if (_edge(a, b, StaffRoles.principal, StaffRoles.vicePresident)) return true;
    if (_edge(a, b, StaffRoles.vicePresident, StaffRoles.studentAffairs)) {
      return true;
    }
    if (_edge(a, b, StaffRoles.vicePresident, StaffRoles.sectionDirector)) {
      return true;
    }
    if (_edge(a, b, StaffRoles.vicePresident, StaffRoles.registrar)) return true;
    if (_edge(a, b, StaffRoles.sectionDirector, StaffRoles.studentAffairs)) {
      return true;
    }

    // Finance branch (procurement chain + payroll + fees/registration).
    if (_edge(a, b, StaffRoles.accountant, StaffRoles.procurement)) return true;
    if (_edge(a, b, StaffRoles.procurement, StaffRoles.storekeeper)) return true;
    if (_edge(a, b, StaffRoles.accountant, StaffRoles.registrar)) return true;
    if (_edge(a, b, StaffRoles.accountant, StaffRoles.transportAdmin)) {
      return true;
    }
    if (_edge(a, b, StaffRoles.accountant, StaffRoles.humanResource)) {
      return true;
    }

    // HR branch (transport + staffs records).
    if (_edge(a, b, StaffRoles.humanResource, StaffRoles.transportAdmin)) {
      return true;
    }
    if (_edge(a, b, StaffRoles.humanResource, StaffRoles.staffs)) return true;

    // Staffs as requesters / peers.
    if (_edge(a, b, StaffRoles.staffs, StaffRoles.procurement)) return true;
    if (_edge(a, b, StaffRoles.staffs, StaffRoles.storekeeper)) return true;
    if (a.contains(StaffRoles.staffs) && b.contains(StaffRoles.staffs)) {
      return true;
    }

    // Requester lines into procurement / store from section leadership.
    if (_edge(a, b, StaffRoles.sectionDirector, StaffRoles.procurement)) {
      return true;
    }
    if (_edge(a, b, StaffRoles.sectionDirector, StaffRoles.storekeeper)) {
      return true;
    }

    // Librarian ↔ VP / Section Director / QA (and classroom teachers via
    // classroomTeacherContacts in messaging access).
    if (a.contains(StaffRoles.librarian) &&
        _intersects(b, librarianContacts)) {
      return true;
    }
    if (b.contains(StaffRoles.librarian) &&
        _intersects(a, librarianContacts)) {
      return true;
    }

    return false;
  }

  static bool _intersects(Set<String> a, Set<String> b) => a.any(b.contains);

  static bool _edge(
    Set<String> a,
    Set<String> b,
    String left,
    String right,
  ) {
    return (a.contains(left) && b.contains(right)) ||
        (a.contains(right) && b.contains(left));
  }
}
