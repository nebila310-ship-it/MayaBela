import 'package:flutter/material.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';
import 'package:mayabela/widgets/profile_photo_align_dialog.dart';
import 'package:mayabela/widgets/profile_photo_view.dart';

class StudentAvatar extends StatelessWidget {
  const StudentAvatar({
    super.key,
    required this.student,
    this.radius = 24,
    this.allowEdit = false,
    this.onPhotoUpdated,
  });

  final StudentRef student;
  final double radius;
  final bool allowEdit;
  final VoidCallback? onPhotoUpdated;

  Future<void> _pickPhoto(BuildContext context) async {
    if (AuthService.currentUser?.roleKey != AuthService.roleAdmin &&
        !AuthService.hasPermission(SchoolPermissions.manageStudents)) {
      return;
    }

    final bytes = await pickAlignedPhotoOrSnack(
      context,
      pick: StudentPhotoService.instance.pickBytes,
      errorOf: () => StudentPhotoService.instance.lastError,
    );
    if (bytes == null) return;

    final path = await StudentPhotoService.instance.saveBytesForStudent(
      student.id,
      bytes,
    );
    if (path == null) return;

    SchoolDataService.instance.updateStudentPhoto(student.id, path);
    onPhotoUpdated?.call();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Photo updated for ${student.name}'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bytes = StudentPhotoService.instance.lookupBytes(
      student.id,
      storedPath: student.photoPath,
    );
    final provider = profilePhotoProvider(bytes: bytes, path: student.photoPath);

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.indigo.withValues(alpha: 0.15),
      child: provider != null
          ? ClipOval(
              child: ProfilePhotoImage(
                bytes: bytes,
                path: student.photoPath,
                size: radius * 2,
              ),
            )
          : Text(
              student.name[0],
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.7,
                color: Colors.indigo,
              ),
            ),
    );

    avatar = GestureDetector(
      onTap: provider == null
          ? (allowEdit ? () => _pickPhoto(context) : null)
          : () => showProfilePhotoViewer(
                context,
                bytes: bytes,
                path: student.photoPath,
                title: student.name,
              ),
      child: avatar,
    );

    if (!allowEdit) return avatar;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        avatar,
        Positioned(
          right: -2,
          bottom: -2,
          child: GestureDetector(
            onTap: () => _pickPhoto(context),
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.indigo,
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}
