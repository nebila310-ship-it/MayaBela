import 'dart:async';

import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/notifications_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/widgets/school_branding_header.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

class WebErpTopBar extends StatefulWidget {
  const WebErpTopBar({
    super.key,
    required this.onNavigate,
    required this.onOpenSearch,
    this.onOpenMenu,
    this.onBack,
  });

  final ValueChanged<String> onNavigate;
  final VoidCallback onOpenSearch;
  final VoidCallback? onOpenMenu;
  final VoidCallback? onBack;

  @override
  State<WebErpTopBar> createState() => _WebErpTopBarState();
}

class _WebErpTopBarState extends State<WebErpTopBar> {
  late Timer _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    final schoolId = AuthService.activeSchoolId;
    final school = schoolId == null
        ? null
        : SchoolRegistryService.instance.lookup(schoolId);
    final schoolName = school?.name ??
        (schoolId != null
            ? AppLocale.instance.strings.schoolName(schoolId)
            : 'MaJo e-School Bridge');
    final messages = DashboardBadgeService.instance.countFor('messages');
    final notifications = NotificationService.instance.unreadCount();

    return Container(
      height: WebErpTheme.topBarHeight,
      decoration: BoxDecoration(
        color: WebErpTheme.paper.withValues(alpha: 0.88),
        border: Border(
          bottom: BorderSide(
            color: WebErpTheme.paperEdge.withValues(alpha: 0.7),
          ),
        ),
      ),
      padding: EdgeInsets.symmetric(horizontal: narrow ? 8 : 16),
      child: Row(
        children: [
          if (widget.onOpenMenu != null) ...[
            IconButton(
              tooltip: 'Menu',
              onPressed: widget.onOpenMenu,
              icon: const Icon(Icons.menu),
            ),
            if (!narrow) const SizedBox(width: 4),
          ],
          if (narrow && widget.onBack != null) ...[
            IconButton(
              tooltip: 'Back',
              onPressed: widget.onBack,
              icon: const Icon(Icons.arrow_back),
            ),
          ],
          if (!narrow) ...[
            const SchoolBrandingHeader(compact: true),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              schoolName,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontSize: narrow ? 14 : null,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (!narrow) ...[
            SizedBox(
              width: 280,
              child: TextField(
                readOnly: true,
                onTap: widget.onOpenSearch,
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Search… (Ctrl+K)',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            _chip(context, school?.academicYear ?? '2025/26', Icons.date_range),
            const SizedBox(width: 8),
            _chip(context, _campusLabel(schoolId), Icons.location_on_outlined),
            const SizedBox(width: 8),
          ] else
            IconButton(
              tooltip: 'Search',
              onPressed: widget.onOpenSearch,
              icon: const Icon(Icons.search),
            ),
          if (!narrow)
            PopupMenuButton<String>(
              tooltip: 'Language',
              onSelected: (code) => AppLocale.instance.setLanguage(code),
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'en', child: Text('English')),
                PopupMenuItem(value: 'am', child: Text('አማርኛ')),
              ],
              child: _iconBtn(Icons.translate, null),
            ),
          _iconBtn(
            Icons.notifications_outlined,
            notifications > 0 ? notifications : null,
            () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NotificationsScreen()),
            ),
          ),
          if (!narrow) ...[
            if (ModuleAccess.canView('support'))
              _iconBtn(
                Icons.mail_outline,
                messages > 0 ? messages : null,
                () => widget.onNavigate('support'),
              ),
            _iconBtn(Icons.task_alt_outlined, null, () {}),
            if (_quickAddItems.isNotEmpty)
              PopupMenuButton<String>(
                tooltip: 'Quick add',
                onSelected: widget.onNavigate,
                itemBuilder: (context) => [
                  for (final item in _quickAddItems)
                    PopupMenuItem(value: item.$1, child: Text(item.$2)),
                ],
                child: _iconBtn(Icons.add_circle_outline, null),
              ),
          ],
          PopupMenuButton<String>(
            onSelected: (v) {
              if (v == 'profile') widget.onNavigate('profile');
              if (v == 'settings') widget.onNavigate('settings');
              if (v == 'logout') widget.onNavigate('logout');
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'profile',
                child: Text(
                  (AuthService.currentUser?.fullName ?? '').trim().isNotEmpty
                      ? AuthService.currentUser!.fullName!
                      : AuthService.displayNameForRole(
                          AuthService.currentUser?.roleKey ??
                              AuthService.roleAdmin,
                        ),
                ),
              ),
              const PopupMenuItem(value: 'settings', child: Text('Settings')),
              const PopupMenuItem(value: 'logout', child: Text('Logout')),
            ],
            child: CircleAvatar(
              radius: narrow ? 14 : 16,
              backgroundColor: WebErpTheme.primary.withValues(alpha: 0.15),
              child: Icon(Icons.person, size: narrow ? 16 : 18),
            ),
          ),
          if (!narrow) ...[
            const SizedBox(width: 8),
            ListenableBuilder(
              listenable: UserPreferencesService.instance,
              builder: (context, _) {
                return IconButton(
                  tooltip: 'Toggle dark mode',
                  onPressed: () => UserPreferencesService.instance
                      .setDarkMode(!UserPreferencesService.instance.darkMode),
                  icon: Icon(
                    UserPreferencesService.instance.darkMode
                        ? Icons.light_mode_outlined
                        : Icons.dark_mode_outlined,
                  ),
                );
              },
            ),
            const SizedBox(width: 8),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${_now.day}/${_now.month}/${_now.year}',
                  style: Theme.of(context).textTheme.labelSmall,
                ),
                Text(
                  '${_now.hour.toString().padLeft(2, '0')}:${_now.minute.toString().padLeft(2, '0')}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Colors.greenAccent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 4),
                Text('Online', style: Theme.of(context).textTheme.labelSmall),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Quick-add entries the signed-in user is actually allowed to perform.
  List<(String, String)> get _quickAddItems => [
        if (ModuleAccess.canManage('students'))
          ('add_student', 'Add Student'),
        if (ModuleAccess.canManage('add_staff'))
          ('add_staff', 'Add Administration Staff'),
        if (ModuleAccess.canManage('add_teacher'))
          ('add_teacher', 'Add Teacher'),
        if (ModuleAccess.canManage('announcements'))
          ('announcements', 'Create Announcement'),
      ];

  String _campusLabel(String? schoolId) {
    final campuses = SchoolRegistryService.instance.campusesForSchool(schoolId);
    if (campuses.length == 1) return campuses.first;
    return '${campuses.length} campuses';
  }

  Widget _chip(BuildContext context, String label, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).dividerColor),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, int? badge, [VoidCallback? onTap]) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(icon),
          onPressed: onTap,
        ),
        if (badge != null && badge > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.redAccent,
                shape: BoxShape.circle,
              ),
              child: Text(
                '$badge',
                style: const TextStyle(color: Colors.white, fontSize: 9),
              ),
            ),
          ),
      ],
    );
  }
}
