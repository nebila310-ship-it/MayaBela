import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/admin_registry_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/teacher_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/widgets/parent_child_registration_card.dart';
import 'package:mayabela/widgets/registration_terms_dialog.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  String selectedRole = AuthService.roleParent;

  final TextEditingController fullName = TextEditingController();
  final TextEditingController schoolId = TextEditingController();
  final TextEditingController email = TextEditingController();
  final TextEditingController phone = TextEditingController();
  final TextEditingController password = TextEditingController();
  final TextEditingController confirmPassword = TextEditingController();
  final TextEditingController teacherId = TextEditingController();
  final TextEditingController adminId = TextEditingController();
  final TextEditingController driverId = TextEditingController();

  final List<ParentChildFormEntry> _children = [ParentChildFormEntry()];
  AdminTeacherRecord? _teacherRecord;
  AdminStaffRecord? _adminRecord;
  AdminDriverRecord? _driverRecord;
  String message = '';
  bool _messageIsSuccess = false;
  bool _submitting = false;

  AppStrings get s => AppLocale.instance.strings;
  final _studentRegistry = StudentRegistryService.instance;
  final _teacherRegistry = TeacherRegistryService.instance;
  final _adminRegistry = AdminRegistryService.instance;
  final _driverRegistry = DriverRegistryService.instance;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    fullName.dispose();
    schoolId.dispose();
    email.dispose();
    phone.dispose();
    password.dispose();
    confirmPassword.dispose();
    teacherId.dispose();
    adminId.dispose();
    driverId.dispose();
    for (final child in _children) {
      child.dispose();
    }
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  void _setMessage(String msg, {required bool isSuccess}) {
    setState(() {
      message = msg;
      _messageIsSuccess = isSuccess;
    });
  }

  void _clearMessage() {
    setState(() {
      message = '';
      _messageIsSuccess = false;
    });
  }

  void _addChild() {
    setState(() => _children.add(ParentChildFormEntry()));
  }

  void _removeChild(int index) {
    if (_children.length <= 1) return;
    setState(() {
      _children[index].dispose();
      _children.removeAt(index);
    });
  }

  DateTime? _parseDob(String raw) {
    final parts = raw.trim().split('/');
    if (parts.length != 3) return null;
    try {
      return DateTime(
        int.parse(parts[2]),
        int.parse(parts[1]),
        int.parse(parts[0]),
      );
    } catch (_) {
      return null;
    }
  }

  void _lookupStudent(ParentChildFormEntry entry) {
    if (schoolId.text.trim().isEmpty) {
      _setMessage(s.enterSchoolId, isSuccess: false);
      return;
    }
    final dob = _parseDob(entry.dobController.text);
    if (dob == null) {
      _setMessage(s.invalidDateFormat, isSuccess: false);
      return;
    }
    final ok = _studentRegistry.verifyStudent(
      schoolId: schoolId.text,
      studentId: entry.studentIdController.text,
      dateOfBirth: dob,
    );
    setState(() {
      entry.record = ok
          ? _studentRegistry.lookupById(entry.studentIdController.text)
          : null;
      if (ok) {
        applyStudentContactSuggestion(
          entry: entry,
          phoneController: phone,
          nameController: fullName,
        );
      }
      message = ok ? s.studentFound : s.studentNotFound;
      _messageIsSuccess = ok;
    });
  }

  void _applyContactFromStudent(ParentChildFormEntry entry) {
    applyStudentContactSuggestion(
      entry: entry,
      phoneController: phone,
      nameController: fullName,
    );
  }

  void _applyContactInfo({
    required String name,
    required String school,
    String? emailValue,
    String? phoneValue,
  }) {
    fullName.text = name;
    schoolId.text = school;
    if (emailValue != null && emailValue.isNotEmpty) email.text = emailValue;
    if (phoneValue != null && phoneValue.isNotEmpty) phone.text = phoneValue;
  }

  void _clearRoleRecords() {
    _teacherRecord = null;
    _adminRecord = null;
    _driverRecord = null;
  }

  void _lookupTeacher() {
    final record = _teacherRegistry.lookupById(teacherId.text);
    setState(() {
      _teacherRecord = record;
      message = record == null ? s.teacherNotFound : s.teacherFound;
      _messageIsSuccess = record != null;
      if (record != null) {
        _applyContactInfo(
          name: record.fullName,
          school: record.schoolId,
          emailValue: record.email,
          phoneValue: record.phone,
        );
      }
    });
  }

  void _lookupAdmin() {
    final record = _adminRegistry.lookupById(adminId.text);
    setState(() {
      _adminRecord = record;
      message = record == null ? s.adminNotFound : s.adminFound;
      _messageIsSuccess = record != null;
      if (record != null) {
        _applyContactInfo(
          name: record.fullName,
          school: record.schoolId,
          emailValue: record.email,
          phoneValue: record.phone,
        );
      }
    });
  }

  void _lookupDriver() {
    final record = _driverRegistry.lookupById(driverId.text);
    setState(() {
      _driverRecord = record;
      message = record == null ? s.driverNotFound : s.driverFound;
      _messageIsSuccess = record != null;
      if (record != null) {
        _applyContactInfo(
          name: record.fullName,
          school: record.schoolId,
          emailValue: record.email,
          phoneValue: record.phone,
        );
      }
    });
  }

  String? _validateForm() {
    if (fullName.text.trim().isEmpty) return s.enterName;
    if (schoolId.text.trim().isEmpty) return s.enterSchoolId;
    if (email.text.trim().isEmpty && phone.text.trim().isEmpty) {
      return s.enterEmailOrPhoneSignup;
    }
    if (password.text.length < AuthService.minPasswordLength) {
      return s.passwordTooShort;
    }
    if (password.text != confirmPassword.text) return s.passwordsNoMatch;

    if (selectedRole == AuthService.roleTeacher && _teacherRecord == null) {
      return s.enterTeacherId;
    }
    if (selectedRole == AuthService.roleAdmin && _adminRecord == null) {
      return s.enterAdminId;
    }
    if (selectedRole == AuthService.roleDriver && _driverRecord == null) {
      return s.enterDriverId;
    }
    if (selectedRole == AuthService.roleParent) {
      if (!PhoneUtils.isValidLoginPhone(phone.text)) {
        return s.invalidPhone;
      }
      for (final child in _children) {
        if (child.record == null) return s.addAtLeastOneChild;
        if (_parseDob(child.dobController.text) == null) {
          return s.invalidDateFormat;
        }
        if (child.hasMedicalCondition == null) {
          return s.studentMedicalRequired;
        }
        if (child.hasMedicalCondition == true &&
            child.medicalDetailsController.text.trim().isEmpty) {
          return s.studentMedicalSpecifyRequired;
        }
      }
    }
    return null;
  }

  Future<void> _showTermsDialog() async {
    if (selectedRole == AuthService.roleParent) {
      final agreed = await showParentGuardianTermsDialog(context);
      if (agreed && mounted) {
        await _completeRegistration();
      } else if (mounted) {
        _setMessage(s.mustAgreeTerms, isSuccess: false);
      }
      return;
    }

    final agreed = await showRegistrationTermsDialog(
      context: context,
      title: s.termsTitle,
      termsBody: s.termsForRole(selectedRole),
      checkboxLabel: s.termsCheckbox,
      agreeLabel: s.iAgree,
      cancelLabel: s.cancel,
    );

    if (agreed && mounted) {
      await _completeRegistration();
    } else if (mounted) {
      _setMessage(s.mustAgreeTerms, isSuccess: false);
    }
  }

  void signUp() {
    _clearMessage();

    final validationError = _validateForm();
    if (validationError != null) {
      _setMessage(validationError, isSuccess: false);
      return;
    }

    _showTermsDialog();
  }

  Future<void> _completeRegistration() async {
    if (selectedRole == AuthService.roleParent) {
      await _completeParentRegistration();
      return;
    }

    String? linkedTeacherId;
    String? linkedAdminId;
    String? linkedDriverId;

    if (selectedRole == AuthService.roleTeacher) {
      linkedTeacherId = _teacherRecord!.teacherId;
    }
    if (selectedRole == AuthService.roleAdmin) {
      linkedAdminId = _adminRecord!.adminId;
    }
    if (selectedRole == AuthService.roleDriver) {
      linkedDriverId = _driverRecord!.driverId;
    }

    final username = email.text.trim().isNotEmpty
        ? email.text.trim().split('@').first.toLowerCase()
        : phone.text.trim().replaceAll(' ', '');

    final error = AuthService.registerUser(
      roleKey: selectedRole,
      fullName: fullName.text.trim(),
      schoolId: schoolId.text.trim(),
      email: email.text.trim(),
      phone: phone.text.trim(),
      password: password.text,
      username: username,
      linkedTeacherId: linkedTeacherId,
      linkedAdminId: linkedAdminId,
      linkedDriverId: linkedDriverId,
    );

    if (error == 'exists') {
      _setMessage(
        s.isAmharic ? 'መለያ አለ' : 'Username already exists',
        isSuccess: false,
      );
      return;
    }

    final extraSummary = switch (selectedRole) {
      AuthService.roleTeacher => '\n${s.teacherId}: $linkedTeacherId',
      AuthService.roleAdmin => '\n${s.adminId}: $linkedAdminId',
      AuthService.roleDriver => '\n${s.driverId}: $linkedDriverId',
      _ => '',
    };

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.accountCreated),
        content: Text(
          '${fullName.text.trim()} (${s.roleLabel(selectedRole)})$extraSummary\n\n${s.goToLogin}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(s.goToLogin),
          ),
        ],
      ),
    );
  }

  Future<void> _completeParentRegistration() async {
    if (_submitting) return;
    for (final child in _children) {
      if (child.record == null) {
        _setMessage(s.verifyChildFirst, isSuccess: false);
        return;
      }
      if (child.hasMedicalCondition == null) {
        _setMessage(s.studentMedicalRequired, isSuccess: false);
        return;
      }
      if (child.hasMedicalCondition == true &&
          child.medicalDetailsController.text.trim().isEmpty) {
        _setMessage(s.studentMedicalSpecifyRequired, isSuccess: false);
        return;
      }
    }

    final children = <ParentChildRegistration>[];
    for (final child in _children) {
      final dob = _parseDob(child.dobController.text);
      if (dob == null) {
        _setMessage(s.invalidDateFormat, isSuccess: false);
        return;
      }
      children.add(
        parentRegistrationFromEntry(child, dateOfBirth: dob),
      );
    }

    setState(() => _submitting = true);
    final error = await AuthService.registerParentAccount(
      fullName: fullName.text.trim(),
      schoolId: schoolId.text.trim(),
      phone: phone.text.trim(),
      password: password.text,
      email: email.text.trim(),
      children: children,
    );
    if (!mounted) return;
    setState(() => _submitting = false);

    if (error != null) {
      _setMessage(s.parentRegisterError(error), isSuccess: false);
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(s.accountCreated),
        content: Text(
          '${s.parentPendingApprovalMessage}\n\n${s.waitingForSchoolApproval}',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: Text(s.goToLogin),
          ),
        ],
      ),
    );
  }

  Widget roleButton(String roleKey) {
    return ChoiceChip(
      label: Text(s.roleLabel(roleKey)),
      selected: selectedRole == roleKey,
      onSelected: (_) => setState(() {
        selectedRole = roleKey;
        _clearRoleRecords();
        message = '';
        _messageIsSuccess = false;
      }),
    );
  }

  InputDecoration _field(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _foundBox({required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _adminCard() {
    final record = _adminRecord;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.adminProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: adminId,
                    decoration: _field(s.adminId),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _lookupAdmin,
                  child: Text(s.lookupAdmin),
                ),
              ],
            ),
            if (record != null) ...[
              const SizedBox(height: 8),
              _foundBox(
                children: [
                  Text(record.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${s.position}: ${record.position}'),
                  Text('${s.department}: ${record.department}'),
                  Text('${s.schoolId}: ${record.schoolId}'),
                  if (record.email != null) Text('${s.email}: ${record.email}'),
                  if (record.phone != null) Text('${s.phone}: ${record.phone}'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              s.isAmharic
                  ? 'ማሳያ መለያዎች: ADM-1001, ADM-1002, ADM-1003...'
                  : 'Demo IDs: ADM-1001, ADM-1002, ADM-1003...',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _driverCard() {
    final record = _driverRecord;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.driverProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: driverId,
                    decoration: _field(s.driverId),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _lookupDriver,
                  child: Text(s.lookupDriver),
                ),
              ],
            ),
            if (record != null) ...[
              const SizedBox(height: 8),
              _foundBox(
                children: [
                  Text(record.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${s.busLinkId}: ${record.busId}'),
                  Text('${s.busNumber}: ${record.busNumber}'),
                  Text('${s.routeName}: ${record.routeName}'),
                  Text('${s.plateNumber}: ${record.plateNumber}'),
                  Text('${s.schoolId}: ${record.schoolId}'),
                  if (record.email != null) Text('${s.email}: ${record.email}'),
                  if (record.phone != null) Text('${s.phone}: ${record.phone}'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              s.isAmharic
                  ? 'ማሳያ መለያዎች: DRV-1001, DRV-1002, DRV-1003...'
                  : 'Demo IDs: DRV-1001, DRV-1002, DRV-1003...',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _teacherCard() {
    final record = _teacherRecord;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(s.teacherProfile, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: teacherId,
                    decoration: _field(s.teacherId),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _lookupTeacher,
                  child: Text(s.lookupTeacher),
                ),
              ],
            ),
            if (record != null) ...[
              const SizedBox(height: 8),
              _foundBox(
                children: [
                  Text(record.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text('${s.subject}: ${record.subject}'),
                  Text('${s.assignedClass}: ${record.assignedClass}'),
                  Text('${s.schoolId}: ${record.schoolId}'),
                  if (record.email != null) Text('${s.email}: ${record.email}'),
                  if (record.phone != null) Text('${s.phone}: ${record.phone}'),
                ],
              ),
            ],
            const SizedBox(height: 8),
            Text(
              s.isAmharic
                  ? 'ማሳያ መለያዎች: TCH-1001, TCH-1002, TCH-1003...'
                  : 'Demo IDs: TCH-1001, TCH-1002, TCH-1003...',
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _parentRegistrationSection() {
    const accent = Color(0xFF00695C);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF00695C), Color(0xFF26A69A)],
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.parentRegistrationTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.linkAnotherChildHint,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.92),
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ...List.generate(
          _children.length,
          (index) => ParentChildRegistrationCard(
            index: index,
            entry: _children[index],
            schoolId: schoolId.text,
            accent: accent,
            onVerify: () => _lookupStudent(_children[index]),
            onStudentContactChanged: _applyContactFromStudent,
            onRemove: _children.length > 1 ? () => _removeChild(index) : null,
          ),
        ),
        OutlinedButton.icon(
          onPressed: _addChild,
          icon: const Icon(Icons.add_circle_outline),
          label: Text(s.addAnotherChild),
          style: OutlinedButton.styleFrom(
            foregroundColor: accent,
            side: BorderSide(color: accent.withValues(alpha: 0.5)),
            padding: const EdgeInsets.symmetric(vertical: 14),
            backgroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(s.signUp),
        backgroundColor: Colors.indigo,
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF1976D2), Color(0xFFBBDEFB)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: listPagePadding(context),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.person_add, size: 60, color: Colors.indigo.shade900),
                const SizedBox(height: 8),
                Text(
                  s.createAccount,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo.shade900,
                  ),
                ),
                const SizedBox(height: 16),
                Text(s.iAm, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: AuthService.roles.map(roleButton).toList(),
                ),
                const SizedBox(height: 16),
                TextField(controller: fullName, decoration: _field(s.fullName)),
                const SizedBox(height: 8),
                TextField(controller: schoolId, decoration: _field(s.schoolId)),
                const SizedBox(height: 8),
                TextField(controller: email, decoration: _field(s.email)),
                const SizedBox(height: 8),
                TextField(controller: phone, decoration: _field(s.phone)),
                const SizedBox(height: 8),
                TextField(
                  controller: password,
                  obscureText: true,
                  decoration: _field(s.password),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: confirmPassword,
                  obscureText: true,
                  decoration: _field(s.confirmPassword),
                ),
                if (selectedRole == AuthService.roleTeacher) ...[
                  const SizedBox(height: 16),
                  _teacherCard(),
                ],
                if (selectedRole == AuthService.roleAdmin) ...[
                  const SizedBox(height: 16),
                  _adminCard(),
                ],
                if (selectedRole == AuthService.roleDriver) ...[
                  const SizedBox(height: 16),
                  _driverCard(),
                ],
                if (selectedRole == AuthService.roleParent) ...[
                  const SizedBox(height: 16),
                  _parentRegistrationSection(),
                ],
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _submitting ? null : signUp,
                  child: _submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(s.signUp),
                ),
                const SizedBox(height: 10),
                if (message.isNotEmpty)
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _messageIsSuccess ? Colors.green.shade800 : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
