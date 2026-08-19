import 'package:flutter/material.dart';

import 'package:mayabela/models/grade_workflow.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class AdminGradeWorkflowSettingsScreen extends StatefulWidget {
  const AdminGradeWorkflowSettingsScreen({super.key});

  @override
  State<AdminGradeWorkflowSettingsScreen> createState() =>
      _AdminGradeWorkflowSettingsScreenState();
}

class _AdminGradeWorkflowSettingsScreenState
    extends State<AdminGradeWorkflowSettingsScreen> {
  bool _requireApproval = true;
  bool _notifyApprovers = true;
  bool _notifyTeacher = true;
  bool _notifyParents = true;
  final _selectedRoles = <GradeApprovalRole>{GradeApprovalRole.admin};

  @override
  void initState() {
    super.initState();
    final schoolId = AuthService.activeSchoolId;
    final school =
        schoolId != null ? SchoolRegistryService.instance.lookup(schoolId) : null;
    final settings = school?.gradeWorkflow ?? const GradeWorkflowSettings();
    _requireApproval = settings.requireApproval;
    _notifyApprovers = settings.notifyApproversOnSubmit;
    _notifyTeacher = settings.notifyTeacherOnDecision;
    _notifyParents = settings.notifyParentsOnPublish;
    _selectedRoles
      ..clear()
      ..addAll(settings.approvalChain);
  }

  Future<void> _save() async {
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null) return;
    final school = SchoolRegistryService.instance.lookup(schoolId);
    if (school == null) return;

    final chain = _selectedRoles.isEmpty
        ? const [GradeApprovalRole.admin]
        : GradeApprovalRole.values
            .where((role) => _selectedRoles.contains(role))
            .toList();

    school.gradeWorkflow = GradeWorkflowSettings(
      requireApproval: _requireApproval,
      approvalChain: chain,
      notifyApproversOnSubmit: _notifyApprovers,
      notifyTeacherOnDecision: _notifyTeacher,
      notifyParentsOnPublish: _notifyParents,
    );
    await SchoolRegistryService.instance.updateSchool(school);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Grade approval settings saved'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Grade approval workflow'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          SwitchListTile(
            title: const Text('Require admin approval before publishing'),
            value: _requireApproval,
            onChanged: (value) => setState(() => _requireApproval = value),
          ),
          const Divider(),
          const ListTile(
            title: Text('Approval levels (in order)'),
            subtitle: Text('Subject teacher enters grades, then each level approves.'),
          ),
          ...GradeApprovalRole.values.map(
            (role) => CheckboxListTile(
              title: Text(role.label),
              value: _selectedRoles.contains(role),
              onChanged: (value) {
                setState(() {
                  if (value == true) {
                    _selectedRoles.add(role);
                  } else {
                    _selectedRoles.remove(role);
                  }
                });
              },
            ),
          ),
          const Divider(),
          SwitchListTile(
            title: const Text('Notify approvers on submission'),
            value: _notifyApprovers,
            onChanged: (value) => setState(() => _notifyApprovers = value),
          ),
          SwitchListTile(
            title: const Text('Notify teacher on approve/reject'),
            value: _notifyTeacher,
            onChanged: (value) => setState(() => _notifyTeacher = value),
          ),
          SwitchListTile(
            title: const Text('Notify parents when grades are published'),
            value: _notifyParents,
            onChanged: (value) => setState(() => _notifyParents = value),
          ),
        ],
      ),
    );
  }
}
