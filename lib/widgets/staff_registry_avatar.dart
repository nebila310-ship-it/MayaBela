import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:mayabela/services/driver_photo_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/widgets/profile_photo_align_dialog.dart';
import 'package:mayabela/widgets/profile_photo_view.dart';

/// Profile avatar for teachers, drivers, or students in admin views.
class StaffRegistryAvatar extends StatefulWidget {
  const StaffRegistryAvatar({
    super.key,
    required this.staffId,
    required this.name,
    this.radius = 24,
    this.fallbackIcon,
    this.fallbackColor = Colors.indigo,
    this.isDriver = false,
    this.isStudent = false,
    this.onTap,
    this.enableViewer = true,
  });

  final String staffId;
  final String name;
  final double radius;
  final IconData? fallbackIcon;
  final Color fallbackColor;
  final bool isDriver;
  final bool isStudent;
  final VoidCallback? onTap;
  final bool enableViewer;

  @override
  State<StaffRegistryAvatar> createState() => _StaffRegistryAvatarState();
}

class _StaffRegistryAvatarState extends State<StaffRegistryAvatar> {
  String? _photoPath;
  Uint8List? _photoBytes;

  @override
  void initState() {
    super.initState();
    _loadPhoto();
  }

  @override
  void didUpdateWidget(covariant StaffRegistryAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.staffId != widget.staffId) _loadPhoto();
  }

  Future<void> _loadPhoto() async {
    String? fromRecord;
    if (widget.isStudent) {
      fromRecord =
          StudentRegistryService.instance.lookupById(widget.staffId)?.photoPath;
    } else if (widget.isDriver) {
      fromRecord =
          DriverRegistryService.instance.lookupById(widget.staffId)?.photoPath;
    } else {
      fromRecord =
          TeacherRegistryService.instance.lookupById(widget.staffId)?.photoPath;
    }

    final resolved = widget.isStudent
        ? await StudentPhotoService.instance.resolvePath(
            widget.staffId,
            storedPath: fromRecord,
          )
        : widget.isDriver
            ? await DriverPhotoService.instance.resolvePath(
                widget.staffId,
                storedPath: fromRecord,
              )
            : await TeacherPhotoService.instance.resolvePath(
                widget.staffId,
                storedPath: fromRecord,
              );

    final bytes = widget.isStudent
        ? StudentPhotoService.instance.lookupBytes(
            widget.staffId,
            storedPath: resolved ?? fromRecord,
          )
        : widget.isDriver
            ? DriverPhotoService.instance.lookupBytes(
                widget.staffId,
                storedPath: resolved ?? fromRecord,
              )
            : TeacherPhotoService.instance.lookupBytes(
                widget.staffId,
                storedPath: resolved ?? fromRecord,
              );

    if (mounted) {
      setState(() {
        _photoPath = resolved ?? fromRecord;
        _photoBytes = bytes;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    final provider = profilePhotoProvider(bytes: _photoBytes, path: _photoPath);

    Widget child;
    if (provider != null) {
      child = ClipOval(
        child: ProfilePhotoImage(
          bytes: _photoBytes,
          path: _photoPath,
          size: size,
        ),
      );
    } else if (widget.fallbackIcon != null) {
      child = Icon(
        widget.fallbackIcon,
        color: widget.fallbackColor,
        size: widget.radius,
      );
    } else {
      child = Text(
        widget.name.isNotEmpty ? widget.name[0].toUpperCase() : '?',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: widget.radius * 0.85,
          color: widget.fallbackColor,
        ),
      );
    }

    return GestureDetector(
      onTap: widget.onTap ??
          (widget.enableViewer && provider != null
              ? () => showProfilePhotoViewer(
                    context,
                    bytes: _photoBytes,
                    path: _photoPath,
                    title: widget.name,
                  )
              : null),
      child: CircleAvatar(
        radius: widget.radius,
        backgroundColor: widget.fallbackColor.withValues(alpha: 0.15),
        child: child,
      ),
    );
  }
}
