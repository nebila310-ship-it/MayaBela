import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/profile_photo_align_dialog.dart';
import 'package:mayabela/widgets/profile_photo_view.dart';

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
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    final resolvedId =
        widget.teacherId ?? TeacherAccessService.instance.teacherId;
    final id = resolvedId.isNotEmpty
        ? resolvedId
        : AuthService.currentUser?.linkedTeacherId;
    if (id == null || id.isEmpty) return;

    final fromRecord = TeacherRegistryService.instance
        .lookupById(id)
        ?.photoPath;
    final resolved = await TeacherPhotoService.instance.resolvePath(
      id,
      storedPath: fromRecord,
    );
    final stored = resolved ?? fromRecord;
    var bytes = TeacherPhotoService.instance.lookupBytes(
      id,
      storedPath: stored,
    );
    if (bytes == null || bytes.isEmpty) {
      bytes = await TeacherPhotoService.instance.hydrateBytes(
        id,
        storedPath: stored,
      );
    }
    if (mounted) {
      setState(() {
        _photoPath = stored;
        _photoBytes = bytes;
      });
    }
  }

  String get _initial {
    final n = widget.name ?? TeacherAccessService.instance.teacherName;
    return n.isNotEmpty ? n[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    final provider = profilePhotoProvider(bytes: _photoBytes, path: _photoPath);

    Widget avatar = CircleAvatar(
      radius: widget.radius,
      backgroundColor:
          widget.backgroundColor ?? Colors.white.withValues(alpha: 0.25),
      child: provider != null
          ? ClipOval(
              child: ProfilePhotoImage(
                bytes: _photoBytes,
                path: _photoPath,
                size: size,
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

    if (provider != null) {
      avatar = GestureDetector(
        onTap: () => showProfilePhotoViewer(
          context,
          bytes: _photoBytes,
          path: _photoPath,
          title: widget.name,
        ),
        child: avatar,
      );
    }

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
