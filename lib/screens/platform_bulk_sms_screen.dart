import 'package:flutter/material.dart';
import 'package:mayabela/services/platform_bulk_sms_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';

class PlatformBulkSmsScreen extends StatefulWidget {
  const PlatformBulkSmsScreen({
    super.key,
    required this.initialSchools,
  });

  final List<SchoolRecord> initialSchools;

  @override
  State<PlatformBulkSmsScreen> createState() => _PlatformBulkSmsScreenState();
}

class _PlatformBulkSmsScreenState extends State<PlatformBulkSmsScreen> {
  final _customController = TextEditingController();
  BulkSmsTemplate _template = BulkSmsTemplate.expiryReminder;
  final Set<String> _selectedIds = {};
  bool _sending = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    for (final s in widget.initialSchools) {
      _selectedIds.add(s.id);
    }
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  List<SchoolRecord> get _selectedSchools => widget.initialSchools
      .where((s) => _selectedIds.contains(s.id))
      .toList();

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _message = null;
    });

    final recipients = PlatformBulkSmsService.instance.buildRecipients(
      schools: _selectedSchools,
      template: _template,
      customBody: _customController.text,
    );

    if (recipients.isEmpty) {
      setState(() {
        _sending = false;
        _message = 'No admin phones for selected schools.';
      });
      return;
    }

    final ok = await PlatformBulkSmsService.instance.sendViaSms(
      recipients: recipients,
    );

    if (!mounted) return;
    setState(() {
      _sending = false;
      _message = ok
          ? 'Opened SMS for ${recipients.length} admin(s).'
          : 'Could not open SMS app.';
    });
  }

  @override
  Widget build(BuildContext context) {
    final preview = _selectedSchools.isEmpty
        ? null
        : PlatformBulkSmsService.instance
            .buildRecipients(
              schools: [_selectedSchools.first],
              template: _template,
              customBody: _customController.text,
            )
            .firstOrNull
            ?.message;

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Bulk SMS'),
      ),
      body: ListView(
        padding: listPagePadding(context),
        children: [
          const Text(
            'Message template',
            style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          RadioGroup<BulkSmsTemplate>(
            groupValue: _template,
            onChanged: (value) {
              if (value == null) return;
              setState(() => _template = value);
            },
            child: Column(
              children: BulkSmsTemplate.values
                  .map(
                    (t) => RadioListTile<BulkSmsTemplate>(
                      value: t,
                      title: Text(
                        t.label,
                        style: const TextStyle(color: Colors.white),
                      ),
                      activeColor: Colors.tealAccent,
                      tileColor: const Color(0xFF1E293B),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          if (_template == BulkSmsTemplate.custom) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _customController,
              maxLines: 3,
              style: const TextStyle(color: Colors.white),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Type your message…',
                hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4)),
                filled: true,
                fillColor: const Color(0xFF1E293B),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
          if (preview != null) ...[
            const SizedBox(height: 12),
            const Text(
              'Preview',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 4),
            Text(
              preview,
              style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recipients',
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton(
                onPressed: () => setState(() {
                  if (_selectedIds.length == widget.initialSchools.length) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds
                      ..clear()
                      ..addAll(widget.initialSchools.map((s) => s.id));
                  }
                }),
                child: Text(
                  _selectedIds.length == widget.initialSchools.length
                      ? 'Clear all'
                      : 'Select all',
                ),
              ),
            ],
          ),
          ...widget.initialSchools.map((school) {
            final phone = PlatformBulkSmsService.instance.buildRecipients(
              schools: [school],
              template: _template,
            );
            final hasPhone = phone.isNotEmpty;
            return CheckboxListTile(
              value: _selectedIds.contains(school.id),
              onChanged: hasPhone
                  ? (v) => setState(() {
                        if (v == true) {
                          _selectedIds.add(school.id);
                        } else {
                          _selectedIds.remove(school.id);
                        }
                      })
                  : null,
              title: Text(
                school.name,
                style: TextStyle(
                  color: hasPhone ? Colors.white : Colors.white38,
                  fontWeight: FontWeight.w600,
                ),
              ),
              subtitle: Text(
                hasPhone
                    ? '${school.id} · ${phone.first.phone}'
                    : '${school.id} · no admin phone',
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
              activeColor: Colors.tealAccent,
              tileColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            );
          }),
          if (_message != null) ...[
            const SizedBox(height: 8),
            Text(
              _message!,
              style: TextStyle(
                color: _message!.startsWith('Opened')
                    ? Colors.greenAccent
                    : Colors.orangeAccent,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _sending || _selectedIds.isEmpty ? null : _send,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.sms_outlined),
            label: Text('Send SMS to ${_selectedIds.length} admin(s)'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.teal.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

extension _FirstOrNull<E> on List<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
