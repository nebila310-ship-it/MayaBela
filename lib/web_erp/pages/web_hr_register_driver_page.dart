import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/hr_transport_onboarding_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';

/// HR registers a driver login, creates their bus, and links students.
class WebHrRegisterDriverPage extends StatefulWidget {
  const WebHrRegisterDriverPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  State<WebHrRegisterDriverPage> createState() =>
      _WebHrRegisterDriverPageState();
}

class _WebHrRegisterDriverPageState extends State<WebHrRegisterDriverPage> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _busNumber = TextEditingController();
  final _routeFrom = TextEditingController();
  final _routeThrough = TextEditingController();
  final _routeTo = TextEditingController();
  final _plateNumber = TextEditingController();
  final _selectedStudentIds = <String>{};
  bool _saving = false;

  bool get _canManage =>
      ModuleAccess.canManage('transport') || ModuleAccess.canHireStaff;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _busNumber.dispose();
    _routeFrom.dispose();
    _routeThrough.dispose();
    _routeTo.dispose();
    _plateNumber.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_canManage) return;
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null || schoolId.trim().isEmpty) {
      _toast('Select a school first.', error: true);
      return;
    }

    setState(() => _saving = true);
    final result = await HrTransportOnboardingService.instance.registerDriver(
      schoolId: schoolId,
      fullName: _name.text,
      phone: _phone.text,
      email: _email.text,
      busNumber: _busNumber.text,
      routeFrom: _routeFrom.text,
      routeThrough: _routeThrough.text,
      routeTo: _routeTo.text,
      plateNumber: _plateNumber.text,
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok || result.driver == null) {
      _toast(_errorText(result.errorCode), error: true);
      return;
    }

    final linked = HrTransportOnboardingService.instance.assignStudentsToBus(
      busId: result.driver!.busId,
      studentIds: _selectedStudentIds,
    );

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Driver registered'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${result.driver!.fullName} can now sign in as Driver.'),
                const SizedBox(height: 12),
                _copyRow('Driver ID', result.driver!.driverId),
                _copyRow('Bus link', result.driver!.busId),
                _copyRow('Login phone', result.loginUsername ?? ''),
                _copyRow('Temp password', result.tempPassword ?? ''),
                const SizedBox(height: 8),
                Text(
                  linked == 0
                      ? 'No students linked yet. You can assign them from this page or Students.'
                      : '$linked student(s) linked to ${result.driver!.busId}.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Live GPS appears after this driver opens the MayaBela app on a phone with location on.',
                  style: TextStyle(height: 1.35),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onNavigate?.call('transport_live_gps');
              },
              child: const Text('Open live GPS'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                widget.onNavigate?.call('transport');
              },
              child: const Text('Done'),
            ),
          ],
        );
      },
    );

    _name.clear();
    _phone.clear();
    _email.clear();
    _busNumber.clear();
    _routeFrom.clear();
    _routeThrough.clear();
    _routeTo.clear();
    _plateNumber.clear();
    _selectedStudentIds.clear();
    if (mounted) setState(() {});
  }

  String _errorText(String? code) {
    return switch (code) {
      'name' => 'Enter the driver name.',
      'invalid_phone' => 'Enter a valid Ethiopian phone number.',
      'exists' => 'A user with this phone is already registered.',
      'bus_number' => 'Enter a bus number.',
      'route' => 'Enter route from, through, and to.',
      'plate' => 'Enter the plate number.',
      'no_school' => 'Select a school first.',
      _ => 'Could not register this driver. Try again.',
    };
  }

  void _toast(String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: error ? Colors.red.shade700 : null,
      ),
    );
  }

  Widget _copyRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text(label)),
          Expanded(
            child: SelectableText(
              value,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          IconButton(
            tooltip: 'Copy',
            onPressed: value.isEmpty
                ? null
                : () => Clipboard.setData(ClipboardData(text: value)),
            icon: const Icon(Icons.copy, size: 18),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schoolId = AuthService.activeSchoolId;
    final students = schoolId == null
        ? const <AdminStudentRecord>[]
        : StudentRegistryService.instance.studentsForSchool(schoolId);
    final drivers = schoolId == null
        ? DriverRegistryService.instance.getAllDrivers()
        : DriverRegistryService.instance.driversForSchool(schoolId);

    return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Register driver',
                style: WebErpTheme.sectionTitle(context),
              ),
              const SizedBox(height: 4),
              Text(
                'HR creates the driver login, assigns a bus, and links students. '
                'The driver then shares live GPS from their phone.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  SizedBox(
                    width: 520,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: WebErpTheme.cardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Driver and bus',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _name,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Full name',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _phone,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Phone (login)',
                              hintText: '09… or 07…',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _email,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'Email (optional)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _busNumber,
                            decoration: const InputDecoration(
                              labelText: 'Bus number',
                              hintText: 'Bus 12',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _routeFrom,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Route from',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _routeThrough,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Through',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _routeTo,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              labelText: 'Route to',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _plateNumber,
                            textCapitalization: TextCapitalization.characters,
                            decoration: const InputDecoration(
                              labelText: 'Plate number',
                              border: OutlineInputBorder(),
                            ),
                            onChanged: (v) {
                              final upper = v.toUpperCase();
                              if (upper != v) {
                                _plateNumber.value = TextEditingValue(
                                  text: upper,
                                  selection: TextSelection.collapsed(
                                    offset: upper.length,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _canManage && !_saving ? _save : null,
                            icon: _saving
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.badge_outlined),
                            label: Text(
                              _saving
                                  ? 'Saving…'
                                  : 'Create driver, bus, and student links',
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 420,
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: WebErpTheme.cardDecoration(context),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Link students to this bus',
                            style: Theme.of(context).textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Selected students get this bus link (BUS-*). Parents '
                            'and Live GPS use that same ID.',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(height: 12),
                          if (students.isEmpty)
                            const Text('No active students in this school yet.')
                          else
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxHeight: 420),
                              child: ListView.builder(
                                shrinkWrap: true,
                                itemCount: students.length,
                                itemBuilder: (context, i) {
                                  final student = students[i];
                                  final selected = _selectedStudentIds
                                      .contains(student.studentId);
                                  final already = student.transportId?.trim();
                                  return CheckboxListTile(
                                    dense: true,
                                    value: selected,
                                    onChanged: (v) {
                                      setState(() {
                                        if (v == true) {
                                          _selectedStudentIds
                                              .add(student.studentId);
                                        } else {
                                          _selectedStudentIds
                                              .remove(student.studentId);
                                        }
                                      });
                                    },
                                    title: Text(student.fullName),
                                    subtitle: Text(
                                      [
                                        student.className,
                                        if (already != null && already.isNotEmpty)
                                          'Now $already',
                                      ].join(' · '),
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            '${_selectedStudentIds.length} selected · '
                            '${drivers.length} driver(s) already in this school',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
  }
}
