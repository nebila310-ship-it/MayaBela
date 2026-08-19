import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/screens/announcements_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/widgets/announcements_ui.dart';

/// Web ERP announcements — scrollable list with create & publish.
class WebAnnouncementsPage extends StatefulWidget {
  const WebAnnouncementsPage({super.key});

  @override
  State<WebAnnouncementsPage> createState() => _WebAnnouncementsPageState();
}

class _WebAnnouncementsPageState extends State<WebAnnouncementsPage> {
  final _data = SchoolDataService.instance;
  final _authorName = AuthService.displayNameForRole(AuthService.roleAdmin);

  @override
  void initState() {
    super.initState();
    SchoolContentSyncService.instance.addListener(_refresh);
  }

  @override
  void dispose() {
    SchoolContentSyncService.instance.removeListener(_refresh);
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  List<Announcement> get _items {
    return _data.getAnnouncementsForRole(AuthService.roleAdmin);
  }

  Future<void> _create() async {
    final s = AppLocale.instance.strings;
    final draft = await Navigator.push<CreateAnnouncementDraft>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateAnnouncementScreen(authorName: _authorName),
      ),
    );
    if (draft == null || !mounted) return;

    _data.addAnnouncement(
      title: draft.title,
      body: draft.body,
      author: _authorName,
      audienceKeys: draft.audienceKeys,
      priority: draft.priority,
      attachments: draft.attachments,
    );
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.announcementPublished),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  void _openDetail(Announcement item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AnnouncementDetailScreen(announcement: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final items = _items;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('Announcements', style: WebErpTheme.sectionTitle(context)),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: ModuleAccess.canManage('announcements')
                        ? _create
                        : null,
                    icon: const Icon(Icons.campaign_outlined),
                    label: Text(s.newAnnouncement),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Create and publish announcements with text, attachments, and videos.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: items.isEmpty
                    ? Center(
                        child: Text(
                          s.noAnnouncements,
                          style: TextStyle(color: Colors.grey.shade600),
                        ),
                      )
                    : ListView.separated(
                        itemCount: items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return AnnouncementCard(
                            announcement: item,
                            onTap: () => _openDetail(item),
                            audienceLabelBuilder: s.announcementAudienceKey,
                            dateLabel:
                                '${item.date.day}/${item.date.month}/${item.date.year}',
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}
