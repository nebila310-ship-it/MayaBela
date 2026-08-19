import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/services/driver_photo_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/student_photo_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_photo_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/platform/web_attachment_cache.dart';

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
  });

  final String staffId;
  final String name;
  final double radius;
  final IconData? fallbackIcon;
  final Color fallbackColor;
  final bool isDriver;
  final bool isStudent;

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

    Uint8List? bytes;
    if (widget.isStudent) {
      bytes = StudentPhotoService.instance.lookupBytes(widget.staffId);
    }
    if (bytes == null && WebAttachmentCache.instance.isWebPath(fromRecord)) {
      bytes = WebAttachmentCache.instance.read(fromRecord);
    }

    if (fromRecord != null && !kIsWeb && File(fromRecord).existsSync()) {
      if (mounted) {
        setState(() {
          _photoPath = fromRecord;
          _photoBytes = bytes;
        });
      }
      return;
    }

    final resolved = widget.isStudent
        ? await StudentPhotoService.instance.resolvePath(widget.staffId)
        : widget.isDriver
            ? await DriverPhotoService.instance.resolvePath(widget.staffId)
            : await TeacherPhotoService.instance.resolvePath(widget.staffId);

    if (bytes == null && widget.isStudent) {
      bytes = StudentPhotoService.instance.lookupBytes(widget.staffId);
    }
    if (bytes == null && WebAttachmentCache.instance.isWebPath(resolved)) {
      bytes = WebAttachmentCache.instance.read(resolved);
    }

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
    final bytes = _photoBytes;
    final hasFilePhoto =
        !kIsWeb && _photoPath != null && File(_photoPath!).existsSync();
    final hasMemoryPhoto = bytes != null && bytes.isNotEmpty;

    Widget? child;
    if (hasMemoryPhoto) {
      child = ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      );
    } else if (hasFilePhoto) {
      child = ClipOval(
        child: Image.file(
          File(_photoPath!),
          width: size,
          height: size,
          fit: BoxFit.cover,
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

    return CircleAvatar(
      radius: widget.radius,
      backgroundColor: widget.fallbackColor.withValues(alpha: 0.15),
      child: child,
    );
  }
}
