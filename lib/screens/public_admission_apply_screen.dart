import 'package:flutter/material.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/models/admission_extra_program.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/theme/login_role_theme.dart';
import 'package:mayabela/web_erp/login/web_login_shell.dart';
import 'package:mayabela/widgets/login_brand_header.dart';

/// Public (no login) admission application for a school.
class PublicAdmissionApplyScreen extends StatefulWidget {
  const PublicAdmissionApplyScreen({super.key, this.initialSchoolId});

  final String? initialSchoolId;

  @override
  State<PublicAdmissionApplyScreen> createState() =>
      _PublicAdmissionApplyScreenState();
}

class _PickedAttachment {
  const _PickedAttachment({required this.fileName, this.filePath});

  final String fileName;
  final String? filePath;
}

class _PublicAdmissionApplyScreenState
    extends State<PublicAdmissionApplyScreen> {
  final _schoolId = TextEditingController();
  final _fullName = TextEditingController();
  final _grade = TextEditingController();
  final _nationality = TextEditingController();
  final _homeLanguage = TextEditingController();
  final _homeAddress = TextEditingController();
  final _city = TextEditingController();
  final _studentNationalId = TextEditingController();
  final _guardian = TextEditingController();
  final _parentNationalId = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _secondGuardian = TextEditingController();
  final _secondPhone = TextEditingController();
  final _previous = TextEditingController();
  final _lastGrade = TextEditingController();
  final _priorAverage = TextEditingController();
  final _sibling = TextEditingController();
  final _specialNeeds = TextEditingController();
  final _programNotes = TextEditingController();
  DateTime? _dateOfBirth;
  String? _gender;
  String _relationship = 'Parent';
  bool _vaccinationUpToDate = false;
  bool _declared = false;
  bool _busy = false;
  String? _message;
  String? _reference;
  final Set<String> _programs = {};
  final Map<String, _PickedAttachment> _attachments = {};

  static const _requiredDocs = [
    ('birth-certificate', 'Birth certificate',
        'Scan of the official birth certificate.'),
    ('previous-school-reports', 'Previous school reports',
        'Last 2–3 years of report cards or transcripts.'),
    ('parent-national-id', 'Parent / guardian national ID',
        'National ID, passport, or residence card of the parent.'),
  ];

  static const _optionalDocs = [
    ('passport-photo', 'Student passport photo',
        'Recent colour photo, plain background.'),
    ('student-id-or-passport', 'Student national ID or passport',
        'If the student already has an ID or passport.'),
    ('vaccination-record', 'Vaccination / health record',
        'Immunisation card or clinic letter.'),
  ];

  @override
  void initState() {
    super.initState();
    final fromWidget = widget.initialSchoolId?.trim();
    final fromUri = Uri.base.queryParameters['school']?.trim();
    _schoolId.text = (fromWidget != null && fromWidget.isNotEmpty)
        ? fromWidget
        : (fromUri ?? '');
  }

  @override
  void dispose() {
    _schoolId.dispose();
    _fullName.dispose();
    _grade.dispose();
    _nationality.dispose();
    _homeLanguage.dispose();
    _homeAddress.dispose();
    _city.dispose();
    _studentNationalId.dispose();
    _guardian.dispose();
    _parentNationalId.dispose();
    _phone.dispose();
    _email.dispose();
    _secondGuardian.dispose();
    _secondPhone.dispose();
    _previous.dispose();
    _lastGrade.dispose();
    _priorAverage.dispose();
    _sibling.dispose();
    _specialNeeds.dispose();
    _programNotes.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {String? hint}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
  }

  Future<void> _pickDocument(String id) async {
    final saved = await AnnouncementAttachmentService.instance.pickAndSaveFiles(
      subdir: 'admission_documents',
    );
    if (!mounted) return;
    if (saved.isEmpty) {
      final err = AnnouncementAttachmentService.instance.lastPickError;
      if (err != null) {
        setState(() => _message = err);
      }
      return;
    }
    setState(() {
      _attachments[id] = _PickedAttachment(
        fileName: saved.first.fileName,
        filePath: saved.first.filePath,
      );
      _message = null;
    });
  }

  Future<void> _submit() async {
    final schoolId = _schoolId.text.trim().toUpperCase();
    final name = _fullName.text.trim();
    final missingDocs = [
      for (final doc in _requiredDocs)
        if (!_attachments.containsKey(doc.$1)) doc.$2,
    ];
    if (schoolId.isEmpty ||
        name.isEmpty ||
        _guardian.text.trim().isEmpty ||
        _dateOfBirth == null) {
      setState(() {
        _message =
            'School ID, student name, date of birth, and parent / guardian name are required.';
        _reference = null;
      });
      return;
    }
    if (missingDocs.isNotEmpty) {
      setState(() {
        _message = 'Attach: ${missingDocs.join(', ')}.';
        _reference = null;
      });
      return;
    }
    if (!_declared) {
      setState(() {
        _message =
            'Please confirm that the information and attachments are true.';
        _reference = null;
      });
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true);
      final documents = [
        for (final entry in _attachments.entries)
          {
            'id': entry.key,
            'fileName': entry.value.fileName,
            if (entry.value.filePath != null) 'filePath': entry.value.filePath,
          },
      ];
      final result = await SchoolAuthCloudService.instance.submitApplication(
        schoolId: schoolId,
        fullName: name,
        gradeApplying: _grade.text.trim(),
        guardianName: _guardian.text.trim(),
        guardianPhone: _phone.text.trim(),
        guardianEmail: _email.text.trim(),
        previousSchool: _previous.text.trim(),
        lastGradeCompleted: _lastGrade.text.trim(),
        previousAverage: double.tryParse(_priorAverage.text.trim()),
        dateOfBirth: _dateOfBirth,
        gender: _gender,
        nationality: _nationality.text.trim(),
        homeLanguage: _homeLanguage.text.trim(),
        homeAddress: _homeAddress.text.trim(),
        city: _city.text.trim(),
        studentNationalId: _studentNationalId.text.trim(),
        parentNationalId: _parentNationalId.text.trim(),
        parentRelationship: _relationship,
        secondGuardianName: _secondGuardian.text.trim(),
        secondGuardianPhone: _secondPhone.text.trim(),
        specialNeedsNotes: _specialNeeds.text.trim(),
        siblingAtSchool: _sibling.text.trim(),
        extraPrograms: _programs.toList(),
        programNotes: _programNotes.text.trim(),
        vaccinationUpToDate: _vaccinationUpToDate,
        documents: documents,
      );
      if (!mounted) return;
      if (result.ok) {
        setState(() {
          _reference = result.applicationId;
          _message =
              'Application received. Keep this reference for the registrar.';
        });
      } else {
        setState(() {
          _message = result.errorMessage ??
              'Could not submit. Ask the school registrar to record a walk-in application.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _message =
            'Could not reach the school cloud. Try again or visit the registrar.';
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = LoginRoleTheme.forRole('parent');
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const WebLoginBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.96),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        LoginBrandHeader(
                          schoolId: _schoolId.text,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Apply for admission',
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const Text(
                          'No login required. This follows the same file used by '
                          'international schools: student details, family contacts, '
                          'prior reports, and required identity documents. The '
                          'registrar tracks your application after submit.',
                        ),
                        const SizedBox(height: 18),
                        _sectionTitle('1. School and academic place'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _schoolId,
                          textCapitalization: TextCapitalization.characters,
                          onChanged: (_) => setState(() {}),
                          decoration: _field('School ID', hint: 'e.g. FEN101'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _grade,
                          decoration: _field(
                            'Grade / year applying for',
                            hint: 'e.g. Grade 5, Year 7, KG2',
                          ),
                        ),
                        const SizedBox(height: 18),
                        _sectionTitle('2. Student details'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _fullName,
                          decoration: _field('Student full legal name'),
                        ),
                        const SizedBox(height: 10),
                        OutlinedButton(
                          onPressed: () async {
                            final picked = await showDatePicker(
                              context: context,
                              firstDate: DateTime(1995),
                              lastDate: DateTime.now(),
                              initialDate: _dateOfBirth ?? DateTime(2016, 1, 1),
                              helpText: 'Student date of birth',
                            );
                            if (picked != null) {
                              setState(() => _dateOfBirth = picked);
                            }
                          },
                          child: Text(
                            _dateOfBirth == null
                                ? 'Date of birth (required)'
                                : 'DOB ${_dateOfBirth!.day}/${_dateOfBirth!.month}/${_dateOfBirth!.year}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: _field('Gender'),
                          items: const [
                            DropdownMenuItem(
                              value: 'Female',
                              child: Text('Female'),
                            ),
                            DropdownMenuItem(
                              value: 'Male',
                              child: Text('Male'),
                            ),
                            DropdownMenuItem(
                              value: 'Prefer not to say',
                              child: Text('Prefer not to say'),
                            ),
                          ],
                          onChanged: (v) => setState(() => _gender = v),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _nationality,
                          decoration: _field('Nationality'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _homeLanguage,
                          decoration: _field(
                            'Home / first language',
                            hint: 'Amharic, English, Oromo…',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _studentNationalId,
                          decoration: _field(
                            'Student national ID or passport number',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _homeAddress,
                          decoration: _field('Home address'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _city,
                          decoration: _field('City / woreda'),
                        ),
                        const SizedBox(height: 18),
                        _sectionTitle('3. Parent / guardian'),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _guardian,
                          decoration: _field('Parent / guardian full name'),
                        ),
                        const SizedBox(height: 10),
                        DropdownButtonFormField<String>(
                          initialValue: _relationship,
                          decoration: _field('Relationship to student'),
                          items: const [
                            DropdownMenuItem(
                              value: 'Mother',
                              child: Text('Mother'),
                            ),
                            DropdownMenuItem(
                              value: 'Father',
                              child: Text('Father'),
                            ),
                            DropdownMenuItem(
                              value: 'Parent',
                              child: Text('Parent'),
                            ),
                            DropdownMenuItem(
                              value: 'Guardian',
                              child: Text('Guardian'),
                            ),
                            DropdownMenuItem(
                              value: 'Other',
                              child: Text('Other'),
                            ),
                          ],
                          onChanged: (v) =>
                              setState(() => _relationship = v ?? 'Parent'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _parentNationalId,
                          decoration: _field(
                            'Parent / guardian national ID number',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _phone,
                          keyboardType: TextInputType.phone,
                          decoration: _field('Parent / guardian phone'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _email,
                          keyboardType: TextInputType.emailAddress,
                          decoration: _field(
                            'Parent / guardian email',
                            hint: 'Used to invite you after enrol',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _secondGuardian,
                          decoration: _field(
                            'Second parent / emergency contact (optional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _secondPhone,
                          keyboardType: TextInputType.phone,
                          decoration: _field('Second contact phone'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _sibling,
                          decoration: _field(
                            'Sibling already at this school (optional)',
                          ),
                        ),
                        const SizedBox(height: 18),
                        _sectionTitle('4. Previous school'),
                        const Text(
                          'International schools usually ask for the last two '
                          'to three years of reports, not only the school name.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _previous,
                          decoration: _field('Previous school name'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _lastGrade,
                          decoration: _field('Last grade completed'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _priorAverage,
                          keyboardType: TextInputType.number,
                          decoration: _field(
                            'Latest average / report mark (optional)',
                          ),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _specialNeeds,
                          maxLines: 3,
                          decoration: _field(
                            'Learning support, language, or medical notes',
                            hint:
                                'IEP, EAL, allergies, or anything the school should know',
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Switch(
                              value: _vaccinationUpToDate,
                              onChanged: (v) =>
                                  setState(() => _vaccinationUpToDate = v),
                            ),
                            const Expanded(
                              child: Text('Vaccination record is up to date'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _sectionTitle('5. Required attachments'),
                        const Text(
                          'Same core file as ISNS, Yangon International, and '
                          'most K–12 international schools: birth certificate, '
                          'prior reports, and parent ID.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 8),
                        for (final doc in _requiredDocs)
                          _attachmentTile(doc.$1, doc.$2, doc.$3, required: true),
                        const SizedBox(height: 10),
                        _sectionTitle('Optional attachments'),
                        for (final doc in _optionalDocs)
                          _attachmentTile(doc.$1, doc.$2, doc.$3),
                        const SizedBox(height: 18),
                        _sectionTitle('6. Extra programmes'),
                        const Text(
                          'These classes will become school modules. Selecting '
                          'them now tells the registrar what the student wants '
                          'beyond the main academic place — film, sport, AI, '
                          'and art / creative studios.',
                          style: TextStyle(fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        for (final group in AdmissionExtraPrograms.groups) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 6, bottom: 4),
                            child: Text(
                              group,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final program in AdmissionExtraPrograms.all
                                  .where((p) => p.group == group))
                                FilterChip(
                                  label: Text(program.title),
                                  selected: _programs.contains(program.id),
                                  onSelected: (on) {
                                    setState(() {
                                      if (on) {
                                        _programs.add(program.id);
                                      } else {
                                        _programs.remove(program.id);
                                      }
                                    });
                                  },
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 10),
                        TextField(
                          controller: _programNotes,
                          maxLines: 3,
                          decoration: _field(
                            'Programme notes (optional)',
                            hint:
                                'Experience, preferred days, or another class to add later',
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Checkbox(
                              value: _declared,
                              onChanged: (v) =>
                                  setState(() => _declared = v ?? false),
                            ),
                            const Expanded(
                              child: Padding(
                                padding: EdgeInsets.only(top: 12),
                                child: Text(
                                  'I confirm the information and attachments are '
                                  'true and complete.',
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        FilledButton(
                          onPressed: _busy ? null : _submit,
                          style: FilledButton.styleFrom(
                            backgroundColor: theme.primary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: _busy
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Submit application'),
                        ),
                        if (_message != null) ...[
                          const SizedBox(height: 12),
                          Text(_message!),
                        ],
                        if (_reference != null) ...[
                          const SizedBox(height: 6),
                          SelectableText(
                            _reference!,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ],
                        TextButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Back to sign in'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
    );
  }

  Widget _attachmentTile(
    String id,
    String title,
    String hint, {
    bool required = false,
  }) {
    final picked = _attachments[id];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Text(required ? '$title (required)' : title),
        subtitle: Text(picked?.fileName ?? hint),
        trailing: TextButton.icon(
          onPressed: () => _pickDocument(id),
          icon: Icon(
            picked == null ? Icons.attach_file : Icons.check_circle_outline,
          ),
          label: Text(picked == null ? 'Attach' : 'Replace'),
        ),
      ),
    );
  }
}

/// Carries the application reference in [SchoolAuthCloudResult.profile.username]
/// as a lightweight id without creating a login account.
