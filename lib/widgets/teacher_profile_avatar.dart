import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';

/// Profile photo for the logged-in teacher (from registry + saved file).
class TeacherProfileAvatar extends StatefulWidget {
  const TeacherProfileAvatar({
    super.key,
    this.teacherId,
    this.name,
    this.radius = 28,
    this.borderColor,
    this.borderWidth = 0,
    this.backgroundColor,
    this.initialTextColor,
  });

  final String? teacherId;
  final String? name;
  final double radius;
  final Color? borderColor;
  final double borderWidth;
  final Color? backgroundColor;
  final Color? initialTextColor;

  @override
  State<TeacherProfileAvatar> createState() => _TeacherProfileAvatarState();
}

class _TeacherProfileAvatarState extends State<TeacherProfileAvatar> {
  String? _photoPath;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final resolvedId = widget.teacherId ?? TeacherAccessService.instance.teacherId;
    final id = resolvedId.isNotEmpty
        ? resolvedId
        : AuthService.currentUser?.linkedTeacherId;
    if (id == null || id.isEmpty) return;

    final fromRecord = TeacherRegistryService.instance.lookupById(id)?.photoPath;
    if (fromRecord != null && !kIsWeb && File(fromRecord).existsSync()) {
      if (mounted) setState(() => _photoPath = fromRecord);
      return;
    }

    final resolved = await TeacherPhotoService.instance.resolvePath(id);
    if (mounted) setState(() => _photoPath = resolved);
  }

  String get _initial {
    final n = widget.name ??
        TeacherAccessService.instance.teacherName;
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    final hasPhoto =
        !kIsWeb && _photoPath != null && File(_photoPath!).existsSync();

    Widget avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor:
          widget.backgroundColor ?? Colors.white.withValues(alpha: 0.25),
      child: hasPhoto
          ? ClipOval(
              child: Image.file(
                File(_photoPath!),
                width: size,
                height: size,
                fit: BoxFit.cover,
              ),
            )
          : Text(
              _initial,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: widget.radius * 0.85,
                color: widget.initialTextColor ?? Colors.white,
              ),
            ),
    );

    if (widget.borderWidth > 0) {
      avatar = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.borderColor ?? Colors.white.withValues(alpha: 0.5),
            width: widget.borderWidth,
          ),
        ),
        child: avatar,
      );
    }

    return avatar;
  }
}
