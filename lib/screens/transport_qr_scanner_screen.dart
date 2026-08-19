import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/transport_passenger.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/bus_live_location_service.dart';
import 'package:mayabela/services/student_registry_service.dart';
import 'package:mayabela/services/transport_service.dart';
import 'package:mayabela/services/scan_feedback_service.dart';
import 'package:mayabela/widgets/advanced_qr_scanner_shell.dart';
import 'package:mayabela/widgets/qr_scanner_theme.dart';

class TransportQrScannerScreen extends StatefulWidget {
  const TransportQrScannerScreen({
    super.key,
    required this.driverId,
    this.initialMode = TransportScanMode.onboard,
  });

  final String driverId;
  final TransportScanMode initialMode;

  @override
  State<TransportQrScannerScreen> createState() =>
      _TransportQrScannerScreenState();
}

class _TransportQrScannerScreenState extends State<TransportQrScannerScreen> {
  final _transport = TransportService.instance;
  late TransportScanMode _mode;
  String? _message;
  bool _success = false;

  @override
  void initState() {
    super.initState();
    _mode = widget.initialMode;
    BusLiveLocationService.instance.startSharing(widget.driverId);
  }

  String get _scannedBy =>
      AuthService.displayNameForRole(AuthService.roleDriver);

  void _handleCode(String code) {
    final error = _transport.recordTransportScan(
      driverId: widget.driverId,
      qrCode: code,
      mode: _mode,
      scannedBy: _scannedBy,
    );

    if (!mounted) return;
    final s = AppLocale.instance.strings;
    final studentId =
        _transport.resolveStudentIdFromQr(code, driverId: widget.driverId);
    final studentName = studentId == null
        ? null
        : StudentRegistryService.instance.lookupById(studentId)?.fullName;

    if (error != null) {
      setState(() {
        _message = error;
        _success = false;
      });
      return;
    }

    ScanFeedbackService.instance.playScanSuccess();
    setState(() {
        final action = _mode == TransportScanMode.onboard
            ? s.transportOnboard
            : s.transportDischarge;
        _message = studentName == null
            ? (_mode == TransportScanMode.onboard
                ? s.transportOnboardRecorded
                : s.transportDischargeRecorded)
            : s.transportStudentAction(studentName, action);
        _success = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final driver = _transport.driverForId(widget.driverId);
    final onboardCount = _transport
        .passengersForDriver(widget.driverId)
        .where((p) => p.isOnboard)
        .length;

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final theme = QrScannerTheme.transport;
        final modeIndex =
            _mode == TransportScanMode.onboard ? 0 : 1;

        return Scaffold(
          backgroundColor: const Color(0xFFF0FDFA),
          appBar: AdvancedQrScannerAppBar(
            title: s.scanQr,
            subtitle: driver == null
                ? null
                : '${driver.busNumber} · ${driver.routeName}',
            theme: theme,
          ),
          body: AdvancedQrScannerShell(
            theme: theme,
            title: s.scanStudentQr,
            subtitle: s.qrScannerAlignHint,
            bannerText: driver == null
                ? null
                : '${driver.busNumber} · $onboardCount ${s.transportOnboard.toLowerCase()}',
            modeOptions: [
              QrScannerModeOption(
                label: s.transportOnboard,
                icon: Icons.login_rounded,
                activeColor: const Color(0xFF059669),
              ),
              QrScannerModeOption(
                label: s.transportDischarge,
                icon: Icons.logout_rounded,
                activeColor: const Color(0xFFEA580C),
              ),
            ],
            selectedModeIndex: modeIndex,
            onModeSelected: (index) {
              setState(() {
                _mode = index == 0
                    ? TransportScanMode.onboard
                    : TransportScanMode.discharge;
                _message = null;
              });
            },
            onCode: _handleCode,
            statusMessage: _message,
            statusSuccess: _success,
            unavailableMessage: s.cameraScannerAvailable,
            errorMessage: s.qrScannerStartError,
            permissionDeniedMessage: s.cameraPermissionRequired,
            startingMessage: s.cameraStarting,
            retryLabel: s.tryAgain,
            bottomChild: !_canScan
                ? _ManualPassengerPicker(
                    driverId: widget.driverId,
                    mode: _mode,
                    onSelected: _handleCode,
                  )
                : null,
          ),
        );
      },
    );
  }

  bool get _canScan {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS;
  }
}

class _ManualPassengerPicker extends StatelessWidget {
  const _ManualPassengerPicker({
    required this.driverId,
    required this.mode,
    required this.onSelected,
  });

  final String driverId;
  final TransportScanMode mode;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final passengers = TransportService.instance.passengersForDriver(driverId);
    if (passengers.isEmpty) {
      return Text(
        AppLocale.instance.strings.transportNoPassengers,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.blueGrey.shade600),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DropdownButtonFormField<String>(
          decoration: InputDecoration(
            labelText: AppLocale.instance.strings.fullName,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: passengers
              .map(
                (p) => DropdownMenuItem(
                  value: p.qrCode,
                  child: Text(p.fullName),
                ),
              )
              .toList(),
          onChanged: (code) {
            if (code != null) onSelected(code);
          },
        ),
      ),
    );
  }
}
