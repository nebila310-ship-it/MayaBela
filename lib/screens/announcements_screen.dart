import 'package:open_file/open_file.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_edit_dialog.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';
import 'package:mayabela/widgets/announcements_ui.dart';

class AnnouncementsScreen extends StatefulWidget {
  const AnnouncementsScreen({
    super.key,
    this.canCreate = false,
    this.authorName = 'Staff',
  });

  final bool canCreate;
  final String authorName;

  @override
  State<AnnouncementsScreen> createState() => _AnnouncementsScreenState();
}

class _AnnouncementsScreenState extends State<AnnouncementsScreen> {
  final _data = SchoolDataService.instance;

  @override
  void initState() {
    super.initState();
    SchoolContentSyncService.instance.addListener(_onCloudDataChanged);
  }

  @override
  void dispose() {
    SchoolContentSyncService.instance.removeListener(_onCloudDataChanged);
    super.dispose();
  }

  void _onCloudDataChanged() {
    if (mounted) setState(() {});
  }

  List<Announcement> get announcements {
    final role = AuthService.currentUser?.roleKey;
    return _data.getAnnouncementsForRole(role);
  }

  String _formatDate(DateTime date) =>
      '${date.day}/${date.month}/${date.year}';

  void _openDetail(Announcement announcement) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(announcement: announcement),
      ),
    );
  }

  Future<void> _createAnnouncement() async {
    final s = AppLocale.instance.strings;
    final draft = await Navigator.push<CreateAnnouncementDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAnnouncementScreen(authorName: widget.authorName),
      ),
    );

    if (draft == null) return;

    _data.addAnnouncement(
      title: draft.title,
      body: draft.body,
      author: widget.authorName,
      audienceKeys: draft.audienceKeys,
      priority: draft.priority,
      attachments: draft.attachments,
    );
    setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.announcementPublished),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final items = announcements;

        return Scaffold(
          backgroundColor: const Color(0xFFFFF7ED),
          appBar: AnnouncementsAppBar(title: s.announcementsTitle),
          floatingActionButton: widget.canCreate
              ? FloatingActionButton.extended(
                  onPressed: _createAnnouncement,
                  backgroundColor: AnnouncementsPalette.primary,
                  icon: const Icon(Icons.campaign_rounded),
                  label: Text(s.newShort),
                )
              : null,
          body: Container(
            decoration: BoxDecoration(gradient: AnnouncementsPalette.pageGradient),
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: AnnouncementsPalette.primary.withValues(alpha: 0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.campaign_outlined,
                              size: 48,
                              color: AnnouncementsPalette.primary,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            s.noAnnouncements,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 15,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: listPagePadding(context),
                    itemCount: items.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final item = items[index];
                      return AnnouncementCard(
                        announcement: item,
                        onTap: () => _openDetail(item),
                        audienceLabelBuilder: s.announcementAudienceKey,
                        dateLabel: _formatDate(item.date),
                      );
                    },
                  ),
          ),
        );
      },
    );
  }
}

class AnnouncementDetailScreen extends StatelessWidget {
  const AnnouncementDetailScreen({super.key, required this.announcement});

  final Announcement announcement;

  String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

