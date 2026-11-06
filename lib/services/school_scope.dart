import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/demo_content.dart';

/// School-owned rows. An empty school id is demo-only and never a live campus.
bool schoolRecordMatchesViewer(
  String? recordSchoolId, {
  String? viewerSchoolId,
}) {
  final viewer = (viewerSchoolId ?? AuthService.activeSchoolId ?? '')
      .trim()
      .toUpperCase();
  if (viewer.isEmpty) return false;
  final record = recordSchoolId?.trim().toUpperCase() ?? '';
  if (record.isEmpty) {
    return !DemoContent.isRealSchool(viewer);
  }
  return record == viewer;
}
