import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/models/notification_preference.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';
import 'package:mayabela/widgets/settings_ui.dart';

class NotificationPreferenceSettings extends StatefulWidget {
  const NotificationPreferenceSettings({super.key});

  @override
  State<NotificationPreferenceSettings> createState() =>
      _NotificationPreferenceSettingsState();
}

class _NotificationPreferenceSettingsState
    extends State<NotificationPreferenceSettings> {
  final _prefs = NotificationPreferenceService.instance;
  final _userPrefs = UserPreferencesService.instance;
  late String _roleKey;

  @override
  void initState() {
    super.initState();
    _roleKey = AuthService.currentUser?.roleKey ?? AuthService.roleParent;
    _prefs.addListener(_rebuild);
    _userPrefs.addListener(_rebuild);
  }

  @override
  void dispose() {
    _prefs.removeListener(_rebuild);
    _userPrefs.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  String _label(AppStrings s, NotificationPreferenceKey key) {
    return switch (key) {
      NotificationPreferenceKey.master => s.pushNotificationsMaster,
      NotificationPreferenceKey.homework => s.notifyHomework,
      NotificationPreferenceKey.messages => s.notifyMessages,
      NotificationPreferenceKey.transport => s.notifyTransport,
      NotificationPreferenceKey.announcements => s.notifyAnnouncements,
      NotificationPreferenceKey.grades => s.notifyGrades,
      NotificationPreferenceKey.attendance => s.notifyAttendance,
      NotificationPreferenceKey.gallery => s.notifyGallery,
      NotificationPreferenceKey.dailyActivity => s.notifyDailyActivity,
      NotificationPreferenceKey.fees => s.notifyFees,
      NotificationPreferenceKey.calendar => s.notifyCalendar,
    };
  }

  String? _hint(AppStrings s, NotificationPreferenceKey key) {
    return switch (key) {
      NotificationPreferenceKey.master => s.pushNotificationsMasterHint,
      NotificationPreferenceKey.homework => s.notifyHomeworkHint,
      NotificationPreferenceKey.messages => s.notifyMessagesHint,
      NotificationPreferenceKey.transport => s.notifyTransportHint,
      NotificationPreferenceKey.announcements => s.notifyAnnouncementsHint,
      NotificationPreferenceKey.grades => s.notifyGradesHint,
      NotificationPreferenceKey.attendance => s.notifyAttendanceHint,
      NotificationPreferenceKey.gallery => s.notifyGalleryHint,
      NotificationPreferenceKey.dailyActivity => s.notifyDailyActivityHint,
      NotificationPreferenceKey.fees => s.notifyFeesHint,
      NotificationPreferenceKey.calendar => s.notifyCalendarHint,
    };
  }

  IconData _icon(NotificationPreferenceKey key) {
    return switch (key) {
      NotificationPreferenceKey.master => Icons.notifications_active_outlined,
      NotificationPreferenceKey.homework => Icons.menu_book_outlined,
      NotificationPreferenceKey.messages => Icons.chat_bubble_outline,
      NotificationPreferenceKey.transport => Icons.directions_bus_outlined,
      NotificationPreferenceKey.announcements => Icons.campaign_outlined,
      NotificationPreferenceKey.grades => Icons.grade_outlined,
      NotificationPreferenceKey.attendance => Icons.fact_check_outlined,
      NotificationPreferenceKey.gallery => Icons.photo_library_outlined,
      NotificationPreferenceKey.dailyActivity => Icons.today_outlined,
      NotificationPreferenceKey.fees => Icons.payments_outlined,
      NotificationPreferenceKey.calendar => Icons.calendar_month_outlined,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        final keys = NotificationPreferenceService.keysForRole(_roleKey);
        final masterOn =
            _prefs.isEnabled(_roleKey, NotificationPreferenceKey.master);

        return SettingsSectionCard(
          title: s.pushNotificationsSection,
          subtitle: s.pushNotificationsSectionHint,
          icon: Icons.notifications_outlined,
          child: Column(
            children: [
              for (final key in keys) ...[
                SettingsToggleTile(
                  icon: _icon(key),
                  title: _label(s, key),
                  subtitle: _hint(s, key),
                  value: _prefs.isEnabled(_roleKey, key),
                  enabled: key == NotificationPreferenceKey.master || masterOn,
                  onChanged: (key != NotificationPreferenceKey.master &&
                          !masterOn)
                      ? null
                      : (value) => _prefs.setEnabled(_roleKey, key, value),
                ),
              ],
              SettingsToggleTile(
                icon: Icons.volume_up_outlined,
                title: s.notificationSounds,
                subtitle: s.notificationSoundsHint,
                value: _userPrefs.notificationSounds,
                enabled: masterOn,
                onChanged: masterOn
                    ? (value) => _userPrefs.setNotificationSounds(value)
                    : null,
              ),
            ],
          ),
        );
      },
    );
  }
}
