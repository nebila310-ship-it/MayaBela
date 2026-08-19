import 'package:flutter/material.dart';
import 'package:mayabela/models/platform_audit_entry.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class PlatformAuditLogScreen extends StatefulWidget {
  const PlatformAuditLogScreen({super.key});

  @override
  State<PlatformAuditLogScreen> createState() => _PlatformAuditLogScreenState();
}

class _PlatformAuditLogScreenState extends State<PlatformAuditLogScreen> {
  List<PlatformAuditEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    await PlatformAuditLogService.instance.load();
    if (!mounted) return;
    setState(() => _entries = PlatformAuditLogService.instance.recent());
  }

  String _formatTime(DateTime dt) {
    final d = '${dt.day}/${dt.month}/${dt.year}';
    final t =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$d · $t';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Audit log'),
      ),
      body: _entries.isEmpty
          ? const Center(
              child: Text(
                'No owner actions logged yet.',
                style: TextStyle(color: Colors.white54),
              ),
            )
          : ListView.separated(
              padding: listPagePadding(context),
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final e = _entries[index];
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              e.actionLabel,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            _formatTime(e.at),
                            style: const TextStyle(color: Colors.white38, fontSize: 11),
                          ),
                        ],
                      ),
                      if (e.schoolName != null || e.schoolId != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          [
                            if (e.schoolName != null) e.schoolName,
                            if (e.schoolId != null) '(${e.schoolId})',
                          ].join(' '),
                          style: const TextStyle(color: Colors.white54, fontSize: 13),
                        ),
                      ],
                      if (e.detail != null && e.detail!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          e.detail!,
                          style: const TextStyle(color: Colors.white38, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}
