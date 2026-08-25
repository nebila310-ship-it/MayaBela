import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/notifications_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/conversation_realtime_sync.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/utils/adaptive_breakpoints.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';
import 'package:mayabela/widgets/classroom_sidebar.dart';
import 'package:mayabela/widgets/dashboard_account_menu.dart';
import 'package:mayabela/widgets/dashboard_scaffold.dart';
import 'package:mayabela/widgets/school_branding_header.dart';

/// Desktop/tablet shell: collapsible classroom sidebar + top bar.
/// Phone widths use [DashboardScaffold] with a slide-out menu.
class AdaptiveDashboardShell extends StatelessWidget {
  const AdaptiveDashboardShell({
    super.key,
    required this.title,
    required this.welcomeMessage,
    required this.gradientColors,
    required this.roleKey,
    this.cards = const [],
    this.sections,
    this.welcomeGreeting,
    this.welcomeName,
    this.welcomeSubtitle,
    this.welcomeEmoji,
    this.welcomeLeading,
    this.header,
    this.hideWelcomeBanner = false,
    this.hideBrandingBanner = false,
  });

  final String title;
  final String welcomeMessage;
  final String? welcomeGreeting;
  final String? welcomeName;
  final String? welcomeSubtitle;
  final String? welcomeEmoji;
  final Widget? welcomeLeading;
  final List<Color> gradientColors;
  final List<Widget> cards;
  final List<BuiltDashboardSection>? sections;
  final String roleKey;
  final Widget? header;
  final bool hideWelcomeBanner;
  final bool hideBrandingBanner;

  @override
  Widget build(BuildContext context) {
    if (AdaptiveBreakpoints.isMobile(context)) {
      return DashboardScaffold(
        title: title,
        welcomeMessage: welcomeMessage,
        welcomeGreeting: welcomeGreeting,
        welcomeName: welcomeName,
        welcomeSubtitle: welcomeSubtitle,
        welcomeEmoji: welcomeEmoji,
        welcomeLeading: welcomeLeading,
        gradientColors: gradientColors,
        roleKey: roleKey,
        cards: cards,
        sections: sections,
        header: header,
        hideWelcomeBanner: hideWelcomeBanner,
        hideBrandingBanner: hideBrandingBanner,
      );
    }

    return _DesktopDashboardShell(
      title: title,
      welcomeMessage: welcomeMessage,
      welcomeGreeting: welcomeGreeting,
      welcomeName: welcomeName,
      welcomeSubtitle: welcomeSubtitle,
      welcomeEmoji: welcomeEmoji,
      welcomeLeading: welcomeLeading,
      gradientColors: gradientColors,
      roleKey: roleKey,
      cards: cards,
      sections: sections,
      header: header,
      hideWelcomeBanner: hideWelcomeBanner,
      hideBrandingBanner: hideBrandingBanner,
    );
  }
}

class _DesktopDashboardShell extends StatefulWidget {
  const _DesktopDashboardShell({
    required this.title,
    required this.welcomeMessage,
    required this.gradientColors,
    required this.roleKey,
    required this.cards,
    this.sections,
    this.welcomeGreeting,
    this.welcomeName,
    this.welcomeSubtitle,
    this.welcomeEmoji,
    this.welcomeLeading,
    this.header,
    this.hideWelcomeBanner = false,
    this.hideBrandingBanner = false,
  });

  final String title;
  final String welcomeMessage;
  final String? welcomeGreeting;
  final String? welcomeName;
  final String? welcomeSubtitle;
  final String? welcomeEmoji;
  final Widget? welcomeLeading;
  final List<Color> gradientColors;
  final List<Widget> cards;
  final List<BuiltDashboardSection>? sections;
  final String roleKey;
  final Widget? header;
  final bool hideWelcomeBanner;
  final bool hideBrandingBanner;

  @override
  State<_DesktopDashboardShell> createState() => _DesktopDashboardShellState();
}

class _DesktopDashboardShellState extends State<_DesktopDashboardShell> {
  int _selectedIndex = 0;

  void _openAccountMenu(BuildContext context) {
    showDashboardAccountMenu(
      context,
      roleKey: widget.roleKey,
      accent: widget.gradientColors.first,
    );
  }

