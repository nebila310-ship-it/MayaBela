import 'package:flutter/material.dart';

import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/discipline_service.dart';
import 'package:mayabela/services/dosa_service.dart';
import 'package:mayabela/services/library_rental_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/persistence/transfer_persistence_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/student_sis_profile.dart';
import 'package:mayabela/services/student_support_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/paginated_directory.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/student_sis_record_view.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/staff_registry_avatar.dart';
import 'package:mayabela/widgets/student_medical_info_panel.dart';

/// Pending student opened from Students or LMS. Cleared after the page reads it.
class SisRoute {
  static String? pendingStudentId;
}

/// Full SIS record assembled from existing school stores — not a second ledger.
class WebSisPage extends StatefulWidget {
  const WebSisPage({super.key, this.initialStudentId, this.onNavigate});

  final String? initialStudentId;
  final ValueChanged<String>? onNavigate;

  @override
  State<WebSisPage> createState() => _WebSisPageState();
}

class _WebSisPageState extends State<WebSisPage> {
  final _search = TextEditingController();
  String? _studentId;
  var _hydrated = false;

  bool get _canView => ModuleAccess.canView('students');

  @override
  void initState() {
    super.initState();
    _studentId = widget.initialStudentId ?? SisRoute.pendingStudentId;
    SisRoute.pendingStudentId = null;
    if (_studentId != null) {
      final student = StudentRegistryService.instance.lookupById(_studentId!);
      if (student != null) _search.text = student.fullName;
    }
    _hydrate();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _hydrate() async {
    await Future.wait([
      StudentSupportService.instance.ensureLoaded(),
      DisciplineService.instance.ensureLoaded(),
      DosaService.instance.ensureLoaded(),
      LibraryRentalService.instance.ensureLoaded(),
      TransferPersistenceService.instance.loadIntoService(),
    ]);
    if (!mounted) return;
    setState(() => _hydrated = true);
  }

  List<AdminStudentRecord> get _hits {
    final q = _search.text.trim();
    if (q.isEmpty) return const [];
    final schoolId = AuthService.activeSchoolId;
    var students = schoolId == null
        ? StudentRegistryService.instance.getAllStudents()
        : StudentRegistryService.instance.studentsForSchool(schoolId);
    return students
        .where(
          (s) => PaginatedDirectory.matchesText(q, [s.fullName, s.studentId]),
        )
        .take(12)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    if (!_canView) {
      return const Center(child: Text('You do not have access to the SIS.'));
    }
    final narrow = WebViewport.isNarrow(context);
    final snapshot =
        _studentId == null ? null : StudentSisProfile.load(_studentId!);
    final student = snapshot?.student;

    return Padding(
      padding: EdgeInsets.fromLTRB(narrow ? 12 : 20, 12, narrow ? 12 : 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Student information',
                  style: WebErpTheme.sectionTitle(context),
                ),
              ),
              if (widget.onNavigate != null)
                TextButton(
                  onPressed: () => widget.onNavigate!('students'),
                  child: const Text('Students directory'),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'One SIS record from Students, Gradebook, Attendance, Student '
            'support, Student Affairs, and Library. This is not a second roster.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Search by name or student ID…',
              prefixIcon: Icon(Icons.search),
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          if (_search.text.trim().isNotEmpty && _hits.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final hit in _hits)
                    ActionChip(
                      label: Text('${hit.fullName} · ${hit.studentId}'),
                      onPressed: () => setState(() {
                        _studentId = hit.studentId;
                        _search.text = hit.fullName;
                      }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          Expanded(
            child: !_hydrated
                ? const Center(child: CircularProgressIndicator())
                : student == null
                    ? Center(
                        child: Text(
                          'Search a student to open the full SIS record.',
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : DecoratedBox(
                        decoration: WebErpTheme.cardDecoration(context),
                        child: ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            Row(
                              children: [
                                StaffRegistryAvatar(
                                  staffId: student.studentId,
                                  name: student.fullName,
                                  photoPath: student.photoPath,
                                  radius: 28,
                                  isStudent: true,
                                  fallbackColor: AdminFormTheme.student.primary,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student.fullName,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 18,
                                        ),
                                      ),
                                      Text(
                                        '${student.studentId} · ${student.grade} · ${student.className}',
                                      ),
                                    ],
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => showWebStudentProfileDialog(
                                    context,
                                    studentId: student.studentId,
                                    onUpdated: () => setState(() {}),
                                  ),
                                  child: const Text('Edit profile'),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'DOB ${ParentInviteService.formatDob(student.dateOfBirth)}'
                              ' · ${student.lifecycleStatus.label}'
                              ' · ${snapshot!.groupingSummary}',
                            ),
                            Text(
                              'Parent ${student.fatherName ?? student.guardianName ?? '—'}'
                              ' (${student.fatherPhone ?? student.guardianPhone ?? '—'})',
                            ),
                            const SizedBox(height: 12),
                            StudentMedicalInfoPanel(
                              hasMedicalCondition: student.hasMedicalCondition,
                              medicalConditionDetails:
                                  student.medicalConditionDetails,
                              otherMedicalInfo: student.otherMedicalInfo,
                              compact: true,
                            ),
                            const SizedBox(height: 12),
                            StudentSisRecordView(snapshot: snapshot),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}
