/// EDUABA — parent-submitted student leave request, reviewed by the
/// homeroom teacher (Student Affairs / admin can also act on it).
enum LeaveRequestStatus { pending, approved, rejected }

class LeaveRequest {
  const LeaveRequest({
    required this.id,
    required this.schoolId,
    required this.studentId,
    required this.studentName,
    required this.className,
    required this.parentUsername,
    required this.parentName,
    required this.startDate,
    required this.endDate,
    required this.reason,
    this.status = LeaveRequestStatus.pending,
    this.reviewedByName = '',
    this.reviewNote = '',
    this.reviewedAt,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String schoolId;
  final String studentId;
  final String studentName;
  final String className;
  final String parentUsername;
  final String parentName;
  final DateTime startDate;
  final DateTime endDate;
  final String reason;
  final LeaveRequestStatus status;
  final String reviewedByName;
  final String reviewNote;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  LeaveRequest copyWith({
    LeaveRequestStatus? status,
    String? reviewedByName,
    String? reviewNote,
    DateTime? reviewedAt,
    DateTime? updatedAt,
  }) {
    return LeaveRequest(
      id: id,
      schoolId: schoolId,
      studentId: studentId,
      studentName: studentName,
      className: className,
      parentUsername: parentUsername,
      parentName: parentName,
      startDate: startDate,
      endDate: endDate,
      reason: reason,
      status: status ?? this.status,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      reviewNote: reviewNote ?? this.reviewNote,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'schoolId': schoolId,
        'studentId': studentId,
        'studentName': studentName,
        'className': className,
        'parentUsername': parentUsername,
        'parentName': parentName,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate.toIso8601String(),
        'reason': reason,
        'status': status.name,
        'reviewedByName': reviewedByName,
        'reviewNote': reviewNote,
        'reviewedAt': reviewedAt?.toIso8601String(),
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  static LeaveRequest fromMap(Map<String, dynamic> map) {
    DateTime parseDate(Object? v) =>
        DateTime.tryParse('${v ?? ''}') ?? DateTime.now();
    return LeaveRequest(
      id: '${map['id'] ?? map['_docId'] ?? ''}',
      schoolId: '${map['schoolId'] ?? ''}'.toUpperCase(),
      studentId: '${map['studentId'] ?? ''}'.toUpperCase(),
      studentName: '${map['studentName'] ?? ''}',
      className: '${map['className'] ?? ''}',
      parentUsername: '${map['parentUsername'] ?? ''}',
      parentName: '${map['parentName'] ?? ''}',
      startDate: parseDate(map['startDate']),
      endDate: parseDate(map['endDate']),
      reason: '${map['reason'] ?? ''}',
      status: LeaveRequestStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => LeaveRequestStatus.pending,
      ),
      reviewedByName: '${map['reviewedByName'] ?? ''}',
      reviewNote: '${map['reviewNote'] ?? ''}',
      reviewedAt: map['reviewedAt'] == null
          ? null
          : DateTime.tryParse('${map['reviewedAt']}'),
      createdAt: parseDate(map['createdAt']),
      updatedAt: parseDate(map['updatedAt']),
    );
  }
}
