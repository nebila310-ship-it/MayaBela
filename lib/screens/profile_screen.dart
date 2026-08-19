import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/settings_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/services/teacher_credentials_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/teacher_profile_avatar.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final user = AuthService.currentUser;
        final roleKey = user?.roleKey ?? AuthService.roleTeacher;
        final schoolId = AuthService.activeSchoolId;
        final schoolName = SchoolRegistryService.instance.displayName(schoolId);
        final isTeacher = roleKey == AuthService.roleTeacher;
        final teacherRecord = isTeacher
            ? TeacherCredentialsService.instance.recordForCurrentUser()
            : null;
        final name = isTeacher
            ? TeacherAccessService.instance.teacherName
            : AuthService.displayNameForRole(roleKey);

        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.indigo,
            title: Text(s.profile),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              Center(
                child: isTeacher
                    ? TeacherProfileAvatar(
                        name: name,
                        radius: 44,
                        borderColor: Colors.indigo.shade200,
                        borderWidth: 2,
                        backgroundColor: Colors.indigo.shade50,
                        initialTextColor: Colors.indigo.shade800,
                      )
                    : CircleAvatar(
                        radius: 44,
                        backgroundColor: Colors.indigo.shade100,
                        child: Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo.shade800,
                          ),
                        ),
                      ),
              ),
              const SizedBox(height: 12),
              Text(
                name,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                s.roleLabel(roleKey),
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600, fontSize: 15),
              ),
              const SizedBox(height: 24),
              _card(
                children: [
                  _row(s.fullName, name),
                  _row(s.schoolId, schoolId ?? '—'),
                  _row('School', schoolName),
                  if (teacherRecord != null) ...[
                    _row(s.teacherId, teacherRecord.teacherId),
                    if (teacherRecord.employeeId != null)
                      _row(s.employeeId, teacherRecord.employeeId!),
                    if (teacherRecord.subject.isNotEmpty)
                      _row(s.subject, teacherRecord.subject),
                  ],
                  if (user?.phone != null && user!.phone!.isNotEmpty)
                    _row(s.phone, user.phone!),
                  if (user?.email != null && user!.email!.isNotEmpty)
                    _row(s.email, user.email!),
                  if (user != null) _row('Login', user.username),
                ],
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
                },
                icon: const Icon(Icons.settings),
                label: Text(s.settings),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.indigo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _card({required List<Widget> children}) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(children: children),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
