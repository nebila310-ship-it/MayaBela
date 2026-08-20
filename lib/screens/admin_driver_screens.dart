import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_photo_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/persistence/driver_persistence_service.dart';
import 'package:mayabela/utils/email_utils.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/utils/text_input_formatters.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/phone_contact_field.dart';

class AdminAddDriverScreen extends StatefulWidget {
  const AdminAddDriverScreen({super.key});

  @override
  State<AdminAddDriverScreen> createState() => _AdminAddDriverScreenState();
}

class _AdminAddDriverScreenState extends State<AdminAddDriverScreen> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _email = TextEditingController();
  final _busNumber = TextEditingController();
  final _routeFrom = TextEditingController();
  final _routeThrough = TextEditingController();
  final _routeTo = TextEditingController();
  final _plateNumber = TextEditingController();
  File? _pickedPhoto;
  bool _saving = false;

  AppStrings get s => AppLocale.instance.strings;

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

  Future<void> _pickPhoto() async {
    final file = await DriverPhotoService.instance.pickFromGallery();
    if (file != null) setState(() => _pickedPhoto = file);
  }

  Future<void> _save() async {
    if (_saving) return;
    final schoolId = AuthService.activeSchoolId;
    if (schoolId == null) return;

    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.enterName)),
      );
      return;
    }

    if (!EmailUtils.isValid(_email.text)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.emailRequired)),
      );
      return;
    }

    if (!PhoneUtils.isValidLoginPhone(_phone.text.trim())) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.invalidPhone)),
      );
      return;
    }

    if (_routeFrom.text.trim().isEmpty ||
        _routeThrough.text.trim().isEmpty ||
        _routeTo.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.transportRouteRequired)),
      );
      return;
    }

    if (_plateNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.transportPlateRequired)),
      );
      return;
    }

    if (_busNumber.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.busNumberRequired)),
      );
      return;
    }

    final loginKey = PhoneUtils.loginKey(_phone.text.trim());
    if (AuthService.accountExists(loginKey)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.phoneAlreadyRegistered)),
      );
      return;
    }

    setState(() => _saving = true);

    final tempPassword = AuthService.generateTempPassword();
    final routeName = DriverRegistryService.formatRoute(
      _routeFrom.text,
      _routeTo.text,
      through: _routeThrough.text,
    );

    var driver = DriverRegistryService.instance.addDriver(
      schoolId: schoolId,
      fullName: _name.text,
      phone: _phone.text,
      email: _email.text,
      busNumber: _busNumber.text,
      routeName: routeName,
      plateNumber: _plateNumber.text,
      loginUsername: loginKey,
      initialPassword: tempPassword,
    );
    final createdDriverId = driver.driverId;
    var loginCreated = false;

    try {
      if (_pickedPhoto != null) {
        final path = await DriverPhotoService.instance.saveForDriver(
          driver.driverId,
          _pickedPhoto!,
        );
        if (path != null) {
          DriverPhotoService.instance.rememberPath(driver.driverId, path);
          DriverRegistryService.instance.updatePhoto(
            driver.driverId,
            path,
            persist: false,
          );
          driver = DriverRegistryService.instance.lookupById(driver.driverId)!;
        }
      }

      final authError = AuthService.registerDriverAccount(
        fullName: _name.text,
        schoolId: schoolId,
        email: _email.text.trim(),
        phone: _phone.text.trim(),
        linkedDriverId: driver.driverId,
        password: tempPassword,
      );

      if (authError != null) {
        DriverRegistryService.instance.removeDriver(createdDriverId);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              switch (authError) {
                'invalid_phone' => s.invalidPhone,
                'invalid_email' => s.emailRequired,
                _ => s.phoneAlreadyRegistered,
              },
            ),
          ),
        );
        return;
      }
      loginCreated = true;

      DriverRegistryService.instance.saveCredentials(
        driverId: driver.driverId,
        initialPassword: tempPassword,
        loginUsername: loginKey,
        persist: false,
      );
      driver = DriverRegistryService.instance.lookupById(driver.driverId)!;

      AuthService.syncDriverAuthProfile(driver);
      await DriverPersistenceService.instance.saveRegistryFromService();
    } catch (_) {
      DriverRegistryService.instance.removeDriver(createdDriverId);
      if (loginCreated) {
        await AuthService.revokeRegisteredAccount(loginKey);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.registrationFailed)),
      );
      return;
    } finally {
      if (mounted) setState(() => _saving = false);
    }

    if (!mounted) return;

    await showAdminSuccessDialog(
      context: context,
      title: s.driverCreated,
      subtitle: driver.fullName,
      accent: AdminFormTheme.driver.primary,
      icon: Icons.check_circle_outline,
      items: [
        AdminDialogSummaryItem(
          icon: Icons.badge_outlined,
          label: s.schoolTransportId,
          value: driver.driverId,
        ),
        AdminDialogSummaryItem(
          icon: Icons.qr_code_2_outlined,
          label: s.busLinkId,
          value: driver.busId,
        ),
        AdminDialogSummaryItem(
          icon: Icons.person_outline,
          label: s.fullName,
          value: driver.fullName,
        ),
        AdminDialogSummaryItem(
          icon: Icons.directions_bus_outlined,
          label: s.busNumber,
          value: driver.busNumber,
        ),
        AdminDialogSummaryItem(
          icon: Icons.route_outlined,
          label: s.routeName,
          value: driver.routeName,
        ),
        AdminDialogSummaryItem(
          icon: Icons.confirmation_number_outlined,
          label: s.plateNumber,
          value: driver.plateNumber,
        ),
        AdminDialogSummaryItem(
          icon: Icons.phone_android_outlined,
          label: s.loginUsername,
          value: loginKey,
        ),
        AdminDialogSummaryItem(
          icon: Icons.lock_outline,
          label: s.tempPassword,
          value: tempPassword,
        ),
      ],
      footnote: s.staffSavedSuccessfully,
      actions: [
        AdminDialogAction(
          label: s.done,
          primary: true,
          icon: Icons.check_rounded,
          onPressed: () {
            Navigator.pop(context);
            Navigator.pop(context);
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final theme = AdminFormTheme.driver;
        return AdminFormScaffold(
          title: s.addTransportStaff,
          subtitle: s.transportDetails,
          theme: theme,
          body: [
            AdminPhotoPicker(
              photo: _pickedPhoto,
              hint: s.driverPhotoHint,
              accent: theme.primary,
              onTap: _pickPhoto,
            ),
            const SizedBox(height: 20),
            AdminFormSection(
              title: s.fullName,
              icon: Icons.person_outline,
              color: theme.primary,
              children: [
                TextField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  inputFormatters: nameInputFormatters,
                  decoration: adminFieldDecoration(
                    label: s.fullName,
                    icon: Icons.badge_outlined,
                    accent: theme.primary,
                  ),
                ),
                PhoneContactField(
                  controller: _phone,
                  label: s.phoneNumber,
                  hint: s.phoneLoginHint,
                ),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: adminFieldDecoration(
                    label: s.email,
                    icon: Icons.email_outlined,
                    accent: theme.primary,
                  ),
                ),
              ],
            ),
            AdminFormSection(
              title: s.transportDetails,
              icon: Icons.directions_bus_outlined,
              color: theme.secondary,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: theme.secondary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.secondary.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    s.busLinkIdAutoHint,
                    style: TextStyle(
                      color: theme.secondary.withValues(alpha: 0.95),
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _busNumber,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.busNumber,
                    hint: s.busNumberHint,
                    icon: Icons.directions_bus,
                    accent: theme.secondary,
                  ),
                ),
                Text(
                  s.routePathHint,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _routeFrom,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.routeFrom,
                    hint: s.routeFromHint,
                    icon: Icons.trip_origin,
                    accent: theme.secondary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_downward_rounded, color: theme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        s.routeThrough,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _routeThrough,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.routeThrough,
                    hint: s.routeThroughHint,
                    icon: Icons.place_outlined,
                    accent: theme.secondary,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.arrow_downward_rounded, color: theme.secondary),
                      const SizedBox(width: 6),
                      Text(
                        s.routeTo,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
                TextField(
                  controller: _routeTo,
                  textCapitalization: TextCapitalization.words,
                  decoration: adminFieldDecoration(
                    label: s.routeTo,
                    hint: s.routeToHint,
                    icon: Icons.flag_outlined,
                    accent: theme.secondary,
                  ),
                ),
                TextField(
                  controller: _plateNumber,
                  textCapitalization: TextCapitalization.characters,
                  decoration: adminFieldDecoration(
                    label: s.plateNumber,
                    hint: s.plateNumberHint,
                    icon: Icons.confirmation_number_outlined,
                    accent: theme.secondary,
                  ),
                  onChanged: (v) {
                    final upper = v.toUpperCase();
                    if (upper != v) {
                      _plateNumber.value = TextEditingValue(
                        text: upper,
                        selection: TextSelection.collapsed(offset: upper.length),
                      );
                    }
                  },
                ),
              ],
            ),
            adminPrimaryButton(
              label: s.createDriverAccount,
              color: theme.primary,
              loading: _saving,
              onPressed: _saving ? null : _save,
            ),
          ],
        );
      },
    );
  }
}
