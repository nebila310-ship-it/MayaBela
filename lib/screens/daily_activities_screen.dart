import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

enum DailyActivityMode { teacher, parent }

class DailyActivitiesScreen extends StatefulWidget {
  const DailyActivitiesScreen({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.className,
    this.mode = DailyActivityMode.teacher,
  });

  final String studentId;
  final String studentName;
  final String className;
  final DailyActivityMode mode;

  @override
  State<DailyActivitiesScreen> createState() => _DailyActivitiesScreenState();
}

class _DailyActivitiesScreenState extends State<DailyActivitiesScreen> {
  final _data = SchoolDataService.instance;
  final _teacherComment = TextEditingController();
  final _parentComment = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  final Set<String> _selectedOptions = {};
  DailyActivityReport? _report;
  late String _studentKey;

  List<DailyActivityOption> get _options => _data.getDailyActivityOptions();

  @override
  void initState() {
    super.initState();
    _studentKey = _data.resolveDailyActivityStudentKey(
      studentId: widget.studentId,
      studentName: widget.studentName,
    );
    _loadReport();
  }

  @override
  void dispose() {
    _teacherComment.dispose();
    _parentComment.dispose();
    super.dispose();
  }

  void _loadReport() {
    _report = _data.getDailyActivityForStudent(
      _studentKey,
      _selectedDate,
      studentName: widget.studentName,
    );
    _selectedOptions
      ..clear()
      ..addAll(_report?.selectedOptionIds ?? []);
    _teacherComment.text = _report?.teacherComment ?? '';
    _parentComment.text = _report?.parentComment ?? '';
    setState(() {});
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      _selectedDate = picked;
      _loadReport();
    }
  }

  void _saveTeacherReport() {
    final s = AppLocale.instance.strings;
    _data.saveDailyActivity(
      studentId: _studentKey,
      studentName: widget.studentName,
      className: widget.className,
      date: _selectedDate,
      selectedOptionIds: _selectedOptions.toList(),
      teacherComment: _teacherComment.text.trim(),
      teacherName: AuthService.displayNameForRole(AuthService.roleTeacher),
    );
    _loadReport();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.dailyReportSaved),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _markParentSeen() {
    final s = AppLocale.instance.strings;
    if (_report == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.noReportForDay)),
      );
      return;
    }

    _data.markDailyActivitySeen(
      reportId: _report!.id,
      parentName: AuthService.displayNameForRole(AuthService.roleParent),
      parentComment: _parentComment.text.trim(),
    );
    _loadReport();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.parentNotifiedViewed),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isTeacher = widget.mode == DailyActivityMode.teacher;
    final report = _report;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.teal,
            title: Text(s.dailyActivities),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              Card(
                color: Colors.teal.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.studentName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text('${widget.className} · ${s.dailyReport}'),
                      const SizedBox(height: 8),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(
                          Icons.calendar_today,
                          color: Colors.teal,
                        ),
                        title: Text(
                          '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
                        ),
                        trailing: TextButton(
                          onPressed: _pickDate,
                          child: Text(s.change),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (report != null && isTeacher) ...[
                const SizedBox(height: 12),
                _SeenStatusBanner(report: report),
              ],
              if (!isTeacher && report == null) ...[
                const SizedBox(height: 12),
                Card(
                  color: Colors.orange.shade50,
                  child: ListTile(
                    leading: const Icon(Icons.info_outline, color: Colors.orange),
                    title: Text(s.noReportForDay),
                    subtitle: Text(s.parentWillTapSeen),
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Text(
                s.todaysActivities,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              if (!isTeacher && report == null)
                Text(
                  s.noReportForDay,
                  style: TextStyle(color: Colors.grey.shade600),
                )
              else
                ..._options.map((option) {
                final selected = _selectedOptions.contains(option.id);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  color: selected ? Colors.teal.shade50 : null,
                  child: CheckboxListTile(
                    value: selected,
                    onChanged: isTeacher
                        ? (value) {
                            setState(() {
                              if (value == true) {
                                _selectedOptions.add(option.id);
                              } else {
                                _selectedOptions.remove(option.id);
                              }
                            });
                          }
                        : null,
                    title: Text(option.label),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                );
              }),
              if (report != null || isTeacher) ...[
              const SizedBox(height: 16),
              TextField(
                controller: _teacherComment,
                readOnly: !isTeacher,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: s.teacherCommentLabel,
                  hintText: s.teacherCommentHint,
                  border: const OutlineInputBorder(),
                  filled: !isTeacher,
                  fillColor: Colors.grey.shade100,
                ),
              ),
              ],
              const SizedBox(height: 12),
              if (!isTeacher && report != null) ...[
                TextField(
                  controller: _parentComment,
                  readOnly: report.parentHasSeen,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: report.parentHasSeen
                        ? s.parentCommentLabel
                        : s.yourCommentOptional,
                    border: const OutlineInputBorder(),
                    filled: report.parentHasSeen,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ] else if (isTeacher &&
                  report?.parentComment != null &&
                  report!.parentComment!.isNotEmpty) ...[
                TextField(
                  controller: _parentComment,
                  readOnly: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: s.parentCommentLabel,
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.grey.shade100,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (isTeacher)
                ElevatedButton.icon(
                  onPressed: _saveTeacherReport,
                  icon: const Icon(Icons.save),
                  label: Text(s.saveReport),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                )
              else ...[
                if (report != null && !report.parentHasSeen)
                  ElevatedButton.icon(
                    onPressed: _markParentSeen,
                    icon: const Icon(Icons.visibility),
                    label: Text(s.seenReport),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  )
                else if (report != null && report.parentHasSeen)
                  Card(
                    color: Colors.green.shade50,
                    child: ListTile(
                      leading: Icon(
                        Icons.check_circle,
                        color: Colors.green.shade700,
                      ),
                      title: Text(s.youViewedReport),
                      subtitle: Text(
                        s.seenByOn(
                          report.parentSeenBy!,
                          '${report.parentSeenAt!.day}/${report.parentSeenAt!.month}/${report.parentSeenAt!.year}',
                        ),
                      ),
                    ),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _SeenStatusBanner extends StatelessWidget {
  const _SeenStatusBanner({required this.report});

  final DailyActivityReport report;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        if (report.parentHasSeen) {
          return Card(
            color: Colors.green.shade50,
            child: ListTile(
              leading: Icon(Icons.check_circle, color: Colors.green.shade700),
              title: Text(s.parentSeenReport),
              subtitle: Text(
                s.parentViewedOn(
                  report.parentSeenBy!,
                  '${report.parentSeenAt!.day}/${report.parentSeenAt!.month}/${report.parentSeenAt!.year}',
                ),
              ),
            ),
          );
        }

        return Card(
          color: Colors.orange.shade50,
          child: ListTile(
            leading: const Icon(Icons.schedule, color: Colors.orange),
            title: Text(s.waitingForParentView),
            subtitle: Text(s.parentWillTapSeen),
          ),
        );
      },
    );
  }
}
