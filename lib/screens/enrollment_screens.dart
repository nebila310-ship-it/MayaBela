import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/enrollment.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/utils/email_utils.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

export 'parent_signup_screen.dart';

class SchoolRegistrationScreen extends StatefulWidget {
  const SchoolRegistrationScreen({super.key});

  @override
  State<SchoolRegistrationScreen> createState() =>
      _SchoolRegistrationScreenState();
}

class _SchoolRegistrationScreenState extends State<SchoolRegistrationScreen> {
  final _schoolName = TextEditingController();
  final _city = TextEditingController();
  final _academicYear = TextEditingController(text: '2025/2026');
  final _grades = TextEditingController(text: 'Grade 1, Grade 2, Grade 3');
  final _sections = TextEditingController(text: 'Grade 1A, Grade 1B, Grade 2A');
  final _adminName = TextEditingController();
  final _adminEmail = TextEditingController();
  final _adminPhone = TextEditingController();
  final _password = TextEditingController();
  final _confirmPassword = TextEditingController();
  String message = '';

  AppStrings get s => AppLocale.instance.strings;

  @override
  void dispose() {
    _schoolName.dispose();
    _city.dispose();
    _academicYear.dispose();
    _grades.dispose();
    _sections.dispose();
    _adminName.dispose();
    _adminEmail.dispose();
    _adminPhone.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    setState(() => message = '');
    if (_schoolName.text.trim().isEmpty ||
        _adminName.text.trim().isEmpty ||
        _adminPhone.text.trim().isEmpty) {
      setState(() => message = s.fillRequiredFields);
      return;
    }
    if (!EmailUtils.isValid(_adminEmail.text)) {
      setState(() => message = s.emailRequired);
      return;
    }
    if (_password.text.length < AuthService.minPasswordLength) {
      setState(() => message = s.passwordTooShort);
      return;
    }
    if (_password.text != _confirmPassword.text) {
      setState(() => message = s.passwordsNoMatch);
      return;
    }

    final setup = SchoolSetup(
      academicYear: _academicYear.text.trim(),
      gradeLevels: _grades.text
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList(),
      sections: _sections.text
          .split(',')
          .map((g) => g.trim())
          .where((g) => g.isNotEmpty)
          .toList(),
    );

    final school = await SchoolRegistryService.instance.registerSchool(
      name: _schoolName.text.trim(),
      city: _city.text.trim(),
      setup: setup,
      adminUsername: _adminPhone.text.trim(),
    );

    final error = AuthService.registerSchoolAdmin(
      schoolName: school.name,
      city: school.city ?? '',
      adminFullName: _adminName.text.trim(),
      adminEmail: EmailUtils.normalize(_adminEmail.text),
      adminPhone: _adminPhone.text.trim(),
      password: _password.text,
      schoolId: school.id,
    );

    if (error == 'exists') {
      setState(() => message = s.phoneAlreadyRegistered);
      return;
    }
    if (error == 'invalid_phone') {
      setState(() => message = s.invalidPhone);
      return;
    }

    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.schoolRegistered),
        content: Text(
          '${s.schoolId}: ${school.id}\n${s.schoolNameLabel}: ${school.name}\n\n${s.saveSchoolIdHint}',
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.indigo,
        title: Text(s.registerSchool),
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          Text(s.registerSchoolIntro, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Text(s.schoolDetails, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _schoolName,
            decoration: InputDecoration(labelText: s.schoolNameLabel, filled: true),
          ),
          TextField(
            controller: _city,
            decoration: InputDecoration(labelText: s.city, filled: true),
          ),
          TextField(
            controller: _academicYear,
            decoration: InputDecoration(labelText: s.academicYear, filled: true),
          ),
          TextField(
            controller: _grades,
            decoration: InputDecoration(labelText: s.gradeLevelsHint, filled: true),
          ),
          TextField(
            controller: _sections,
            decoration: InputDecoration(labelText: s.sectionsHint, filled: true),
          ),
          const Divider(height: 32),
          Text(s.principalAccount, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          TextField(
            controller: _adminName,
            decoration: InputDecoration(labelText: s.fullName, filled: true),
          ),
          TextField(
            controller: _adminEmail,
            decoration: InputDecoration(labelText: s.email, filled: true),
            keyboardType: TextInputType.emailAddress,
          ),
          TextField(
            controller: _adminPhone,
            decoration: InputDecoration(
              labelText: s.phoneNumber,
              hintText: s.phoneLoginHint,
              helperText: s.phoneLoginHelp,
              filled: true,
            ),
            keyboardType: TextInputType.phone,
          ),
          TextField(
            controller: _password,
            obscureText: true,
            decoration: InputDecoration(labelText: s.password, filled: true),
          ),
          TextField(
            controller: _confirmPassword,
            obscureText: true,
            decoration: InputDecoration(labelText: s.confirmPassword, filled: true),
          ),
          if (message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(message, style: const TextStyle(color: Colors.red)),
          ],
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _register,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.indigo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: Text(s.createSchool),
          ),
        ],
      ),
    );
  }
}
