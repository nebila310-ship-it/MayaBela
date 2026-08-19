import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/driver_registry_service.dart';
import 'package:mayabela/services/parent_invite_service.dart';
import 'package:mayabela/services/parent_transport_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/parent_child_picker.dart';

/// Parent-facing card to link a child to their school bus via Bus Link ID.
class ParentBusLinkCard extends StatefulWidget {
  const ParentBusLinkCard({
    super.key,
    required this.studentId,
    required this.childName,
    this.onLinked,
  });

  final String studentId;
  final String childName;
  final VoidCallback? onLinked;

  @override
  State<ParentBusLinkCard> createState() => _ParentBusLinkCardState();
}

class _ParentBusLinkCardState extends State<ParentBusLinkCard> {
  final _busIdCtrl = TextEditingController();
  bool _saving = false;
  bool _lookupOk = false;
  String? _lookupMessage;
  AdminDriverRecord? _previewDriver;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void initState() {
    super.initState();
    _busIdCtrl.addListener(_onBusIdChanged);
    final linked = ParentTransportService.instance
        .linkedDriverForStudent(widget.studentId);
    if (linked != null) {
      _busIdCtrl.text = linked.busId;
      _applyPreview(linked);
    }
  }

  @override
  void dispose() {
    _busIdCtrl.removeListener(_onBusIdChanged);
    _busIdCtrl.dispose();
    super.dispose();
  }

  void _onBusIdChanged() => _lookupBus(silent: true);

  void _applyPreview(AdminDriverRecord driver) {
    setState(() {
      _previewDriver = driver;
      _lookupOk = true;
      _lookupMessage = s.transportBusRegisteredLabel(
        driver.busId,
        driver.busNumber,
        driver.fullName,
      );
    });
  }

  void _lookupBus({bool silent = false}) {
    final id = _busIdCtrl.text.trim().toUpperCase();
    if (id.isEmpty) {
      setState(() {
        _previewDriver = null;
        _lookupOk = false;
        _lookupMessage = null;
      });
      return;
    }

    final schoolId =
        AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId;
    final validation = ParentInviteService.instance.validateTransportId(
      id,
      schoolId: schoolId,
    );

    if (validation != null) {
      setState(() {
        _previewDriver = null;
        _lookupOk = false;
        _lookupMessage = validation == 'wrong_school'
            ? s.transportIdWrongSchool
            : s.transportBusNotRegisteredWithId(id);
      });
      return;
    }

    final driver = DriverRegistryService.instance.resolveTransportReference(id);
    if (driver == null) {
      setState(() {
        _previewDriver = null;
        _lookupOk = false;
        _lookupMessage = s.transportBusNotRegisteredWithId(id);
      });
      return;
    }

    if (!silent) {
      _applyPreview(driver);
    } else {
      setState(() {
        _previewDriver = driver;
        _lookupOk = true;
        _lookupMessage = s.transportBusRegisteredLabel(
          driver.busId,
          driver.busNumber,
          driver.fullName,
        );
      });
    }
  }

