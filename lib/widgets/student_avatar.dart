import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/staff_permissions.dart';

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

    final bytes = await StudentPhotoService.instance.pickBytes();
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
    final hasPhoto = !kIsWeb &&
        student.photoPath != null &&
        student.photoPath!.isNotEmpty;

    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Colors.indigo.withValues(alpha: 0.15),
      child: hasPhoto
          ? ClipOval(
              child: Image.file(
                File(student.photoPath!),
                width: radius * 2,
                height: radius * 2,
                fit: BoxFit.cover,
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

    if (!allowEdit) return avatar;

    return GestureDetector(
      onTap: () => _pickPhoto(context),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: -2,
            bottom: -2,
            child: CircleAvatar(
              radius: 12,
              backgroundColor: Colors.indigo,
              child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
