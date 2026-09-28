import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:url_launcher/url_launcher.dart';

import 'package:mayabela/constants/app_info.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/change_password_screen.dart';
import 'package:mayabela/widgets/app_security_settings.dart';
import 'package:mayabela/widgets/mfa_settings_card.dart';
import 'package:mayabela/screens/golive_self_service_screen.dart';
import 'package:mayabela/widgets/notification_preference_settings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/dashboard_registry.dart';
import 'package:mayabela/services/phone_launch_service.dart';
import 'package:mayabela/services/school_support_contact_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/services/device_calendar_export_service.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/settings_ui.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _prefs = UserPreferencesService.instance;
  late List<String> _order;
  late String _roleKey;

  AppStrings get s => AppLocale.instance.strings;

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_rebuild);
    _prefs.addListener(_rebuild);
    _roleKey = AuthService.currentUser?.roleKey ?? AuthService.roleTeacher;
    final defaults = DashboardRegistry.defaultOrderFor(_roleKey);
    _order = _prefs
        .getOrder(_roleKey, defaults)
        .where((id) {
          final entry = DashboardRegistry.find(_roleKey, id);
          return entry != null && DashboardRegistry.shouldShow(entry);
        })
        .toList();
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_rebuild);
    _prefs.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  DashboardEntry? _entry(String id) => DashboardRegistry.find(_roleKey, id);

  void _saveOrder() {
    _prefs.setOrder(_roleKey, _order);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.dashboardLayoutSaved),
        backgroundColor: SettingsPalette.deep,
      ),
    );
  }

  List<({String question, String answer})> get _faqItems => [
        (question: s.settingsFaqLogin, answer: s.settingsFaqLoginAnswer),
        (question: s.settingsFaqNotifications, answer: s.settingsFaqNotificationsAnswer),
        (question: s.settingsFaqLanguage, answer: s.settingsFaqLanguageAnswer),
        (question: s.settingsFaqDashboard, answer: s.settingsFaqDashboardAnswer),
        (question: s.settingsFaqSupport, answer: s.settingsFaqSupportAnswer),
      ];

  void _showAboutSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: SettingsPalette.card,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: listPagePadding(context).copyWith(top: 20, bottom: 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: SettingsPalette.headerGradient,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppInfo.name,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          AppInfo.tagline,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.9),
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _AboutRow(label: s.settingsAppVersion, value: AppInfo.versionLabel),
            _AboutRow(label: s.settingsBuild, value: AppInfo.buildNumber),
            _AboutRow(label: s.settingsSupportEmail, value: _supportEmailForDisplay()),
            const SizedBox(height: 12),
            Text(
              s.settingsAboutDescription,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                height: 1.45,
                color: SettingsPalette.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _copySupportEmail() {
    final email = _supportEmailForDisplay();
    Clipboard.setData(ClipboardData(text: email));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(s.settingsEmailCopied),
        backgroundColor: SettingsPalette.deep,
      ),
    );
  }

  String _supportEmailForDisplay() {
    if (SchoolSupportContactService.instance.showSchoolAdminSupport) {
      final contact = SchoolSupportContactService.instance.forActiveSchool();
      if (contact?.hasEmail == true) return contact!.email!;
    }
    return AppInfo.supportEmail;
  }

  Future<void> _callSchoolAdmin() async {
    final contact = SchoolSupportContactService.instance.forActiveSchool();
    if (contact?.hasPhone != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.settingsSchoolAdminUnavailable)),
      );
      return;
    }
    final ok = await PhoneLaunchService.instance.dial(contact!.phone!);
    if (!mounted || ok) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(s.callFailed)),
    );
  }

  Future<void> _emailSchoolAdmin() async {
    final contact = SchoolSupportContactService.instance.forActiveSchool();
    if (contact?.hasEmail != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.settingsSchoolAdminUnavailable)),
      );
      return;
    }
    final uri = Uri(
      scheme: 'mailto',
      path: contact!.email,
      queryParameters: {
        'subject': 'Maya Edu — ${contact.schoolName} support',
      },
    );
    if (!await launchUrl(uri)) {
      if (!mounted) return;
      Clipboard.setData(ClipboardData(text: contact.email!));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.settingsEmailCopied)),
      );
    }
  }

  List<Widget> _buildSupportTiles() {
    final support = SchoolSupportContactService.instance;
    if (support.showSchoolAdminSupport) {
      final contact = support.forActiveSchool();
      final adminLabel = contact?.adminName?.trim().isNotEmpty == true
          ? contact!.adminName!
          : s.settingsContactSchoolAdmin;

      return [
        if (contact?.hasAnyContact == true) ...[
          SettingsActionTile(
            icon: Icons.support_agent_rounded,
            title: adminLabel,
            subtitle: contact!.schoolName,
            onTap: null,
          ),
          const SizedBox(height: 8),
          if (contact.hasPhone)
            SettingsActionTile(
              icon: Icons.phone_in_talk_rounded,
              title: s.settingsSchoolAdminPhone,
              subtitle: contact.phone!,
              onTap: _callSchoolAdmin,
            ),
          if (contact.hasPhone) const SizedBox(height: 8),
          if (contact.hasEmail)
            SettingsActionTile(
              icon: Icons.mail_outline_rounded,
              title: s.settingsSchoolAdminEmail,
              subtitle: contact.email!,
              onTap: _emailSchoolAdmin,
            ),
        ] else
          SettingsActionTile(
            icon: Icons.info_outline_rounded,
            title: s.settingsContactSchoolAdmin,
            subtitle: s.settingsSchoolAdminUnavailable,
            onTap: null,
          ),
      ];
    }

    return [
      SettingsActionTile(
        icon: Icons.mail_outline_rounded,
        title: s.settingsContactSupport,
        subtitle: AppInfo.supportEmail,
        onTap: _copySupportEmail,
      ),
    ];
  }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColors = isDark
        ? [
            scheme.surfaceContainerHighest,
            scheme.surfaceContainerHigh,
            scheme.surface,
          ]
        : SettingsPalette.headerGradient;

    return Scaffold(
      backgroundColor: scheme.surface,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 132,
            pinned: true,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                s.settings,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  shadows: [
                    Shadow(
                      color: Colors.black26,
                      blurRadius: 6,
                      offset: Offset(0, 1),
                    ),
                  ],
                ),
              ),
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: headerColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      right: -16,
                      top: 24,
                      child: Icon(
                        Icons.tune_rounded,
                        size: 100,
                        color: Colors.white.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: listPagePadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SettingsSectionCard(
                    title: s.changeLanguage,
                    subtitle: s.settingsLanguageHint,
                    icon: Icons.translate_rounded,
                    child: const AnimatedLanguageSelector(),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: s.settingsAppearance,
                    subtitle: s.settingsAppearanceHint,
                    icon: Icons.dark_mode_outlined,
                    child: SettingsToggleTile(
                      icon: Icons.nightlight_round,
                      title: s.settingsDarkMode,
                      subtitle: _prefs.darkMode
                          ? s.settingsDarkModeHint
                          : s.settingsLightModeHint,
                      value: _prefs.darkMode,
                      onChanged: _prefs.setDarkMode,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: s.dashboardLayout,
                    subtitle: s.dragToReorder,
                    icon: Icons.dashboard_customize_outlined,
                    child: Column(
                      children: [
                        ReorderableListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _order.length,
                          onReorderItem: (index, newOffset) {
                            setState(() {
                              final newIndex = index + newOffset;
                              final item = _order.removeAt(index);
                              _order.insert(newIndex, item);
                            });
                            _prefs.setOrder(_roleKey, _order);
                          },
                          itemBuilder: (context, index) {
                            final id = _order[index];
                            final entry = _entry(id);
                            if (entry == null ||
                                !DashboardRegistry.shouldShow(entry)) {
                              return SizedBox(key: ValueKey(id));
                            }
                            return Container(
                              key: ValueKey(id),
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: SettingsPalette.surface,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: SettingsPalette.border),
                              ),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor:
                                      SettingsPalette.accentSoft,
                                  child: Icon(
                                    entry.icon,
                                    color: SettingsPalette.accent,
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  s.dashboardTitle(id, roleKey: _roleKey),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                trailing: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() {
                                    _order =
                                        DashboardRegistry.defaultOrderFor(
                                            _roleKey);
                                  });
                                  _prefs.resetOrder(
                                    _roleKey,
                                    DashboardRegistry.defaultOrderFor(
                                        _roleKey),
                                  );
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: SettingsPalette.deep,
                                  side: const BorderSide(
                                    color: SettingsPalette.border,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(s.resetLayout),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _saveOrder,
                                style: FilledButton.styleFrom(
                                  backgroundColor: SettingsPalette.accent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                ),
                                child: Text(s.saveLayout),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const NotificationPreferenceSettings(),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: s.preferences,
                    subtitle: s.settingsPreferencesHint,
                    icon: Icons.tune_outlined,
                    child: Column(
                      children: [
                        SettingsToggleTile(
                          icon: Icons.view_compact_outlined,
                          title: s.compactDashboard,
                          subtitle: s.compactDashboardHint,
                          value: _prefs.compactDashboard,
                          onChanged: (v) =>
                              setState(() => _prefs.setCompactDashboard(v)),
                        ),
                        SettingsToggleTile(
                          icon: Icons.celebration_outlined,
                          title: s.ethiopianHolidays,
                          subtitle: s.ethiopianHolidaysHint,
                          value: _prefs.showEthiopianHolidays,
                          onChanged: (v) => setState(
                            () => _prefs.setShowEthiopianHolidays(v),
                          ),
                        ),
                        if (DeviceCalendarExportService.instance.isSupported)
                          SettingsToggleTile(
                            icon: Icons.phone_android_outlined,
                            title: s.syncDeviceCalendar,
                            subtitle: s.syncDeviceCalendarHint,
                            value: _prefs.syncEventsToDeviceCalendar,
                            onChanged: (v) => setState(
                              () => _prefs.setSyncEventsToDeviceCalendar(v),
                            ),
                          ),
                        SettingsToggleTile(
                          icon: Icons.notifications_active_outlined,
                          title: s.highlightNotifications,
                          subtitle: s.highlightNotificationsHint,
                          value: _prefs.autoOpenNotifications,
                          onChanged: (v) => setState(
                            () => _prefs.setAutoOpenNotifications(v),
                          ),
                        ),
                        SettingsToggleTile(
                          icon: Icons.vibration_outlined,
                          title: s.settingsHapticFeedback,
                          subtitle: s.settingsHapticFeedbackHint,
                          value: _prefs.hapticFeedback,
                          onChanged: (v) =>
                              setState(() => _prefs.setHapticFeedback(v)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const AppSecuritySettings(),
                  const SizedBox(height: 16),
                  const MfaSettingsCard(),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: s.changePassword,
                    subtitle: s.changePasswordHint,
                    icon: Icons.lock_reset_rounded,
                    child: SettingsActionTile(
                      icon: Icons.vpn_key_outlined,
                      title: s.changePassword,
                      subtitle: s.changePasswordHint,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ChangePasswordScreen(),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: s.settingsHelpSupport,
                    subtitle: SchoolSupportContactService.instance
                            .showSchoolAdminSupport
                        ? s.settingsContactSchoolAdminHint
                        : s.settingsHelpSupportHint,
                    icon: Icons.help_outline_rounded,
                    child: Column(
                      children: [
                        SettingsFaqList(items: _faqItems),
                        const SizedBox(height: 8),
                        ..._buildSupportTiles(),
                        const SizedBox(height: 8),
                        SettingsActionTile(
                          icon: Icons.privacy_tip_outlined,
                          title: s.settingsPrivacyPolicy,
                          subtitle: s.settingsPrivacyPolicyHint,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoliveSelfServiceScreen(
                                  initialTab: 1,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        SettingsActionTile(
                          icon: Icons.menu_book_outlined,
                          title: 'Training manuals',
                          subtitle: 'Short admin, teacher, and parent guides',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GoliveSelfServiceScreen(
                                  initialTab: 2,
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        SettingsActionTile(
                          icon: Icons.description_outlined,
                          title: s.settingsTermsOfUse,
                          subtitle: s.settingsTermsHint,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.settingsOpeningSoon)),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  SettingsSectionCard(
                    title: s.settingsAboutApp,
                    subtitle: s.settingsAboutAppHint,
                    icon: Icons.info_outline_rounded,
                    child: Column(
                      children: [
                        SettingsActionTile(
                          icon: Icons.apps_rounded,
                          title: AppInfo.name,
                          subtitle: AppInfo.versionLabel,
                          onTap: _showAboutSheet,
                        ),
                        const SizedBox(height: 8),
                        SettingsActionTile(
                          icon: Icons.system_update_outlined,
                          title: s.settingsCheckUpdates,
                          subtitle: s.settingsCheckUpdatesHint,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(s.settingsUpToDate)),
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        SettingsActionTile(
                          icon: Icons.cleaning_services_outlined,
                          title: s.settingsClearCache,
                          subtitle: s.settingsClearCacheHint,
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(s.settingsCacheCleared),
                                backgroundColor: SettingsPalette.deep,
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  const _AboutRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: SettingsPalette.muted,
                fontSize: 13,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: SettingsPalette.deep,
            ),
          ),
        ],
      ),
    );
  }
}
