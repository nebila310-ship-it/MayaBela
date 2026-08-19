import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/student_conduct.dart';
import 'package:mayabela/models/teacher_features.dart';
import 'package:mayabela/screens/messages_screen.dart';
import 'package:mayabela/services/grade_analytics_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/phone_launch_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/class_rankings_list.dart';
import 'package:mayabela/widgets/student_medical_info_panel.dart';
import 'package:mayabela/widgets/student_avatar.dart';

/// Read-only homeroom student view with parent contact and conduct rating.
class HomeroomStudentProfileScreen extends StatefulWidget {
  const HomeroomStudentProfileScreen({
    super.key,
    required this.className,
    required this.entry,
  });

  final String className;
  final RankedStudentReport entry;

  @override
  State<HomeroomStudentProfileScreen> createState() =>
      _HomeroomStudentProfileScreenState();
}

class _HomeroomStudentProfileScreenState
    extends State<HomeroomStudentProfileScreen> {
  final _data = SchoolDataService.instance;

  StudentRef? get _studentRef => _data.findStudentInClass(
        className: widget.className,
        studentName: widget.entry.report.studentName,
      );

  String get _studentId => _studentRef?.id ?? widget.entry.report.studentName;

  AdminStudentRecord? get _registryRecord {
    final ref = _studentRef;
    if (ref?.registryStudentId != null) {
      return StudentRegistryService.instance
          .lookupById(ref!.registryStudentId!);
    }
    return ParentInviteService.instance.recordForStudentRef(
      name: widget.entry.report.studentName,
      registryStudentId: ref?.registryStudentId,
    );
  }

  String? get _parentPhone =>
      _registryRecord?.primaryContactPhone ?? _studentRef?.parentPhone;

  String? get _parentName =>
      _registryRecord?.primaryParentName ?? _studentRef?.parentName;

  StudentConductRating? get _conduct => _data.getStudentConduct(
        className: widget.className,
        studentId: _studentId,
      );

  void _setConduct(StudentConductRating rating) {
    setState(() {
      _data.setStudentConduct(
        className: widget.className,
        studentId: _studentId,
        rating: rating,
      );
    });
  }

  Future<void> _dialParent() async {
    final s = AppLocale.instance.strings;
    final phone = _parentPhone;
    if (phone == null || phone.trim().isEmpty) {
      _showSnack(s.noParentPhoneOnFile);
      return;
    }
    final ok = await PhoneLaunchService.instance.dial(phone);
    if (!ok && mounted) _showSnack(s.couldNotOpenPhone);
  }

  Future<void> _smsParent() async {
    final s = AppLocale.instance.strings;
    final phone = _parentPhone;
    if (phone == null || phone.trim().isEmpty) {
      _showSnack(s.noParentPhoneOnFile);
      return;
    }
    final message = s.homeroomParentSmsTemplate(
      widget.entry.report.studentName,
      widget.className,
    );
    final ok = await ParentInviteService.instance.sendSms(
      phone: phone,
      message: message,
    );
    if (!ok && mounted) _showSnack(s.couldNotOpenSms);
  }

  void _messageInApp() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MessagesScreen()),
    );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Color _gradeColor(double percentage) {
    if (percentage >= 90) return Colors.green;
    if (percentage >= 80) return Colors.lightGreen;
    if (percentage >= 70) return Colors.orange;
    if (percentage >= 50) return Colors.deepOrange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final style = rankVisualStyle(widget.entry.rank, widget.entry.average);
    final student = _studentRef;
    final report = widget.entry.report;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFF8FAFC),
          appBar: AppBar(
            backgroundColor: style.accent,
            foregroundColor: Colors.white,
            title: Text(student?.name ?? report.studentName),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [style.accent, style.accent.withValues(alpha: 0.82)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: style.accent.withValues(alpha: 0.25),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    if (student != null)
                      StudentAvatar(
                        student: student,
                        radius: 34,
                        allowEdit: false,
                      )
                    else
                      CircleAvatar(
                        radius: 34,
                        backgroundColor: Colors.white.withValues(alpha: 0.2),
                        child: Text(
                          '${widget.entry.rank}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            report.studentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${widget.className} · ${s.rankPosition(widget.entry.rank)}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            s.averageLabel(widget.entry.average),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SectionCard(
                title: s.studentConductLabel,
                icon: Icons.fact_check_outlined,
                child: ConductRatingSelector(
                  selected: _conduct,
                  onChanged: _setConduct,
                ),
              ),
              const SizedBox(height: 12),
              _SectionCard(
                title: s.contactParentTitle,
                icon: Icons.contact_phone_outlined,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_parentName != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          s.parentOf(_parentName!),
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    _ContactButton(
                      icon: Icons.phone_in_talk_rounded,
                      label: s.callParent,
                      color: const Color(0xFF15803D),
                      onTap: _dialParent,
                    ),
                    const SizedBox(height: 8),
                    _ContactButton(
                      icon: Icons.message_rounded,
                      label: s.messageInApp,
                      color: const Color(0xFF4338CA),
                      onTap: _messageInApp,
                    ),
                    const SizedBox(height: 8),
                    _ContactButton(
                      icon: Icons.sms_outlined,
                      label: s.sendSms,
                      color: const Color(0xFF0EA5E9),
                      onTap: _smsParent,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (_registryRecord != null)
                _SectionCard(
                  title: s.studentMedicalSection,
                  icon: Icons.medical_information_outlined,
                  child: StudentMedicalInfoPanel(
                    hasMedicalCondition: _registryRecord!.hasMedicalCondition,
                    medicalConditionDetails:
                        _registryRecord!.medicalConditionDetails,
                    otherMedicalInfo: _registryRecord!.otherMedicalInfo,
                  ),
                ),
              if (_registryRecord != null) const SizedBox(height: 12),
              _SectionCard(
                title: s.subjectBreakdown,
                icon: Icons.menu_book_outlined,
                subtitle: s.homeroomGradesReadOnlyHint,
                child: Column(
                  children: report.subjects.map((subject) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subject.subject,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                if (subject.comment != null)
                                  Text(
                                    subject.comment!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: _gradeColor(subject.percentage)
                                  .withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              '${subject.score.toInt()}/${subject.maxScore.toInt()}',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _gradeColor(subject.percentage),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final Widget child;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: const Color(0xFF4338CA)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(
                subtitle!,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ContactButton extends StatelessWidget {
  const _ContactButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: color.withValues(alpha: 0.95),
                  ),
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 14, color: color),
            ],
          ),
        ),
      ),
    );
  }
}