  Future<void> _openAttachment(
    BuildContext context,
    AnnouncementAttachment attachment,
  ) async {
    final s = AppLocale.instance.strings;
    final result =
        await AnnouncementAttachmentService.instance.openAttachment(attachment);
    if (!context.mounted) return;
    if (result.type != ResultType.done) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.announcementAttachmentOpenFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final priority = AnnouncementPriorityStyle.forPriority(
          announcement.priority,
          s,
        );

        return Scaffold(
          backgroundColor: const Color(0xFFFFF7ED),
          appBar: AnnouncementsAppBar(title: s.announcement),
          body: Container(
            decoration: BoxDecoration(gradient: AnnouncementsPalette.pageGradient),
            child: SingleChildScrollView(
              padding: listPagePadding(context, horizontal: 20, top: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: priority.color.withValues(alpha: 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: priority.color.withValues(alpha: 0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: priority.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(priority.icon, color: priority.color),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    priority.label,
                                    style: TextStyle(
                                      color: priority.color,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  if (announcement.isPinned)
                                    Text(
                                      s.pinned,
                                      style: TextStyle(
                                        color: AnnouncementsPalette.primary,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          announcement.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final key in announcement.audienceKeys)
                              Chip(
                                label: Text(s.announcementAudienceKey(key)),
                                backgroundColor:
                                    AnnouncementsPalette.accent.withValues(alpha: 0.25),
                              ),
                            Chip(label: Text(announcement.author)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      announcement.body,
                      style: const TextStyle(fontSize: 16, height: 1.55),
                    ),
                  ),
                  if (announcement.attachments.isNotEmpty) ...[
                    const SizedBox(height: 18),
                    Text(
                      s.announcementAttachments,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...announcement.attachments.map(
                      (file) => AnnouncementAttachmentTile(
                        attachment: file,
                        onTap: () => _openAttachment(context, file),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Text(
                    s.postedOn(_formatDate(announcement.date)),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class CreateAnnouncementScreen extends StatefulWidget {
  const CreateAnnouncementScreen({super.key, required this.authorName});

  final String authorName;

  @override
  State<CreateAnnouncementScreen> createState() =>
      _CreateAnnouncementScreenState();
}

class _CreateAnnouncementScreenState extends State<CreateAnnouncementScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  final _attachments = <AnnouncementAttachment>[];
  late final Set<String> _audiences = _defaultAudiences();
  AnnouncementPriority _priority = AnnouncementPriority.normal;
  String _error = '';
  bool _pickingFile = false;

  static Set<String> _defaultAudiences() {
    final role = AuthService.currentUser?.roleKey;
    if (role == AuthService.roleAdmin) {
      return {
        AnnouncementAudiences.all,
        AnnouncementAudiences.parents,
        AnnouncementAudiences.teachers,
        AnnouncementAudiences.students,
        AnnouncementAudiences.admin,
      };
    }
    if (role == AuthService.roleTeacher) {
      final homeroomClasses = TeacherAccessService.instance.homeroomClassNames;
      if (homeroomClasses.isNotEmpty) {
        return {
          AnnouncementAudiences.students,
          ...homeroomClasses,
        };
      }
    }
    return {AnnouncementAudiences.parents};
  }

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _pickAttachments() async {
    setState(() => _pickingFile = true);
    final picked =
        await AnnouncementAttachmentService.instance.pickAndSaveFiles();
    if (!mounted) return;
    setState(() {
      _pickingFile = false;
      _attachments.addAll(picked);
    });
  }

  void _removeAttachment(AnnouncementAttachment attachment) {
    setState(() {
      _attachments.removeWhere((a) => a.id == attachment.id);
    });
  }

  Future<void> _publish() async {
    final s = AppLocale.instance.strings;
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = s.titleMessageRequired);
      return;
    }
    if (_audiences.isEmpty) {
      setState(() => _error = s.announcementAudienceRequired);
      return;
    }

    final draft = CreateAnnouncementDraft(
      title: _title.text.trim(),
      body: _body.text.trim(),
      audienceKeys: _audiences.toList(),
      priority: _priority,
      attachments: List.unmodifiable(_attachments),
    );

    if (!mounted) return;
    Navigator.pop(context, draft);
  }

  Future<void> _publishWithDialog() async {
    final s = AppLocale.instance.strings;
    if (_title.text.trim().isEmpty || _body.text.trim().isEmpty) {
      setState(() => _error = s.titleMessageRequired);
      return;
    }
    if (_audiences.isEmpty) {
      setState(() => _error = s.announcementAudienceRequired);
      return;
    }

    final confirmed = await showAdminFormDialog(
      context: context,
      title: s.publishAnnouncementFull,
      subtitle: _title.text.trim(),
      accent: AnnouncementsPalette.primary,
      icon: Icons.campaign_rounded,
      saveLabel: s.publish,
      builder: (ctx, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AdminFormDialogSection(
            title: s.audience,
            icon: Icons.groups_outlined,
            color: AnnouncementsPalette.secondary,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _audiences
                    .map(
                      (key) => Chip(
                        label: Text(s.announcementAudienceKey(key)),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          AdminFormDialogSection(
            title: s.announcementPriority,
            icon: Icons.flag_outlined,
            color: AnnouncementsPalette.primary,
            children: [
              Text(
                AnnouncementPriorityStyle.forPriority(_priority, s).label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          if (_attachments.isNotEmpty)
            AdminFormDialogSection(
              title: s.announcementAttachments,
              icon: Icons.attach_file_rounded,
              color: AnnouncementsPalette.deep,
              children: [
                Text(
                  s.announcementAttachmentCount(_attachments.length),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );

    if (confirmed) await _publish();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return Scaffold(
          backgroundColor: const Color(0xFFFFF7ED),
          appBar: AnnouncementsAppBar(title: s.newAnnouncement),
          body: Container(
            decoration: BoxDecoration(gradient: AnnouncementsPalette.pageGradient),
            child: SingleChildScrollView(
              padding: listPagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: AnnouncementsPalette.accent.withValues(alpha: 0.4),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AnnouncementsPalette.primary.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _title,
                          decoration: adminFieldDecoration(
                            label: s.titleLabel,
                            icon: Icons.title_rounded,
                            accent: AnnouncementsPalette.primary,
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.announcementPriority,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        AnnouncementPriorityPicker(
                          selected: _priority,
                          onChanged: (value) =>
                              setState(() => _priority = value),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          s.audience,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.announcementAudienceHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        AnnouncementAudiencePicker(
                          selected: _audiences,
                          onChanged: (value) => setState(() {
                            _audiences
                              ..clear()
                              ..addAll(value);
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _body,
                          maxLines: 8,
                          decoration: adminFieldDecoration(
                            label: s.messageLabel,
                            icon: Icons.notes_rounded,
                            accent: AnnouncementsPalette.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: AnnouncementsPalette.accent.withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.attach_file_rounded,
                              color: AnnouncementsPalette.deep,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.announcementAttachments,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.announcementAttachmentHint,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickingFile ? null : _pickAttachments,
                          icon: _pickingFile
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.upload_file_rounded),
                          label: Text(s.announcementAddAttachment),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AnnouncementsPalette.deep,
                            side: BorderSide(
                              color: AnnouncementsPalette.primary.withValues(alpha: 0.35),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        if (_attachments.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          ..._attachments.map(
                            (file) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: const Icon(Icons.insert_drive_file_outlined),
                              title: Text(
                                file.fileName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: Text(
                                AnnouncementAttachmentService.instance
                                    .formatFileSize(file.fileSizeBytes),
                              ),
                              trailing: IconButton(
                                icon: const Icon(Icons.close_rounded),
                                onPressed: () => _removeAttachment(file),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (_error.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text(_error, style: const TextStyle(color: Colors.red)),
                  ],
                  const SizedBox(height: 16),
                  adminPrimaryButton(
                    label: s.publishAnnouncementFull,
                    color: AnnouncementsPalette.primary,
                    onPressed: _publishWithDialog,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
