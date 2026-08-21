import 'package:flutter/material.dart';

import 'package:mayabela/models/student_portal.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/student_account_service.dart';

class AdminStudentPortalSettingsScreen extends StatefulWidget {
  const AdminStudentPortalSettingsScreen({super.key});

  @override
  State<AdminStudentPortalSettingsScreen> createState() =>
      _AdminStudentPortalSettingsScreenState();
}

class _AdminStudentPortalSettingsScreenState
    extends State<AdminStudentPortalSettingsScreen> {
  bool _loaded = false;
  bool _enabled = true;
  int _minimumGrade = 7;
  bool _allowHomeworkUpload = true;
  bool _allowReportDownload = true;
  bool _allowStudentMessaging = false;
  bool _allowClassRank = false;
  final _tempPassword = TextEditingController(text: 'Welcome12!');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await SchoolRegistryService.instance.load();
    final schoolId = AuthService.activeSchoolId;
    final settings = StudentAccountService.instance.settingsForSchool(schoolId);
    if (!mounted) return;
    setState(() {
      _enabled = settings.enabled;
      _minimumGrade = settings.minimumGrade;
      _allowHomeworkUpload = settings.allowHomeworkUpload;
      _allowReportDownload = settings.allowReportDownload;
      _allowStudentMessaging = settings.allowStudentMessaging;
      _allowClassRank = settings.allowClassRank;
      _tempPassword.text = settings.tempPasswordTemplate;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _tempPassword.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null) return;
    final school = SchoolRegistryService.instance.lookup(schoolId);
    if (school == null) return;

    final updated = school.copyWith(
      studentPortal: StudentPortalSettings(
        enabled: _enabled,
        minimumGrade: _minimumGrade,
        tempPasswordTemplate: _tempPassword.text.trim(),
        allowHomeworkUpload: _allowHomeworkUpload,
        allowReportDownload: _allowReportDownload,
        allowStudentMessaging: _allowStudentMessaging,
        allowClassRank: _allowClassRank,
      ),
    );
    await SchoolRegistryService.instance.updateSchool(updated);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Student portal settings saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('Student Portal Settings')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Student Portal Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            title: const Text('Enable Student Portal'),
            subtitle: Text(
              'The school chooses who may log in. Currently Grade $_minimumGrade '
              'and above.',
            ),
            value: _enabled,
            onChanged: (value) => setState(() => _enabled = value),
          ),
          ListTile(
            title: const Text('Minimum grade that may log in'),
            subtitle: Text(
              'Grade $_minimumGrade and above — not a fixed Grade 7. '
              'Fenote Raey sets this from Grade 1 through 12.',
            ),
            trailing: SizedBox(
              width: 120,
              child: DropdownButtonFormField<int>(
                initialValue: _minimumGrade,
                items: List.generate(12, (i) => i + 1)
                    .map(
                      (grade) => DropdownMenuItem(
                        value: grade,
                        child: Text('Grade $grade'),
                      ),
                    )
                    .toList(),
                onChanged: (value) {
                  if (value != null) setState(() => _minimumGrade = value);
                },
              ),
            ),
          ),
          TextField(
            controller: _tempPassword,
            decoration: const InputDecoration(
              labelText: 'Temporary password template',
              helperText: 'Use {year} for current year, e.g. EduAba@{year}',
            ),
          ),
          const Divider(height: 32),
          SwitchListTile(
            title: const Text('Allow homework upload'),
            value: _allowHomeworkUpload,
            onChanged: (value) => setState(() => _allowHomeworkUpload = value),
          ),
          SwitchListTile(
            title: const Text('Allow report card download'),
            value: _allowReportDownload,
            onChanged: (value) => setState(() => _allowReportDownload = value),
          ),
          SwitchListTile(
            title: const Text('Allow student messaging'),
            value: _allowStudentMessaging,
            onChanged: (value) => setState(() => _allowStudentMessaging = value),
          ),
          SwitchListTile(
            title: const Text('Show class rank'),
            value: _allowClassRank,
            onChanged: (value) => setState(() => _allowClassRank = value),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: const Text('Save settings')),
        ],
      ),
    );
  }
}
