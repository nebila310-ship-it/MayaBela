import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/teacher_access_service.dart';

class AnnouncementsPalette {
  AnnouncementsPalette._();

  static const primary = Color(0xFFC2410C);
  static const secondary = Color(0xFFEA580C);
  static const accent = Color(0xFFFDBA74);
  static const deep = Color(0xFF9A3412);

  static const gradient = [Color(0xFFC2410C), Color(0xFFEA580C), Color(0xFFF97316)];

  static LinearGradient get pageGradient => LinearGradient(
        colors: [
          const Color(0xFFFFF7ED),
          const Color(0xFFFFEDD5).withValues(alpha: 0.55),
          const Color(0xFFF8FAFC),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      );
}

class AnnouncementPriorityStyle {
  const AnnouncementPriorityStyle({
    required this.color,
    required this.icon,
    required this.label,
  });

  final Color color;
  final IconData icon;
  final String label;

  static AnnouncementPriorityStyle forPriority(
    AnnouncementPriority priority,
    AppStrings s,
  ) {
    return switch (priority) {
      AnnouncementPriority.urgent => AnnouncementPriorityStyle(
          color: const Color(0xFFB91C1C),
          icon: Icons.notification_important_rounded,
          label: s.announcementPriorityUrgent,
        ),
      AnnouncementPriority.important => AnnouncementPriorityStyle(
          color: const Color(0xFFD97706),
          icon: Icons.priority_high_rounded,
          label: s.announcementPriorityImportant,
        ),
      AnnouncementPriority.normal => AnnouncementPriorityStyle(
          color: const Color(0xFF64748B),
          icon: Icons.info_outline_rounded,
          label: s.announcementPriorityNormal,
        ),
    };
  }
}

class AnnouncementsAppBar extends StatelessWidget implements PreferredSizeWidget {
  const AnnouncementsAppBar({super.key, required this.title});

  final String title;

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      elevation: 0,
      foregroundColor: Colors.white,
      flexibleSpace: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AnnouncementsPalette.gradient,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}

class AnnouncementCard extends StatelessWidget {
  const AnnouncementCard({
    super.key,
    required this.announcement,
    required this.onTap,
    required this.audienceLabelBuilder,
    required this.dateLabel,
  });

  final Announcement announcement;
  final VoidCallback onTap;
  final String Function(String key) audienceLabelBuilder;
  final String dateLabel;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final priority = AnnouncementPriorityStyle.forPriority(
      announcement.priority,
      s,
    );

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: priority.color.withValues(alpha: 0.18),
            ),
            boxShadow: [
              BoxShadow(
                color: priority.color.withValues(alpha: 0.1),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  width: 6,
                  decoration: BoxDecoration(
                    color: priority.color,
                    borderRadius: const BorderRadius.horizontal(
                      left: Radius.circular(22),
                    ),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: priority.color.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                priority.icon,
                                color: priority.color,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      if (announcement.isPinned) ...[
                                        Icon(
                                          Icons.push_pin_rounded,
                                          size: 16,
                                          color: AnnouncementsPalette.primary,
                                        ),
                                        const SizedBox(width: 4),
                                      ],
                                      Expanded(
                                        child: Text(
                                          announcement.title,
                                          style: const TextStyle(
                                            fontSize: 17,
                                            fontWeight: FontWeight.bold,
                                            height: 1.25,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    priority.label,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: priority.color,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          announcement.body,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            for (final key in announcement.audienceKeys)
                              _AudienceChip(
                                label: audienceLabelBuilder(key),
                                color: AnnouncementsPalette.secondary,
                              ),
                          ],
                        ),
                        if (announcement.attachments.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(
                                Icons.attach_file_rounded,
                                size: 16,
                                color: Colors.grey.shade600,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                s.announcementAttachmentCount(
                                  announcement.attachments.length,
                                ),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Icon(
                              Icons.person_outline_rounded,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                announcement.author,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            ),
                            Text(
                              dateLabel,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AudienceChip extends StatelessWidget {
  const _AudienceChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

class AnnouncementAttachmentTile extends StatelessWidget {
  const AnnouncementAttachmentTile({
    super.key,
    required this.attachment,
    required this.onTap,
  });

  final AnnouncementAttachment attachment;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final service = AnnouncementAttachmentService.instance;
    final hint = service.iconHintForFileName(attachment.fileName);
    final icon = switch (hint) {
      IconHint.pdf => Icons.picture_as_pdf_rounded,
      IconHint.document => Icons.description_outlined,
      IconHint.spreadsheet => Icons.table_chart_outlined,
      IconHint.image => Icons.image_outlined,
      IconHint.video => Icons.movie_outlined,
      IconHint.audio => Icons.audiotrack_outlined,
      IconHint.archive => Icons.folder_zip_outlined,
      IconHint.generic => Icons.insert_drive_file_outlined,
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AnnouncementsPalette.accent.withValues(alpha: 0.35)),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AnnouncementsPalette.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(icon, color: AnnouncementsPalette.deep, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        if (attachment.fileSizeBytes != null)
                          Text(
                            service.formatFileSize(attachment.fileSizeBytes),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.open_in_new_rounded, color: Colors.grey.shade500, size: 18),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AnnouncementPriorityPicker extends StatelessWidget {
  const AnnouncementPriorityPicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final AnnouncementPriority selected;
  final ValueChanged<AnnouncementPriority> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: AnnouncementPriority.values.map((priority) {
        final style = AnnouncementPriorityStyle.forPriority(priority, s);
        final isSelected = selected == priority;
        return FilterChip(
          selected: isSelected,
          showCheckmark: false,
          avatar: Icon(
            style.icon,
            size: 18,
            color: isSelected ? Colors.white : style.color,
          ),
          label: Text(style.label),
          selectedColor: style.color,
          backgroundColor: style.color.withValues(alpha: 0.08),
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : style.color,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: style.color.withValues(alpha: 0.35)),
          onSelected: (_) => onChanged(priority),
        );
      }).toList(),
    );
  }
}

class AnnouncementAudiencePicker extends StatelessWidget {
  const AnnouncementAudiencePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final role = AuthService.currentUser?.roleKey;
    final audienceKeys = [
      ...AnnouncementAudiences.selectable,
      if (role == AuthService.roleTeacher)
        ...TeacherAccessService.instance.homeroomClassNames,
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: audienceKeys.map((key) {
        final isSelected = selected.contains(key);
        return FilterChip(
          selected: isSelected,
          label: Text(s.announcementAudienceKey(key)),
          selectedColor: AnnouncementsPalette.secondary.withValues(alpha: 0.85),
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : AnnouncementsPalette.deep,
            fontWeight: FontWeight.w600,
          ),
          onSelected: (value) {
            final next = Set<String>.from(selected);
            if (value) {
              next.add(key);
            } else {
              next.remove(key);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}
