import 'package:flutter/material.dart';

import 'package:mayabela/models/transfer_models.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/web_admin_profile_dialog.dart';

/// Graduated students — alumni list (TOR student lifecycle end state).
class WebAlumniPage extends StatefulWidget {
  const WebAlumniPage({super.key});

  @override
  State<WebAlumniPage> createState() => _WebAlumniPageState();
}

class _WebAlumniPageState extends State<WebAlumniPage> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    final schoolId = AuthService.activeSchoolId;
    var alumni = StudentRegistryService.instance
        .registrySnapshot()
        .where((s) {
          if (s.lifecycleStatus != StudentLifecycleStatus.graduated) {
            return false;
          }
          if (schoolId == null || schoolId.isEmpty) return true;
          return s.schoolId.toUpperCase() == schoolId.toUpperCase();
        })
        .toList();
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      alumni = alumni
          .where(
            (s) =>
                s.fullName.toLowerCase().contains(q) ||
                s.studentId.toLowerCase().contains(q),
          )
          .toList();
    }

    return Padding(
      padding: EdgeInsets.all(narrow ? 12 : 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Alumni', style: WebErpTheme.sectionTitle(context)),
          const SizedBox(height: 4),
          Text(
            'Students who completed the lifecycle (graduated). '
            'Promotion still happens in Transfers & Promotion.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Chip(label: Text('${alumni.length} alumni')),
              SizedBox(
                width: 260,
                child: TextField(
                  controller: _search,
                  decoration: const InputDecoration(
                    hintText: 'Search name or student ID…',
                    prefixIcon: Icon(Icons.search),
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: WebErpTheme.cardDecoration(context),
              child: alumni.isEmpty
                  ? const Center(
                      child: Text('No graduated students yet.'),
                    )
                  : ListView.separated(
                      itemCount: alumni.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final s = alumni[i];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              s.fullName.isEmpty ? '?' : s.fullName[0],
                            ),
                          ),
                          title: Text(s.fullName),
                          subtitle: Text(
                            '${s.studentId} · ${s.grade} · ${s.className}'
                            '${s.academicYear == null || s.academicYear!.isEmpty ? '' : ' · ${s.academicYear}'}',
                          ),
                          onTap: () => showWebStudentProfileDialog(
                            context,
                            studentId: s.studentId,
                            onUpdated: () => setState(() {}),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
