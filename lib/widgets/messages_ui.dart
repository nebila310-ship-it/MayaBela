import 'dart:io';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/announcement.dart';
import 'package:mayabela/models/message.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/announcement_attachment_service.dart';
import 'package:mayabela/services/presence_service.dart';
import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/widgets/admin_form_ui.dart';

class MessagesPalette {
  MessagesPalette._();

  static const appBar = Color(0xFF008069);
  static const primary = Color(0xFF008069);
  static const secondary = Color(0xFF00A884);
  static const accent = Color(0xFF25D366);
  static const warm = Color(0xFF25D366);
  static const outgoingBubble = Color(0xFFD9FDD3);
  static const incomingBubble = Color(0xFFFFFFFF);
  static const chatWallpaper = Color(0xFFEFEAE2);
  static const listBg = Color(0xFFFFFFFF);
  static const composerBar = Color(0xFFF0F2F5);
  static const ink = Color(0xFF111B21);
  static const muted = Color(0xFF667781);
  static const checkBlue = Color(0xFF53BDEB);
  static const fab = Color(0xFF25D366);
  static const unreadBadge = Color(0xFF25D366);

  static const gradient = [
    Color(0xFF075E54),
    Color(0xFF008069),
    Color(0xFF00A884),
  ];

  static LinearGradient get pageGradient => const LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFFF0F2F5)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static const avatarColors = [
    Color(0xFF00A884),
    Color(0xFF53BDEB),
    Color(0xFF9B59B6),
    Color(0xFFE91E63),
    Color(0xFFE67E22),
    Color(0xFF1ABC9C),
    Color(0xFF3498DB),
    Color(0xFF16A085),
  ];

  static Color colorForName(String name) {
    final hash = name.trim().toLowerCase().hashCode.abs();
    return avatarColors[hash % avatarColors.length];
  }

  static Color bubbleFg(bool outgoing) => ink;

  static Color bubbleMuted(bool outgoing) => muted;

  static Color chipBg(bool outgoing) =>
      outgoing ? const Color(0xFFC6E9C1) : const Color(0xFFF0F2F5);
}

class CommunityPalette {
  CommunityPalette._();

  static const primary = Color(0xFF0D9488);
  static const secondary = Color(0xFF14B8A6);
  static const accent = Color(0xFF99F6E4);
  static const surface = Color(0xFFF0FDFA);

  static const gradient = [
    Color(0xFF0F766E),
    Color(0xFF0D9488),
    Color(0xFF2DD4BF),
  ];

  static LinearGradient get pageGradient => LinearGradient(
    colors: [
      const Color(0xFFF0FDFA),
      const Color(0xFFECFDF5),
      const Color(0xFFFAFAFA),
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}

class PresenceDot extends StatelessWidget {
  const PresenceDot({super.key, required this.online, this.size = 10});

  final bool online;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: online ? const Color(0xFF16A34A) : const Color(0xFF9CA3AF),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}

class PresenceLabel extends StatelessWidget {
  const PresenceLabel({super.key, required this.online, this.light = false});

  final bool online;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final color = light
        ? Colors.white.withValues(alpha: 0.92)
        : (online ? const Color(0xFF15803D) : Colors.grey.shade600);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PresenceDot(online: online, size: 8),
        const SizedBox(width: 6),
        Text(
          online ? s.onlineNow : s.offlineNow,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

class MessagesAppBar extends StatelessWidget implements PreferredSizeWidget {
  const MessagesAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.peerOnline,
    this.actions = const [],
    this.useCommunityTheme = false,
    this.photoPath,
    this.onTitleTap,
    this.bottom,
    this.titleKey,
  });

  final String title;
  final String? subtitle;
  final bool? peerOnline;
  final List<Widget> actions;
  final bool useCommunityTheme;
  final String? photoPath;
  final VoidCallback? onTitleTap;
  final PreferredSizeWidget? bottom;
  final Key? titleKey;

  @override
  Size get preferredSize {
    final extra = subtitle != null || peerOnline != null ? 16.0 : 0.0;
    final tab = bottom?.preferredSize.height ?? 0;
    return Size.fromHeight(kToolbarHeight + extra + tab);
  }

  @override
  Widget build(BuildContext context) {
    final subtitleStyle = TextStyle(
      fontSize: 13,
      color: Colors.white.withValues(alpha: 0.86),
    );
    Widget? subtitleChild;
    if (subtitle != null && subtitle!.trim().isNotEmpty && peerOnline != null) {
      subtitleChild = Row(
        children: [
          Flexible(
            child: Text(
              subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: subtitleStyle,
            ),
          ),
          const SizedBox(width: 8),
          PresenceLabel(online: peerOnline!, light: true),
        ],
      );
    } else if (peerOnline != null) {
      subtitleChild = PresenceLabel(online: peerOnline!, light: true);
    } else if (subtitle != null && subtitle!.trim().isNotEmpty) {
      subtitleChild = Text(
        subtitle!,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: subtitleStyle,
      );
    }
    final titleText = Text(
      title,
      key: titleKey,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
    );
    final titleWidget = subtitleChild != null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [titleText, subtitleChild],
          )
        : titleText;

    final showAvatar =
        photoPath != null || peerOnline != null || onTitleTap != null;
    final titled = showAvatar
        ? Row(
            children: [
              ChatPersonAvatar(
                name: title,
                photoPath: photoPath,
                size: 38,
                online: peerOnline ?? false,
                showOnline: peerOnline != null,
              ),
              const SizedBox(width: 10),
              Expanded(child: titleWidget),
            ],
          )
        : titleWidget;

    return AppBar(
      elevation: 0,
      backgroundColor: MessagesPalette.appBar,
      foregroundColor: Colors.white,
      actions: actions,
      bottom: bottom,
      title: onTitleTap == null
          ? titled
          : InkWell(onTap: onTitleTap, child: titled),
    );
  }
}

class MessageStaffPicker extends StatelessWidget {
  const MessageStaffPicker({
    super.key,
    required this.staff,
    required this.selectedIds,
    required this.onChanged,
    this.multiSelect = true,
  });