  Future<void> _saveLink() async {
    if (_saving) return;
    _lookupBus();
    if (!_lookupOk) return;

    setState(() => _saving = true);
    final result = ParentTransportService.instance.linkStudentToBus(
      studentId: widget.studentId,
      busLinkId: _busIdCtrl.text.trim(),
    );
    if (!mounted) return;
    setState(() => _saving = false);

    if (!result.ok) {
      final message = switch (result.error) {
        ParentTransportLinkError.wrongSchool => s.transportIdWrongSchool,
        ParentTransportLinkError.accessDenied => s.parentBusLinkAccessDenied,
        ParentTransportLinkError.studentNotFound => s.inviteParentNoRecord,
        _ => s.transportBusNotRegisteredWithId(
            _busIdCtrl.text.trim().toUpperCase(),
          ),
      };
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
      return;
    }

    widget.onLinked?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.parentBusLinkedSuccess(widget.childName))),
    );
    setState(() {});
  }

  Future<void> _unlink() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.parentUnlinkBusTitle),
        content: Text(s.parentUnlinkBusMessage(widget.childName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.parentUnlinkBusConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    final error = ParentTransportService.instance.unlinkStudentFromBus(
      studentId: widget.studentId,
    );
    if (!mounted) return;

    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.parentBusLinkAccessDenied)),
      );
      return;
    }

    _busIdCtrl.clear();
    setState(() {
      _previewDriver = null;
      _lookupOk = false;
      _lookupMessage = null;
    });
    widget.onLinked?.call();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.parentBusUnlinkedSuccess)),
    );
  }

  List<AdminDriverRecord> get _schoolBuses {
    final schoolId =
        AuthService.activeSchoolId ?? AuthService.currentUser?.schoolId;
    return DriverRegistryService.instance
        .driversForSchool(schoolId)
        .where((d) => d.isActive && d.busNumber.trim().isNotEmpty)
        .toList()
      ..sort((a, b) => a.busId.compareTo(b.busId));
  }

  @override
  Widget build(BuildContext context) {
    final linked = ParentTransportService.instance
        .linkedDriverForStudent(widget.studentId);
    final isLinked = linked != null;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLinked
              ? Colors.blue.withValues(alpha: 0.25)
              : ParentChildPalette.secondary.withValues(alpha: 0.25),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.directions_bus_rounded, color: Colors.blue),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.parentBusLinkTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isLinked ? s.transportWired : s.parentBusLinkSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (linked != null) ...[
            const SizedBox(height: 14),
            _LinkedBusSummary(driver: linked),
          ],
          const SizedBox(height: 14),
          Text(
            s.parentBusLinkIdLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          if (_schoolBuses.isNotEmpty) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _schoolBuses.map((driver) {
                final selected = _previewDriver?.busId == driver.busId;
                return FilterChip(
                  label: Text('${driver.busId} · ${driver.busNumber}'),
                  selected: selected,
                  onSelected: (_) {
                    _busIdCtrl.text = driver.busId;
                    _applyPreview(driver);
                  },
                  selectedColor: ParentChildPalette.primary.withValues(alpha: 0.18),
                  checkmarkColor: ParentChildPalette.primary,
                );
              }).toList(),
            ),
            const SizedBox(height: 10),
          ],
          TextField(
            controller: _busIdCtrl,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: s.busLinkId,
              hintText: s.busLinkIdStudentHint,
              prefixIcon: const Icon(Icons.qr_code_2_outlined),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              filled: true,
              fillColor: ParentChildPalette.surface,
            ),
            onSubmitted: (_) => _lookupBus(),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _lookupBus(),
              icon: const Icon(Icons.search),
              label: Text(s.lookupBus),
            ),
          ),
          if (_lookupMessage != null)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _lookupOk ? Colors.green.shade50 : Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _lookupOk ? Colors.green.shade200 : Colors.red.shade200,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _lookupOk ? Icons.check_circle : Icons.error_outline,
                    color: _lookupOk ? Colors.green : Colors.red,
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_lookupMessage!)),
                ],
              ),
            ),
          FilledButton.icon(
            onPressed: _saving || !_lookupOk ? null : _saveLink,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.link_rounded),
            label: Text(isLinked ? s.parentBusLinkUpdate : s.parentBusLinkSave),
            style: FilledButton.styleFrom(
              backgroundColor: ParentChildPalette.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          if (isLinked) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: _unlink,
              child: Text(s.parentUnlinkBusConfirm),
            ),
          ],
        ],
      ),
    );
  }
}

class _LinkedBusSummary extends StatelessWidget {
  const _LinkedBusSummary({required this.driver});

  final AdminDriverRecord driver;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${driver.busNumber} · ${driver.routeName}',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            s.parentBusLinkedDriver(driver.fullName, driver.busId),
            style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

/// Full screen for parents to configure / update the bus link for a child.
class ParentBusLinkScreen extends StatelessWidget {
  const ParentBusLinkScreen({
    super.key,
    required this.studentId,
    required this.childName,
  });

  final String studentId;
  final String childName;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: ParentChildPalette.surface,
          appBar: AppBar(
            backgroundColor: ParentChildPalette.primary,
            foregroundColor: Colors.white,
            title: Text(s.schoolBusTool),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              Text(
                childName,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                s.parentBusLinkSubtitle,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ParentBusLinkCard(
                key: ValueKey('bus-link-$studentId'),
                studentId: studentId,
                childName: childName,
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Bottom sheet shortcut when parent taps bus tracking without a link.
Future<void> showParentLinkBusSheet({
  required BuildContext context,
  required String studentId,
  required String childName,
  VoidCallback? onLinked,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) {
      return Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 8,
          bottom: MediaQuery.viewInsetsOf(ctx).bottom + 24,
        ),
        child: SingleChildScrollView(
          child: ParentBusLinkCard(
            studentId: studentId,
            childName: childName,
            onLinked: () {
              onLinked?.call();
              Navigator.pop(ctx);
            },
          ),
        ),
      );
    },
  );
}
