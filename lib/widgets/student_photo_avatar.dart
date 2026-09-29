import 'package:flutter/material.dart';

import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';

/// Saved student photo for any roster — id, name, or both.
class StudentPhotoAvatar extends StatelessWidget {
  const StudentPhotoAvatar({
    super.key,
    this.studentId,
    required this.name,
    this.photoPath,
    this.radius = 20,
    this.fallbackColor = Colors.indigo,
    this.enableViewer = true,
  });

  final String? studentId;
  final String name;
  final String? photoPath;
  final double radius;
  final Color fallbackColor;
  final bool enableViewer;

  @override
  Widget build(BuildContext context) {
    final record = StudentRegistryService.instance.resolveForPhoto(
      studentId: studentId,
      name: name,
    );
    return StaffRegistryAvatar(
      staffId: record?.studentId ?? studentId ?? name,
      name: record?.fullName ?? name,
      photoPath: photoPath ?? record?.photoPath,
      radius: radius,
      isStudent: true,
      fallbackColor: fallbackColor,
      enableViewer: enableViewer,
    );
  }
}