  final List<StaffMemberOption> staff;
  final Set<String> selectedIds;
  final ValueChanged<Set<String>> onChanged;
  final bool multiSelect;

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _StaffSearchSheet(
        staff: staff,
        selectedIds: Set<String>.from(selectedIds),
        multiSelect: multiSelect,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PresenceService.instance,
      builder: (context, _) => _buildPicker(context),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final s = AppLocale.instance.strings;
    if (staff.isEmpty) {
      return Text(
        s.noStaffRegistered,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }

    final selectedMembers = staff
        .where((member) => selectedIds.contains(member.id))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration:
                adminFieldDecoration(
                  label: s.messageSelectStaff,
                  icon: Icons.badge_outlined,
                  accent: const Color(0xFF7C3AED),
                ).copyWith(
                  suffixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                ),
            child: Text(
              selectedMembers.isEmpty
                  ? s.messageSelectStaff
                  : multiSelect
                  ? s.messageStaffSelected(selectedMembers.length)
                  : selectedMembers.first.labeledName,
              style: TextStyle(
                color: selectedMembers.isEmpty
                    ? Colors.grey.shade600
                    : Colors.black87,
              ),
            ),
          ),
        ),
        if (multiSelect && selectedMembers.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedMembers.map((member) {
              return InputChip(
                avatar: Icon(_staffIcon(member.kind), size: 16),
                label: Text(member.labeledName),
                onDeleted: () {
                  final next = Set<String>.from(selectedIds)..remove(member.id);
                  onChanged(next);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

class MessageParentPicker extends StatelessWidget {
  const MessageParentPicker({
    super.key,
    required this.parents,
    required this.selectedNames,
    required this.onChanged,
    this.multiSelect = true,
  });

  final List<ParentRecipientOption> parents;
  final Set<String> selectedNames;
  final ValueChanged<Set<String>> onChanged;
  final bool multiSelect;

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ParentSearchSheet(
        parents: parents,
        selectedNames: Set<String>.from(selectedNames),
        multiSelect: multiSelect,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PresenceService.instance,
      builder: (context, _) => _buildPicker(context),
    );
  }

  Widget _buildPicker(BuildContext context) {
    final s = AppLocale.instance.strings;
    if (parents.isEmpty) {
      return Text(
        s.noParentsRegistered,
        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
      );
    }

    final selectedOptions = parents
        .where((option) => selectedNames.contains(option.parentName))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InkWell(
          onTap: () => _openPicker(context),
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration:
                adminFieldDecoration(
                  label: s.messageSelectParent,
                  icon: Icons.family_restroom_outlined,
                  accent: MessagesPalette.primary,
                ).copyWith(
                  suffixIcon: Icon(Icons.search, color: Colors.grey.shade600),
                ),
            child: Text(
              selectedOptions.isEmpty
                  ? s.messageSelectParent
                  : multiSelect
                  ? s.messageParentsSelected(selectedOptions.length)
                  : selectedOptions.first.labeledName,
              style: TextStyle(
                color: selectedOptions.isEmpty
                    ? Colors.grey.shade600
                    : Colors.black87,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
        if (multiSelect && selectedOptions.isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: selectedOptions.map((option) {
              return InputChip(
                label: Text(option.labeledName),
                onDeleted: () {
                  final next = Set<String>.from(selectedNames)
                    ..remove(option.parentName);
                  onChanged(next);
                },
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

IconData _staffIcon(StaffKind kind) => switch (kind) {
  StaffKind.teacher => Icons.school_outlined,
  StaffKind.driver => Icons.directions_bus_outlined,
  StaffKind.adminStaff => Icons.admin_panel_settings_outlined,
};

Color _staffColor(StaffKind kind) => switch (kind) {
  StaffKind.teacher => const Color(0xFF7C3AED),
  StaffKind.driver => const Color(0xFFEA580C),
  StaffKind.adminStaff => MessagesPalette.primary,
};

class _SelectAllBar extends StatelessWidget {
  const _SelectAllBar({required this.allSelected, required this.onToggleAll});

  final bool allSelected;
  final VoidCallback onToggleAll;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Material(
      color: MessagesPalette.primary.withValues(alpha: 0.06),
      borderRadius: BorderRadius.circular(14),
      child: CheckboxListTile(
        value: allSelected,
        onChanged: (_) => onToggleAll(),
        controlAffinity: ListTileControlAffinity.leading,
        title: Text(
          s.selectAll,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          s.selectAllHint,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ParentSearchSheet extends StatefulWidget {
  const _ParentSearchSheet({
    required this.parents,
    required this.selectedNames,
    required this.multiSelect,
  });

  final List<ParentRecipientOption> parents;
  final Set<String> selectedNames;
  final bool multiSelect;

  @override
  State<_ParentSearchSheet> createState() => _ParentSearchSheetState();
}

class _ParentSearchSheetState extends State<_ParentSearchSheet> {
  final _query = TextEditingController();
  late Set<String> _selected = Set<String>.from(widget.selectedNames);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<ParentRecipientOption> get _filtered => widget.parents
      .where((option) => option.matchesQuery(_query.text))
      .toList();

  bool get _allFilteredSelected =>
      _filtered.isNotEmpty &&
      _filtered.every((option) => _selected.contains(option.parentName));

  void _toggleSelectAll() {
    setState(() {
      if (_allFilteredSelected) {
        for (final option in _filtered) {
          _selected.remove(option.parentName);
        }
      } else {
        for (final option in _filtered) {
          _selected.add(option.parentName);
        }
      }
    });
  }

  void _toggleParent(String parentName) {
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(parentName)) {
          _selected.remove(parentName);
        } else {
          _selected.add(parentName);
        }
      } else {
        _selected = {parentName};
        Navigator.pop(context, _selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PresenceService.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.messageSelectParent,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.messageSearchParentHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _query,
                        autofocus: true,
                        decoration: adminFieldDecoration(
                          label: s.search,
                          icon: Icons.search_rounded,
                          accent: MessagesPalette.primary,
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (widget.multiSelect) ...[
                        const SizedBox(height: 10),
                        _SelectAllBar(
                          allSelected: _allFilteredSelected,
                          onToggleAll: _toggleSelectAll,
                        ),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              s.messageNoSearchResults,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final option = _filtered[index];
                            final isSelected = _selected.contains(
                              option.parentName,
                            );
                            final online = PresenceService.instance
                                .isParentOnline(option);
                            if (widget.multiSelect) {
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (_) =>
                                    _toggleParent(option.parentName),
                                secondary: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: MessagesPalette.primary
                                          .withValues(alpha: 0.12),
                                      child: Icon(
                                        Icons.family_restroom_outlined,
                                        color: MessagesPalette.primary,
                                      ),
                                    ),
                                    Positioned(
                                      right: -1,
                                      bottom: -1,
                                      child: PresenceDot(online: online),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  option.labeledName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${online ? AppLocale.instance.strings.onlineNow : AppLocale.instance.strings.offlineNow} · ${option.searchDetail}',
                                ),
                              );
                            }
                            return ListTile(
                              selected: isSelected,
                              leading: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: MessagesPalette.primary
                                        .withValues(alpha: 0.12),
                                    child: Icon(
                                      Icons.family_restroom_outlined,
                                      color: MessagesPalette.primary,
                                    ),
                                  ),
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: PresenceDot(
                                      online: PresenceService.instance
                                          .isParentOnline(option),
                                    ),
                                  ),
                                ],
                              ),
                              title: Text(
                                option.labeledName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${PresenceService.instance.isParentOnline(option) ? AppLocale.instance.strings.onlineNow : AppLocale.instance.strings.offlineNow} · ${option.searchDetail}',
                              ),
                              trailing: isSelected
                                  ? Icon(
                                      Icons.check_circle,
                                      color: MessagesPalette.primary,
                                    )
                                  : null,
                              onTap: () => _toggleParent(option.parentName),
                            );
                          },
                        ),
                ),
                if (widget.multiSelect)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: MessagesPalette.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(s.messageDoneSelecting),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StaffSearchSheet extends StatefulWidget {
  const _StaffSearchSheet({
    required this.staff,
    required this.selectedIds,
    required this.multiSelect,
  });

  final List<StaffMemberOption> staff;
  final Set<String> selectedIds;
  final bool multiSelect;

  @override
  State<_StaffSearchSheet> createState() => _StaffSearchSheetState();
}

class _StaffSearchSheetState extends State<_StaffSearchSheet> {
  final _query = TextEditingController();
  late Set<String> _selected = Set<String>.from(widget.selectedIds);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  List<StaffMemberOption> get _filtered =>
      widget.staff.where((member) => member.matchesQuery(_query.text)).toList();

  bool get _allFilteredSelected =>
      _filtered.isNotEmpty &&
      _filtered.every((member) => _selected.contains(member.id));

  void _toggleSelectAll() {
    setState(() {
      if (_allFilteredSelected) {
        for (final member in _filtered) {
          _selected.remove(member.id);
        }
      } else {
        for (final member in _filtered) {
          _selected.add(member.id);
        }
      }
    });
  }

  void _toggleStaff(String staffId) {
    setState(() {
      if (widget.multiSelect) {
        if (_selected.contains(staffId)) {
          _selected.remove(staffId);
        } else {
          _selected.add(staffId);
        }
      } else {
        _selected = {staffId};
        Navigator.pop(context, _selected);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PresenceService.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

        return Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.78,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        s.messageSelectStaff,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        s.messageSearchStaffHint,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _query,
                        autofocus: true,
                        decoration: adminFieldDecoration(
                          label: s.search,
                          icon: Icons.search_rounded,
                          accent: const Color(0xFF7C3AED),
                        ),
                        onChanged: (_) => setState(() {}),
                      ),
                      if (widget.multiSelect) ...[
                        const SizedBox(height: 10),
                        _SelectAllBar(
                          allSelected: _allFilteredSelected,
                          onToggleAll: _toggleSelectAll,
                        ),
                      ],
                    ],
                  ),
                ),
                Flexible(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(
                              s.messageNoSearchResults,
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          ),
                        )
                      : ListView.separated(
                          shrinkWrap: true,
                          itemCount: _filtered.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final member = _filtered[index];
                            final isSelected = _selected.contains(member.id);
                            final color = _staffColor(member.kind);
                            final online = PresenceService.instance
                                .isStaffOnline(member);
                            if (widget.multiSelect) {
                              return CheckboxListTile(
                                value: isSelected,
                                onChanged: (_) => _toggleStaff(member.id),
                                secondary: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      backgroundColor: color.withValues(
                                        alpha: 0.12,
                                      ),
                                      child: Icon(
                                        _staffIcon(member.kind),
                                        color: color,
                                      ),
                                    ),
                                    Positioned(
                                      right: -1,
                                      bottom: -1,
                                      child: PresenceDot(online: online),
                                    ),
                                  ],
                                ),
                                title: Text(
                                  member.labeledName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                subtitle: Text(
                                  '${online ? AppLocale.instance.strings.onlineNow : AppLocale.instance.strings.offlineNow} · ${member.subtitle}',
                                ),
                              );
                            }
                            return ListTile(
                              selected: isSelected,
                              leading: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  CircleAvatar(
                                    backgroundColor: color.withValues(
                                      alpha: 0.12,
                                    ),
                                    child: Icon(
                                      _staffIcon(member.kind),
                                      color: color,
                                    ),
                                  ),
                                  Positioned(
                                    right: -1,
                                    bottom: -1,
                                    child: PresenceDot(online: online),
                                  ),
                                ],
                              ),
                              title: Text(
                                member.labeledName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              subtitle: Text(
                                '${online ? AppLocale.instance.strings.onlineNow : AppLocale.instance.strings.offlineNow} · ${member.subtitle}',
                              ),
                              trailing: isSelected
                                  ? Icon(Icons.check_circle, color: color)
                                  : null,
                              onTap: () => _toggleStaff(member.id),
                            );
                          },
                        ),
                ),
                if (widget.multiSelect)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _selected),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                      ),
                      child: Text(s.messageDoneSelecting),
                    ),
                  )
                else
                  const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}

class MessageAudiencePicker extends StatelessWidget {
  const MessageAudiencePicker({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  final Set<String> selected;
  final ValueChanged<Set<String>> onChanged;

  static const selectable = [
    AnnouncementAudiences.parents,
    AnnouncementAudiences.teachers,
    AnnouncementAudiences.transport,
  ];

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: selectable.map((key) {
        final isSelected = selected.contains(key);
        final color = _colorForKey(key);
        return FilterChip(
          selected: isSelected,
          label: Text(s.messageAudienceKey(key)),
          avatar: Icon(
            _iconForKey(key),
            size: 18,
            color: isSelected ? Colors.white : color,
          ),
          selectedColor: color,
          checkmarkColor: Colors.white,
          labelStyle: TextStyle(
            color: isSelected ? Colors.white : color,
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

  Color _colorForKey(String key) {
    return switch (key) {
      AnnouncementAudiences.parents => const Color(0xFF2563EB),
      AnnouncementAudiences.teachers => const Color(0xFF7C3AED),
      AnnouncementAudiences.transport => const Color(0xFFEA580C),
      _ => MessagesPalette.primary,
    };
  }

  IconData _iconForKey(String key) {
    return switch (key) {
      AnnouncementAudiences.parents => Icons.family_restroom_outlined,
      AnnouncementAudiences.teachers => Icons.school_outlined,
      AnnouncementAudiences.transport => Icons.directions_bus_outlined,
      _ => Icons.groups_outlined,
    };
  }
}

class ConversationCard extends StatelessWidget {
  const ConversationCard({
    super.key,
    required this.conversation,
    required this.timeLabel,
    required this.audienceLabelBuilder,
    required this.onTap,
    this.unreadCount,
  });

  final Conversation conversation;
  final String timeLabel;
  final String Function(String key) audienceLabelBuilder;
  final VoidCallback onTap;
  final int? unreadCount;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PresenceService.instance,
      builder: (context, _) {
        final chat = conversation;
        final role = AuthService.currentUser?.roleKey;
        final viewerStaffId = role == AuthService.roleAdmin
            ? StaffMemberOption.viewerAdminStaffId(role)
            : StaffMemberOption.viewerStaffId(role);
        final unread =
            unreadCount ??
            chat.unreadForViewer(role, viewerStaffId: viewerStaffId);
        final isBroadcast = chat.isBroadcast;
        final isCommunity = chat.isGroup;
        final showPresence = !isBroadcast && !isCommunity;
        final peerOnline = showPresence
            ? PresenceService.instance.isConversationPeerOnline(chat)
            : false;
        final title = chat.inboxTitleForViewer();
        final roleLabel = chat.inboxPeerRoleLabel();
        final preview = chat.lastMessagePreviewForViewer(
          youLabel: AppLocale.instance.strings.youChatPreview,
        );

        return Material(
          color: Colors.white,
          child: InkWell(
            key: Key('conversation-row-${chat.id}'),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  ChatPersonAvatar(
                    name: title,
                    photoPath: isCommunity ? chat.photoPath : null,
                    size: 52,
                    icon: isBroadcast
                        ? Icons.campaign_rounded
                        : isCommunity
                        ? Icons.groups_rounded
                        : null,
                    online: peerOnline,
                    showOnline: showPresence,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                  fontSize: 16,
                                  color: MessagesPalette.ink,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeLabel,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: unread > 0
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: unread > 0
                                    ? MessagesPalette.accent
                                    : MessagesPalette.muted,
                              ),
                            ),
                          ],
                        ),
                        if (roleLabel != null &&
                            roleLabel.trim().isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            roleLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: MessagesPalette.secondary,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                preview,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: unread > 0
                                      ? MessagesPalette.ink
                                      : MessagesPalette.muted,
                                  fontWeight: unread > 0
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            if (unread > 0) ...[
                              const SizedBox(width: 8),
                              Container(
                                constraints: const BoxConstraints(
                                  minWidth: 20,
                                  minHeight: 20,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: MessagesPalette.unreadBadge,
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  unread > 99 ? '99+' : '$unread',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (isBroadcast &&
                            chat.broadcastAudienceKeys.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: chat.broadcastAudienceKeys
                                .map(
                                  (key) => _MiniChip(
                                    label: audienceLabelBuilder(key),
                                    color: MessagesPalette.secondary,
                                  ),
                                )
                                .toList(),
                          ),
                        ],
                      ],
                    ),
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

class _MiniChip extends StatelessWidget {
  const _MiniChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: color.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

class CommunityMembersSheet extends StatefulWidget {
  const CommunityMembersSheet({
    super.key,
    required this.conversationId,
    required this.canManage,
    this.onChanged,
    this.onMemberTap,
  });

  final String conversationId;
  final bool canManage;
  final VoidCallback? onChanged;
  final ValueChanged<GroupMemberEntry>? onMemberTap;

  static Future<void> show(
    BuildContext context, {
    required String conversationId,
    required bool canManage,
    VoidCallback? onChanged,
    ValueChanged<GroupMemberEntry>? onMemberTap,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CommunityMembersSheet(
        conversationId: conversationId,
        canManage: canManage,
        onChanged: onChanged,
        onMemberTap: onMemberTap,
      ),
    );
  }

  @override
  State<CommunityMembersSheet> createState() => _CommunityMembersSheetState();
}

class _CommunityMembersSheetState extends State<CommunityMembersSheet> {
  final _data = SchoolDataService.instance;

  List<GroupMemberEntry> get _members =>
      _data.getCommunityMembers(widget.conversationId);

  void _reload() {
    setState(() {});
    widget.onChanged?.call();
  }

  Future<void> _openAddMembers() async {
    final parents = _data.getAvailableParentsForCommunity(
      widget.conversationId,
    );
    final staff = _data.getAvailableStaffForCommunity(widget.conversationId);
    if (parents.isEmpty && staff.isEmpty) {
      final s = AppLocale.instance.strings;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(s.noMembersAvailableToAdd)));
      return;
    }

    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddCommunityMembersSheet(
        conversationId: widget.conversationId,
        parents: parents,
        staff: staff,
      ),
    );
    if (added == true && mounted) {
      _reload();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocale.instance.strings.membersAdded),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
    }
  }

  void _removeMember(GroupMemberEntry member) {
    final s = AppLocale.instance.strings;
    _data.removeCommunityMember(
      widget.conversationId,
      key: member.key,
      isParent: member.isParent,
    );
    if (!mounted) return;

    if (_data.getConversation(widget.conversationId) == null) {
      Navigator.pop(context);
      widget.onChanged?.call();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(s.memberRemoved),
          backgroundColor: const Color(0xFF15803D),
        ),
      );
      return;
    }

    _reload();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.memberRemoved),
        backgroundColor: const Color(0xFF15803D),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final members = _members;
    final parents = members.where((m) => m.isParent).toList();
    final staff = members.where((m) => !m.isParent).toList();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(99),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: CommunityPalette.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.diversity_3_rounded,
                    color: CommunityPalette.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.communityMembers,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                      Text(
                        s.communityMembersCount(members.length),
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (widget.canManage)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _openAddMembers,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: CommunityPalette.primary,
                    side: const BorderSide(color: CommunityPalette.primary),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  icon: const Icon(Icons.person_add_outlined),
                  label: Text(
                    s.addMember,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              children: [
                if (parents.isNotEmpty) ...[
                  _MembersSectionTitle(label: s.parents),
                  ...parents.map(
                    (member) => _MemberTile(
                      member: member,
                      canManage: widget.canManage,
                      onRemove: () => _removeMember(member),
                      onTap: widget.onMemberTap == null
                          ? null
                          : () => widget.onMemberTap!(member),
                    ),
                  ),
                ],
                if (staff.isNotEmpty) ...[
                  _MembersSectionTitle(label: s.staffAudience),
                  ...staff.map(
                    (member) => _MemberTile(
                      member: member,
                      canManage: widget.canManage,
                      onRemove: () => _removeMember(member),
                      onTap: widget.onMemberTap == null
                          ? null
                          : () => widget.onMemberTap!(member),
                    ),
                  ),
                ],
                if (members.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        s.communityMembersEmpty,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AddCommunityMembersSheet extends StatefulWidget {
  const AddCommunityMembersSheet({
    super.key,
    required this.conversationId,
    required this.parents,
    required this.staff,
  });

  final String conversationId;
  final List<ParentRecipientOption> parents;
  final List<StaffMemberOption> staff;

  @override
  State<AddCommunityMembersSheet> createState() =>
      _AddCommunityMembersSheetState();
}

class _AddCommunityMembersSheetState extends State<AddCommunityMembersSheet> {
  final Set<String> _selectedParentNames = {};
  final Set<String> _selectedStaffIds = {};
  String _error = '';

  void _confirmAdd() {
    final s = AppLocale.instance.strings;
    if (_selectedParentNames.isEmpty && _selectedStaffIds.isEmpty) {
      setState(() => _error = s.messageRecipientsRequired);
      return;
    }
    final ok = SchoolDataService.instance.addCommunityMembers(
      widget.conversationId,
      parentNames: _selectedParentNames.toList(),
      staffIds: _selectedStaffIds.toList(),
    );
    if (!ok) {
      setState(() => _error = s.messageRecipientsRequired);
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                s.addCommunityMembers,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 17,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                s.addCommunityMembersHint,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.parents.isNotEmpty) ...[
                Text(
                  s.messageParentsOptional,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                MessageParentPicker(
                  parents: widget.parents,
                  selectedNames: _selectedParentNames,
                  onChanged: (value) => setState(() {
                    _selectedParentNames
                      ..clear()
                      ..addAll(value);
                    _error = '';
                  }),
                ),
                const SizedBox(height: 16),
              ],
              if (widget.staff.isNotEmpty) ...[
                Text(
                  s.messageStaffOptional,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                MessageStaffPicker(
                  staff: widget.staff,
                  selectedIds: _selectedStaffIds,
                  onChanged: (value) => setState(() {
                    _selectedStaffIds
                      ..clear()
                      ..addAll(value);
                    _error = '';
                  }),
                ),
                const SizedBox(height: 16),
              ],
              if (_error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              FilledButton(
                onPressed: _confirmAdd,
                style: FilledButton.styleFrom(
                  backgroundColor: CommunityPalette.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(s.addMember),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MembersSectionTitle extends StatelessWidget {
  const _MembersSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 8, 6),
      child: Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: CommunityPalette.primary.withValues(alpha: 0.95),
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({
    required this.member,
    required this.canManage,
    required this.onRemove,
    this.onTap,
  });

  final GroupMemberEntry member;
  final bool canManage;
  final VoidCallback onRemove;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final online = member.isParent
        ? PresenceService.instance.isOnline(username: member.key)
        : PresenceService.instance.isOnline(staffId: member.key);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      onTap: onTap,
      leading: ChatPersonAvatar(
        name: member.displayName,
        size: 42,
        online: online,
        showOnline: true,
      ),
      title: Text(
        member.displayName,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: MessagesPalette.colorForName(member.displayName),
        ),
      ),
      subtitle: Text(
        '${online ? s.onlineNow : s.offlineNow} · ${member.typeLabel} · ${member.subtitle}',
      ),
      trailing: canManage
          ? TextButton.icon(
              onPressed: onRemove,
              icon: const Icon(Icons.person_remove_outlined, size: 18),
              label: Text(s.removeMember),
              style: TextButton.styleFrom(
                foregroundColor: const Color(0xFFDC2626),
              ),
            )
          : null,
    );
  }
}

IconData roleIcon(String role) {
  switch (role.toLowerCase()) {
    case 'parent':
      return Icons.family_restroom_outlined;
    case 'teacher':
      return Icons.school_outlined;
    case 'driver':
    case 'transport':
      return Icons.directions_bus_outlined;
    case 'admin':
      return Icons.admin_panel_settings_outlined;
    case 'broadcast':
      return Icons.campaign_outlined;
    default:
      return Icons.person_outline;
  }
}

Color roleColor(String role) {
  switch (role.toLowerCase()) {
    case 'parent':
      return const Color(0xFF2563EB);
    case 'teacher':
      return const Color(0xFF7C3AED);
    case 'driver':
    case 'transport':
      return const Color(0xFFEA580C);
    case 'admin':
      return const Color(0xFF4338CA);
    case 'broadcast':
      return MessagesPalette.warm;
    default:
      return MessagesPalette.secondary;
  }
}

class ChatPersonAvatar extends StatelessWidget {
  const ChatPersonAvatar({
    super.key,
    required this.name,
    this.photoPath,
    this.size = 52,
    this.icon,
    this.online = false,
    this.showOnline = false,
  });

  final String name;
  final String? photoPath;
  final double size;
  final IconData? icon;
  final bool online;
  final bool showOnline;

  String get _initials {
    final parts = name
        .trim()
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return '?';
    String first(String value) {
      final iter = value.runes.iterator;
      return iter.moveNext() ? String.fromCharCode(iter.current) : '?';
    }

    if (parts.length == 1) return first(parts.first).toUpperCase();
    return (first(parts.first) + first(parts.last)).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();
    final color = MessagesPalette.colorForName(name);

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              image: hasPhoto
                  ? DecorationImage(
                      image: FileImage(File(photoPath!)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            alignment: Alignment.center,
            child: hasPhoto
                ? null
                : icon != null
                ? Icon(icon, color: Colors.white, size: size * 0.46)
                : Text(
                    _initials,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: size * 0.34,
                    ),
                  ),
          ),
          if (showOnline)
            Positioned(
              right: 0,
              bottom: 0,
              child: PresenceDot(online: online, size: size * 0.22),
            ),
        ],
      ),
    );
  }
}

/// Tappable WhatsApp-style sender name in a chat bubble.
class TappableSenderName extends StatelessWidget {
  const TappableSenderName({
    super.key,
    required this.name,
    required this.onTap,
  });

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Text(
          name,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: MessagesPalette.colorForName(name),
          ),
        ),
      ),
    );
  }
}

class ChatWallpaper extends StatelessWidget {
  const ChatWallpaper({super.key});

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: MessagesPalette.chatWallpaper,
      child: CustomPaint(
        painter: _ChatDoodlePainter(),
        child: SizedBox.expand(),
      ),
    );
  }
}

class _ChatDoodlePainter extends CustomPainter {
  const _ChatDoodlePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0x14000000)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1;
    const step = 42.0;
    for (var row = 0; row * step < size.height + step; row++) {
      final y = row * step;
      final odd = row.isOdd;
      for (var col = 0; col * step < size.width + step; col++) {
        final x = col * step + (odd ? step / 2 : 0);
        canvas.drawCircle(Offset(x, y), 1.6, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class CommunityAvatar extends StatelessWidget {
  const CommunityAvatar({
    super.key,
    required this.accent,
    this.photoPath,
    this.size = 52,
    this.icon = Icons.diversity_3_rounded,
    this.borderRadius = 16,
  });

  final Color accent;
  final String? photoPath;
  final double size;
  final IconData icon;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: hasPhoto
            ? null
            : LinearGradient(
                colors: [accent, accent.withValues(alpha: 0.65)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(borderRadius),
        image: hasPhoto
            ? DecorationImage(
                image: FileImage(File(photoPath!)),
                fit: BoxFit.cover,
              )
            : null,
        border: hasPhoto
            ? Border.all(color: accent.withValues(alpha: 0.25))
            : null,
      ),
      alignment: Alignment.center,
      child: hasPhoto
          ? null
          : Icon(icon, color: Colors.white, size: size * 0.5),
    );
  }
}

class CommunityPhotoPicker extends StatelessWidget {
  const CommunityPhotoPicker({
    super.key,
    required this.photoPath,
    required this.onPick,
    required this.onRemove,
    this.picking = false,
  });

  final String? photoPath;
  final VoidCallback onPick;
  final VoidCallback onRemove;
  final bool picking;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final hasPhoto =
        photoPath != null &&
        photoPath!.isNotEmpty &&
        File(photoPath!).existsSync();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.communityPhotoOptional,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            CommunityAvatar(
              accent: CommunityPalette.primary,
              photoPath: photoPath,
              size: 72,
              borderRadius: 20,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  OutlinedButton.icon(
                    onPressed: picking ? null : onPick,
                    icon: picking
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: CommunityPalette.primary,
                            ),
                          )
                        : Icon(
                            hasPhoto
                                ? Icons.photo_camera_outlined
                                : Icons.add_a_photo_outlined,
                          ),
                    label: Text(
                      hasPhoto ? s.changeCommunityPhoto : s.addCommunityPhoto,
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: CommunityPalette.primary,
                      side: BorderSide(
                        color: CommunityPalette.primary.withValues(alpha: 0.35),
                      ),
                    ),
                  ),
                  if (hasPhoto) ...[
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: onRemove,
                      icon: const Icon(Icons.delete_outline, size: 18),
                      label: Text(s.removeCommunityPhoto),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red.shade700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class MessageAttachmentChip extends StatelessWidget {
  const MessageAttachmentChip({
    super.key,
    required this.attachment,
    required this.onTap,
    this.compact = false,
    this.isOutgoing = false,
  });

  final AnnouncementAttachment attachment;
  final VoidCallback onTap;
  final bool compact;
  final bool isOutgoing;

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
    final bg = MessagesPalette.chipBg(isOutgoing);
    final fg = MessagesPalette.bubbleFg(isOutgoing);
    final subFg = MessagesPalette.bubbleMuted(isOutgoing);

    return Padding(
      padding: EdgeInsets.only(top: compact ? 0 : 6, bottom: compact ? 6 : 0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Ink(
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: MessagesPalette.accent.withValues(alpha: 0.18),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 8 : 10,
                vertical: compact ? 6 : 8,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: compact ? 16 : 18, color: fg),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attachment.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: compact ? 11 : 12,
                            color: fg,
                          ),
                        ),
                        if (!compact && attachment.fileSizeBytes != null)
                          Text(
                            service.formatFileSize(attachment.fileSizeBytes),
                            style: TextStyle(fontSize: 10, color: subFg),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.open_in_new_rounded, size: 14, color: subFg),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PendingAttachmentRow extends StatelessWidget {
  const PendingAttachmentRow({
    super.key,
    required this.attachments,
    required this.onRemove,
  });

  final List<AnnouncementAttachment> attachments;
  final ValueChanged<AnnouncementAttachment> onRemove;

  @override
  Widget build(BuildContext context) {
    if (attachments.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: attachments.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final attachment = attachments[index];
          return InputChip(
            avatar: Icon(
              Icons.attach_file_rounded,
              size: 16,
              color: CommunityPalette.primary,
            ),
            label: Text(attachment.fileName, overflow: TextOverflow.ellipsis),
            deleteIcon: const Icon(Icons.close, size: 16),
            onDeleted: () => onRemove(attachment),
            backgroundColor: Colors.white,
            side: BorderSide(
              color: CommunityPalette.primary.withValues(alpha: 0.2),
            ),
          );
        },
      ),
    );
  }
}

/// Swipe a message toward the chat center to set it as the reply target.
class SwipeToReplyMessage extends StatefulWidget {
  const SwipeToReplyMessage({
    super.key,
    required this.isOutgoing,
    required this.enabled,
    required this.onReply,
    required this.accent,
    required this.child,
  });

  final bool isOutgoing;
  final bool enabled;
  final VoidCallback onReply;
  final Color accent;
  final Widget child;

  @override
  State<SwipeToReplyMessage> createState() => _SwipeToReplyMessageState();
}

class _SwipeToReplyMessageState extends State<SwipeToReplyMessage> {
  double _dragOffset = 0;
  static const _triggerThreshold = 52;
  static const _maxDrag = 68;

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.enabled) return;
    setState(() {
      final delta = details.delta.dx;
      if (widget.isOutgoing) {
        _dragOffset = (_dragOffset + delta).clamp(-_maxDrag, 0).toDouble();
      } else {
        _dragOffset = (_dragOffset + delta).clamp(0, _maxDrag).toDouble();
      }
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.enabled) return;
    final triggered = widget.isOutgoing
        ? _dragOffset <= -_triggerThreshold
        : _dragOffset >= _triggerThreshold;
    if (triggered) widget.onReply();
    setState(() => _dragOffset = 0);
  }

  @override
  Widget build(BuildContext context) {
    final showReplyHint = _dragOffset.abs() > 8;
    final iconOpacity = (_dragOffset.abs() / _triggerThreshold).clamp(0.0, 1.0);

    return GestureDetector(
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: widget.isOutgoing
            ? Alignment.centerRight
            : Alignment.centerLeft,
        children: [
          if (showReplyHint)
            Positioned(
              left: widget.isOutgoing ? null : 0,
              right: widget.isOutgoing ? 0 : null,
              child: Opacity(
                opacity: iconOpacity,
                child: Icon(
                  Icons.reply_rounded,
                  color: widget.accent.withValues(alpha: 0.85),
                  size: 22,
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dragOffset, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}

class MessageReplyComposerBar extends StatelessWidget {
  const MessageReplyComposerBar({
    super.key,
    required this.quote,
    required this.accent,
    required this.onCancel,
  });

  final MessageReplyQuote quote;
  final Color accent;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: accent, width: 3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.replyingTo} ${quote.senderDisplayName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: accent,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  quote.previewText,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: s.cancelReply,
            onPressed: onCancel,
            icon: Icon(Icons.close_rounded, color: Colors.grey.shade600),
          ),
        ],
      ),
    );
  }
}

class MessageReplyQuoteBubble extends StatelessWidget {
  const MessageReplyQuoteBubble({
    super.key,
    required this.quote,
    required this.isOutgoing,
    required this.accent,
  });

  final MessageReplyQuote quote;
  final bool isOutgoing;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final borderColor = accent;
    final nameColor = accent;
    final bodyColor = MessagesPalette.muted;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: MessagesPalette.chipBg(isOutgoing),
        borderRadius: BorderRadius.circular(10),
        border: Border(left: BorderSide(color: borderColor, width: 3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            quote.senderDisplayName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: nameColor,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            quote.previewText,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, height: 1.3, color: bodyColor),
          ),
        ],
      ),
    );
  }
}
