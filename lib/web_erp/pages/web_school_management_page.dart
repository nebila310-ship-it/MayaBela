import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_backup_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/widgets/web_erp_related_tools.dart';

/// School profile / academic year / contact — replaces the old placeholder.
class WebSchoolManagementPage extends StatefulWidget {
  const WebSchoolManagementPage({super.key});

  @override
  State<WebSchoolManagementPage> createState() =>
      _WebSchoolManagementPageState();
}

class _WebSchoolManagementPageState extends State<WebSchoolManagementPage> {
  final _name = TextEditingController();
  final _city = TextEditingController();
  final _academicYear = TextEditingController();
  final _address = TextEditingController();
  final _officePhone = TextEditingController();
  final _adminPhone = TextEditingController();
  final _notes = TextEditingController();
  bool _saving = false;
  String? _error;

  SchoolRecord? get _school {
    final id = AuthService.activeSchoolId;
    if (id == null) return null;
    return SchoolRegistryService.instance.lookup(id);
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    final school = _school;
    if (school == null) return;
    _name.text = school.name;
    _city.text = school.city ?? '';
    _academicYear.text = school.academicYear ?? '';
    _address.text = school.address ?? '';
    _officePhone.text = school.officePhone ?? '';
    _adminPhone.text = school.adminContactPhone ?? '';
    _notes.text = school.notes ?? '';
  }

  @override
  void dispose() {
    _name.dispose();
    _city.dispose();
    _academicYear.dispose();
    _address.dispose();
    _officePhone.dispose();
    _adminPhone.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final school = _school;
    if (school == null) {
      setState(() => _error = 'No active school in this session.');
      return;
    }
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'School name is required.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    await SchoolRegistryService.instance.updateSchool(
      school.copyWith(
        name: name,
        city: _city.text.trim().isEmpty ? null : _city.text.trim(),
        academicYear: _academicYear.text.trim().isEmpty
            ? null
            : _academicYear.text.trim(),
        address: _address.text.trim().isEmpty ? null : _address.text.trim(),
        officePhone:
            _officePhone.text.trim().isEmpty ? null : _officePhone.text.trim(),
        adminContactPhone:
            _adminPhone.text.trim().isEmpty ? null : _adminPhone.text.trim(),
        notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
      ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('School profile saved')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final school = _school;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('School Management', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 8),
          Text(
            school == null
                ? 'No school loaded for this session.'
                : 'School ID ${school.id} · ${school.campuses.length} campus(es) · ${school.gradeLevels.length} grade levels',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 20),
          if (school == null)
            const Text('Sign in as a school owner to edit the profile.')
          else
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: WebErpTheme.cardDecoration(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      labelText: 'School name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _city,
                          decoration: const InputDecoration(
                            labelText: 'City',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _academicYear,
                          decoration: const InputDecoration(
                            labelText: 'Academic year',
                            hintText: '2025/2026',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _address,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _officePhone,
                          decoration: const InputDecoration(
                            labelText: 'Office phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _adminPhone,
                          decoration: const InputDecoration(
                            labelText: 'Admin contact phone',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _notes,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Campuses: ${school.campuses.join(", ")}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Grade levels: ${school.gradeLevels.join(", ")}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: const Text('Save school profile'),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 16),
          const WebErpRelatedToolsCard(
            title: 'Student portal',
            tools: [
              WebErpRelatedTool(
                routeId: 'student_portal_settings',
                label: 'Student portal settings',
                icon: Icons.tune,
                subtitle: 'From the grade the school sets, plus portal permissions',
              ),
              WebErpRelatedTool(
                routeId: 'student_password_resets',
                label: 'Student password requests',
                icon: Icons.lock_reset,
                subtitle: 'Approve student reset requests',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: WebErpTheme.cardDecoration(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Files & backup', style: WebErpTheme.sectionTitle(context)),
                const SizedBox(height: 6),
                Text(
                  'Daily school files live in the MaJo Bridge cloud. '
                  'Recommended: also keep a school-held JSON copy on a school '
                  'computer or school server so Fenote Raey is not locked to one place.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      await SchoolBackupService.instance.shareSchoolJsonBackup();
                      if (!mounted) return;
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'School backup JSON is ready. Save one copy locally '
                            'and keep daily work in the cloud.',
                          ),
                        ),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      messenger.showSnackBar(
                        SnackBar(content: Text('Backup failed: $e')),
                      );
                    }
                  },
                  icon: const Icon(Icons.cloud_download_outlined),
                  label: const Text('Download school backup (JSON)'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
