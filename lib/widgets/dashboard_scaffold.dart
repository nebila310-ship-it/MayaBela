import 'package:flutter/material.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/notifications_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/cloud/conversation_realtime_sync.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/dashboard_badge_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/school_content_sync_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/web_erp/widgets/web_cloud_sync_bar.dart';
import 'package:mayabela/widgets/admin_educational_background.dart';
import 'package:mayabela/widgets/classroom_sidebar.dart';
import 'package:mayabela/widgets/dashboard_account_menu.dart';
import 'package:mayabela/widgets/school_branding_header.dart';

class DashboardScaffold extends StatefulWidget {
  const DashboardScaffold({
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
  State<DashboardScaffold> createState() => _DashboardScaffoldState();

  void _openAccountMenu(BuildContext context) {
    showDashboardAccountMenu(
      context,
      roleKey: roleKey,
      accent: gradientColors.first,
    );
  }

  Widget _buildWelcomeBanner(AppStrings s) {
    if (welcomeName != null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.32),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.22),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.35),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: welcomeLeading ??
                  Center(
                    child: Text(
                      welcomeEmoji ?? '👋',
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    welcomeGreeting ?? s.welcomeBack,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.88),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    welcomeName!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    ),
                  ),
                  if (welcomeSubtitle != null && welcomeSubtitle!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        welcomeSubtitle!,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.95),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: gradientColors),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        welcomeMessage,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 22,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCardGrid(List<Widget> items, int crossAxis, bool compact) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: crossAxis,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: compact ? 0.95 : 1.0,
      children: items,
    );
  }

  Widget _buildSectionedCards(List<BuiltDashboardSection> sections, int crossAxis, bool compact) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < sections.length; i++) ...[
          if (i > 0) const SizedBox(height: 20),
          Row(
            children: [
              if (sections[i].icon != null) ...[
                Icon(sections[i].icon, size: 18, color: gradientColors.first),
                const SizedBox(width: 8),
              ],
              Text(
                sections[i].title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: gradientColors.first,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildCardGrid(sections[i].cards, crossAxis, compact),
        ],
      ],
    );
  }

}

class _DashboardScaffoldState extends State<DashboardScaffold> {
  int _selectedIndex = 0;

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
        final unread = NotificationService.instance.unreadCount();
        final compact = UserPreferencesService.instance.compactDashboard;
        final width = MediaQuery.sizeOf(context).width;
        final crossAxis = compact && width >= 520 ? 3 : 2;
        final themeColor = widget.gradientColors.first;
        final sectionList = widget.sections;
        final cardList = widget.cards;
        final destinations = classroomNavDestinations(
          roleKey: widget.roleKey,
          s: s,
        );

        return Scaffold(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? Theme.of(context).colorScheme.surface
              : const Color(0xFFCFDBEA),
          drawer: ClassroomSidebar(
            title: widget.title,
            accent: themeColor,
            destinations: destinations,
            selectedIndex: _selectedIndex.clamp(0, destinations.length - 1),
            collapsed: false,
            inDrawer: true,
            onToggle: () => Navigator.of(context).maybePop(),
            onSelect: (index) {
              setState(() => _selectedIndex = index);
              selectClassroomDestination(
                index: index,
                roleKey: widget.roleKey,
                destinations: destinations,
                onIndex: (i) => _selectedIndex = i,
              );
              Navigator.of(context).maybePop();
            },
          ),
          appBar: AppBar(
            backgroundColor: themeColor,
            foregroundColor: Colors.white,
            leading: Builder(
              builder: (context) {
                return IconButton(
                  key: const Key('classroom-open-menu'),
                  tooltip: s.openClassroomMenu,
                  onPressed: () => Scaffold.of(context).openDrawer(),
                  icon: const Icon(Icons.menu_rounded),
                );
              },
            ),
            title: Text(widget.title),
            actions: [
              IconButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const NotificationsScreen(),
                    ),
                  );
                },
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text(unread > 99 ? '99+' : '$unread'),
                  child: const Icon(Icons.notifications),
                ),
              ),
              IconButton(
                onPressed: () => widget._openAccountMenu(context),
                tooltip: s.profile,
                icon: CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.white.withValues(alpha: 0.22),
                  child: const Icon(
                    Icons.person_rounded,
                    size: 18,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const WebCloudSyncBar(horizontalPadding: 16),
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AdminEducationalBackground(accentColor: themeColor),
                    SingleChildScrollView(
                      padding: listPagePadding(context),
                      child: Column(
                        children: [
                          if (!widget.hideBrandingBanner &&
                              AuthService.activeSchoolId != null &&
                              SchoolRegistryService.instance
                                      .lookup(AuthService.activeSchoolId) !=
                                  null)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: themeColor.withValues(alpha: 0.12),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: themeColor.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: SchoolBrandingHeader(
                                schoolId: AuthService.activeSchoolId,
                                compact: true,
                              ),
                            ),
                          if (!widget.hideWelcomeBanner)
                            widget._buildWelcomeBanner(s),
                          if (widget.header != null) ...[
                            const SizedBox(height: 16),
                            widget.header!,
                          ],
                          const SizedBox(height: 20),
                          if (sectionList != null && sectionList.isNotEmpty)
                            widget._buildSectionedCards(
                              sectionList,
                              crossAxis,
                              compact,
                            )
                          else
                            widget._buildCardGrid(
                              cardList,
                              crossAxis,
                              compact,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