  Widget _buildWelcomeBanner(AppStrings s) {
    if (widget.welcomeName != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            if (widget.welcomeLeading != null)
              widget.welcomeLeading!
            else
              Text(widget.welcomeEmoji ?? '👋',
                  style: const TextStyle(fontSize: 36)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.welcomeGreeting ?? s.welcomeBack,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.9),
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    widget.welcomeName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (widget.welcomeSubtitle != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      widget.welcomeSubtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.92),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      );
    }
    return Text(
      widget.welcomeMessage,
      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
    );
  }

  Widget _buildCardGrid(List<Widget> items, int crossAxis, bool compact) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxis,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: compact ? 1.05 : 1.15,
      children: items,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        AppLocale.instance,
        NotificationService.instance,
        DashboardBadgeService.instance,
        SchoolContentSyncService.instance,
        ConversationRealtimeSync.instance,
        UserPreferencesService.instance,
      ]),
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final themeColor = widget.gradientColors.first;
        final unread = NotificationService.instance.unreadCount();
        final compact = UserPreferencesService.instance.compactDashboard;
        final crossAxis = AdaptiveBreakpoints.dashboardCrossAxisCount(
          context,
          compact: compact,
        );
        final destinations = classroomNavDestinations(
          roleKey: widget.roleKey,
          s: s,
        );
        final collapsed =
            UserPreferencesService.instance.classroomSidebarCollapsed;

        return Scaffold(
          backgroundColor: const Color(0xFFCFDBEA),
          body: Row(
            children: [
              ClassroomSidebar(
                title: widget.title,
                accent: themeColor,
                destinations: destinations,
                selectedIndex: _selectedIndex.clamp(0, destinations.length - 1),
                collapsed: collapsed,
                onToggle: () {
                  UserPreferencesService.instance
                      .setClassroomSidebarCollapsed(!collapsed);
                },
                onSelect: (index) {
                  setState(() => _selectedIndex = index);
                  selectClassroomDestination(
                    index: index,
                    roleKey: widget.roleKey,
                    destinations: destinations,
                    onIndex: (i) => _selectedIndex = i,
                  );
                },
              ),
              Expanded(
                child: ClipRect(
                child: Column(
                  children: [
                    Material(
                      color: themeColor,
                      child: SafeArea(
                        bottom: false,
                        child: SizedBox(
                          height: ClassroomSidebar.headerHeight,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                IconButton(
                                  key: const Key('classroom-top-menu'),
                                  tooltip: collapsed
                                      ? s.expandClassroomSidebar
                                      : s.collapseClassroomSidebar,
                                  onPressed: () {
                                    UserPreferencesService.instance
                                        .setClassroomSidebarCollapsed(
                                      !collapsed,
                                    );
                                  },
                                  icon: Icon(
                                    collapsed
                                        ? Icons.menu_open_rounded
                                        : Icons.menu_rounded,
                                    color: Colors.white,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    widget.title,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            const NotificationsScreen(),
                                      ),
                                    );
                                  },
                                  icon: Badge(
                                    isLabelVisible: unread > 0,
                                    label: Text(
                                      unread > 99 ? '99+' : '$unread',
                                    ),
                                    child: const Icon(
                                      Icons.notifications,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  onPressed: () => _openAccountMenu(context),
                                  icon: const CircleAvatar(
                                    radius: 16,
                                    backgroundColor: Colors.white24,
                                    child: Icon(
                                      Icons.person_rounded,
                                      size: 18,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          AdminEducationalBackground(accentColor: themeColor),
                          SingleChildScrollView(
                            padding: listPagePadding(context).copyWith(
                              left: 16,
                              right: 20,
                              top: 20,
                            ),
                            child: Align(
                              alignment: Alignment.topCenter,
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: AdaptiveBreakpoints.contentMaxWidth,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    if (!widget.hideBrandingBanner &&
                                        AuthService.activeSchoolId != null &&
                                        SchoolRegistryService.instance.lookup(
                                                AuthService.activeSchoolId) !=
                                            null)
                                      Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 16),
                                        child: SchoolBrandingHeader(
                                          schoolId: AuthService.activeSchoolId,
                                          compact: true,
                                        ),
                                      ),
                                    if (!widget.hideWelcomeBanner)
                                      _buildWelcomeBanner(s),
                                    if (widget.header != null) ...[
                                      const SizedBox(height: 16),
                                      widget.header!,
                                    ],
                                    const SizedBox(height: 24),
                                    if (widget.sections != null &&
                                        widget.sections!.isNotEmpty)
                                      for (final section
                                          in widget.sections!) ...[
                                        Row(
                                          children: [
                                            if (section.icon != null) ...[
                                              Icon(section.icon,
                                                  color: themeColor, size: 18),
                                              const SizedBox(width: 8),
                                            ],
                                            Text(
                                              section.title,
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w700,
                                                color: themeColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),
                                        _buildCardGrid(
                                          section.cards,
                                          crossAxis,
                                          compact,
                                        ),
                                        const SizedBox(height: 24),
                                      ]
                                    else
                                      _buildCardGrid(
                                        widget.cards,
                                        crossAxis,
                                        compact,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
