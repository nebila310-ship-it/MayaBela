import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/services/student_portal_sync_service.dart';
import 'package:mayabela/services/student_profile_service.dart';

class StudentProfileScreen extends StatelessWidget {
  const StudentProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: StudentPortalSyncService.instance,
      builder: (context, _) {
        final sync = StudentPortalSyncService.instance;
        final profile = StudentProfileService.profileForCurrentUser();

        if (sync.isSyncing && profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Profile')),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (profile == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Profile')),
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  sync.error ??
                      'Student record not found. Please sign in again or contact your school admin.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red.shade700),
                ),
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: const Text('My Profile')),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ProfileHeader(profile: profile),
              const Divider(height: 28),
              _row('Student ID', profile.studentId),
              _row('School', profile.schoolName),
              _row('School ID', profile.schoolId),
              _row('Grade', profile.grade),
              _row('Class', profile.className),
              if (profile.section.isNotEmpty) _row('Section', profile.section),
              _row('Roll number', profile.rollNumber),
              if (profile.homeroomTeacher != null &&
                  profile.homeroomTeacher!.trim().isNotEmpty)
                _row('Homeroom teacher', profile.homeroomTeacher!),
              if (profile.gender != null) _row('Gender', profile.gender!),
              if (profile.dateOfBirth != null)
                _row('Date of birth', _formatDate(profile.dateOfBirth!)),
              if (profile.portalUsername != null)
                _row('Portal username', profile.portalUsername!),
              if (profile.portalStatus != null)
                _row('Portal status', profile.portalStatus!),
            ],
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return ListTile(
      title: Text(label),
      trailing: Text(
        value,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.profile});

  final StudentPortalProfile profile;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Avatar(profile: profile),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                profile.fullName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                profile.studentId,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const SizedBox(height: 4),
              Text(
                '${profile.grade} · ${profile.className}',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.profile});

  final StudentPortalProfile profile;

  @override
  Widget build(BuildContext context) {
    const radius = 40.0;

    if (profile.hasPhoto) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(profile.photoPath!)),
      );
    }

    if (profile.hasSchoolLogo) {
      final logoUrl = profile.schoolLogoUrl?.trim();
      if (logoUrl != null && logoUrl.isNotEmpty) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: NetworkImage(logoUrl),
        );
      }
      if (!kIsWeb) {
        return CircleAvatar(
          radius: radius,
          backgroundImage: FileImage(File(profile.schoolLogoPath!)),
        );
      }
    }

    return CircleAvatar(
      radius: radius,
      child: Text(
        profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
        style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
      ),
    );
  }
}
