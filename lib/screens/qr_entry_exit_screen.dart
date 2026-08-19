import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/calendar_event.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/scan_feedback_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/advanced_qr_scanner_shell.dart';
import 'package:mayabela/widgets/qr_scanner_theme.dart';
import 'package:mayabela/widgets/student_qr_card.dart';

enum QrScreenRole { teacher, driver, parent }

class QrEntryExitScreen extends StatefulWidget {
  const QrEntryExitScreen({
    super.key,
    required this.role,
    this.scopedClassName,
  });

  final QrScreenRole role;
  final String? scopedClassName;

  @override
  State<QrEntryExitScreen> createState() => _QrEntryExitScreenState();
}

class _QrEntryExitScreenState extends State<QrEntryExitScreen>
    with SingleTickerProviderStateMixin {
  final _data = SchoolDataService.instance;
  late TabController _tabs;
  QrScanAction _action = QrScanAction.present;
  String? _lastMessage;
  bool _lastSuccess = false;
  String? _selectedManualStudentId;

  String get _scannedBy {
    switch (widget.role) {
      case QrScreenRole.teacher:
        return AuthService.displayNameForRole(AuthService.roleTeacher);
      case QrScreenRole.driver:
        return AuthService.displayNameForRole(AuthService.roleDriver);
      case QrScreenRole.parent:
        return AuthService.displayNameForRole(AuthService.roleParent);
    }
  }

  List<StudentQrProfile> get _scannableStudents {
    final scoped = widget.scopedClassName?.trim();
    if (scoped != null && scoped.isNotEmpty) {
      return _data.getStudentQrProfilesForClass(scoped);
    }
    return _data.getAllStudentQrProfiles();
  }

  List<QrScanRecord> get _visibleHistory {
    final scoped = widget.scopedClassName?.trim();
    final history = _data.getQrScanHistory();
    if (scoped == null || scoped.isEmpty) return history;
    return history.where((record) => record.className == scoped).toList();
  }

  @override
  void initState() {
    super.initState();
    _tabs = TabController(
      length: widget.role == QrScreenRole.parent ? 1 : 2,
      vsync: this,
    );
    if (_scannableStudents.isNotEmpty) {      _selectedManualStudentId = _scannableStudents.first.id;
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }
  void _handleScan(String code) {
    final s = AppLocale.instance.strings;
    final syncAttendance = widget.role == QrScreenRole.teacher;
    final error = _data.recordQrScan(
      qrCode: code,
      action: _action,
      scannedBy: _scannedBy,
      allowedClassName: widget.scopedClassName,
      syncAttendance: syncAttendance,
    );

    if (error != null) {
      setState(() {
        if (error.startsWith('wrong_class:')) {
          final className = error.substring('wrong_class:'.length);
          _lastMessage = s.qrWrongClassError(className);
        } else {
          _lastMessage = error;
        }
        _lastSuccess = false;
      });
      return;
    }

    ScanFeedbackService.instance.playScanSuccess();
    setState(() {
        final student = _data.findStudentByQrCode(code);
        if (student == null) {
          _lastMessage = s.scanSuccess;
        } else if (syncAttendance) {
          _lastMessage = s.qrAttendanceMarked(
            student.name,
            _teacherStatusLabel(s, _action),
          );
        } else {
          final actionLabel =
              _action == QrScanAction.entry ? s.entry : s.exit;
          _lastMessage = s.scanRecordedFor(student.name, actionLabel);
        }
        _lastSuccess = true;
    });
  }

  String _teacherStatusLabel(AppStrings s, QrScanAction action) {
    switch (action) {
      case QrScanAction.present:
      case QrScanAction.entry:
        return s.present;
      case QrScanAction.late:
        return s.late;
      case QrScanAction.absent:
      case QrScanAction.exit:
        return s.absent;
    }
  }

  int _teacherModeIndex(QrScanAction action) {
    switch (action) {
      case QrScanAction.present:
      case QrScanAction.entry:
        return 0;
      case QrScanAction.late:
        return 1;
      case QrScanAction.absent:
      case QrScanAction.exit:
        return 2;
    }
  }

  QrScanAction _teacherActionFromIndex(int index) {
    switch (index) {
      case 0:
        return QrScanAction.present;
      case 1:
        return QrScanAction.late;
      case 2:
        return QrScanAction.absent;
      default:
        return QrScanAction.present;
    }
  }

  Color _teacherStatusColor(QrScanAction action) {
    switch (action) {
      case QrScanAction.present:
      case QrScanAction.entry:
        return Colors.green;
      case QrScanAction.late:
        return Colors.orange;
      case QrScanAction.absent:
      case QrScanAction.exit:
        return Colors.red;
    }
  }

  IconData _teacherStatusIcon(QrScanAction action) {
    switch (action) {
      case QrScanAction.present:
      case QrScanAction.entry:
        return Icons.check;
      case QrScanAction.late:
        return Icons.schedule;
      case QrScanAction.absent:
      case QrScanAction.exit:
        return Icons.close;
    }
  }

  void _manualScan() {
    final student = _scannableStudents.firstWhere(
      (s) => s.id == _selectedManualStudentId,
    );
    _handleScan(student.qrCode);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.role == QrScreenRole.parent) {
      return _buildParentView();
    }

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFEEF2FF),
          appBar: AdvancedQrScannerAppBar(
            title: s.qrEntryExit,
            subtitle: widget.scopedClassName != null
                ? s.qrScopedToClass(widget.scopedClassName!)
                : null,
            theme: QrScannerTheme.attendance,
            bottom: TabBar(
              controller: _tabs,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              indicatorColor: Colors.white,
              tabs: [
                Tab(
                  text: s.scannerTab,
                  icon: const Icon(Icons.qr_code_scanner),
                ),
                Tab(text: s.historyTab, icon: const Icon(Icons.history)),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _KeepAliveTab(child: _buildScannerTab(s)),
              _buildHistoryTab(s),
            ],
          ),
        );
      },
    );
  }

  Widget _buildParentView() {
    final profiles = _data.getStudentQrProfilesForParent();

    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: Colors.black87,
            title: Text(s.studentQrCodes),
          ),
          body: ListView(
            padding: listPagePadding(context),
            children: [
              Text(
                s.showQrAtGate,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ...profiles.map((profile) => StudentQrCard(profile: profile)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildScannerTab(AppStrings s) {
    final students = _scannableStudents;
    final theme = QrScannerTheme.attendance;
    final isTeacher = widget.role == QrScreenRole.teacher;
    final modeIndex = isTeacher
        ? _teacherModeIndex(_action)
        : (_action == QrScanAction.entry ? 0 : 1);

    if (students.isEmpty) {
      return Center(
        child: Padding(
          padding: listPagePadding(context),
          child: Text(
            widget.scopedClassName == null
                ? s.noStudentsInClass
                : s.noStudentsInClassNamed(widget.scopedClassName!),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return AdvancedQrScannerShell(
      theme: theme,
      title: s.scannerTab,
      subtitle: s.qrScannerAlignHint,
      bannerText: widget.scopedClassName,
      modeOptions: isTeacher
          ? [
              QrScannerModeOption(
                label: s.present,
                icon: Icons.check,
                activeColor: Colors.green.shade700,
              ),
              QrScannerModeOption(
                label: s.late,
                icon: Icons.schedule,
                activeColor: Colors.orange.shade700,
              ),
              QrScannerModeOption(
                label: s.absent,
                icon: Icons.close,
                activeColor: Colors.red.shade700,
              ),
            ]
          : [
              QrScannerModeOption(
                label: s.entry,
                icon: Icons.login_rounded,
                activeColor: const Color(0xFF059669),
              ),
              QrScannerModeOption(
                label: s.exit,
                icon: Icons.logout_rounded,
                activeColor: const Color(0xFFEA580C),
              ),
            ],
      selectedModeIndex: modeIndex,
      onModeSelected: (index) {
        setState(() {
          _action = isTeacher
              ? _teacherActionFromIndex(index)
              : (index == 0 ? QrScanAction.entry : QrScanAction.exit);
          _lastMessage = null;
        });
      },
      onCode: _handleScan,
      statusMessage: _lastMessage,
      statusSuccess: _lastSuccess,
      unavailableMessage: s.cameraScannerAvailable,
      errorMessage: s.qrScannerStartError,
      permissionDeniedMessage: s.cameraPermissionRequired,
      startingMessage: s.cameraStarting,
      retryLabel: s.tryAgain,
      bottomChild: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.manualCheckIn,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            key: ValueKey(_selectedManualStudentId),
            initialValue: _selectedManualStudentId,
            decoration: InputDecoration(
              labelText: s.selectStudent,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            items: students
                .map(
                  (student) => DropdownMenuItem(
                    value: student.id,
                    child: Text('${student.name} (${student.className})'),
                  ),
                )
                .toList(),
            onChanged: (value) =>
                setState(() => _selectedManualStudentId = value),
          ),
          const SizedBox(height: 10),
          FilledButton.icon(
            onPressed: _manualScan,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              s.recordAction(
                isTeacher
                    ? _teacherStatusLabel(s, _action)
                    : (modeIndex == 0 ? s.entry : s.exit),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: theme.primary,
              minimumSize: const Size.fromHeight(48),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryTab(AppStrings s) {
    final history = _visibleHistory;

    if (history.isEmpty) {
      return Center(child: Text(s.noScansYet));
    }

    return ListView.separated(
      padding: listPagePadding(context),
      itemCount: history.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final record = history[index];
        final actionLabel = widget.role == QrScreenRole.teacher
            ? _teacherStatusLabel(s, record.action)
            : (record.action == QrScanAction.entry ? s.entry : s.exit);
        final statusColor = widget.role == QrScreenRole.teacher
            ? _teacherStatusColor(record.action)
            : (record.action == QrScanAction.entry ? Colors.green : Colors.orange);
        final statusIcon = widget.role == QrScreenRole.teacher
            ? _teacherStatusIcon(record.action)
            : (record.action == QrScanAction.entry ? Icons.login : Icons.logout);

        return ListTile(
          leading: CircleAvatar(
            backgroundColor: statusColor.withValues(alpha: 0.15),
            child: Icon(statusIcon, color: statusColor),
          ),
          title: Text(record.studentName),
          subtitle: Text(
            '${record.className} · $actionLabel · ${record.scannedBy}',
          ),
          trailing: Text(
            _formatTime(record.time),
            style: const TextStyle(fontSize: 12),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}

class _KeepAliveTab extends StatefulWidget {
  const _KeepAliveTab({required this.child});

  final Widget child;

  @override
  State<_KeepAliveTab> createState() => _KeepAliveTabState();
}

class _KeepAliveTabState extends State<_KeepAliveTab>
    with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return widget.child;
  }
}
