import 'package:shared_preferences/shared_preferences.dart';
import 'package:mayabela/services/push_notification_service.dart';
import 'package:mayabela/services/school_platform_insight.dart';
import 'package:mayabela/services/school_registry_service.dart';

class ExpiryAlertItem {
  ExpiryAlertItem({
    required this.schoolId,
    required this.schoolName,
    required this.daysLeft,
    required this.expiryDate,
    required this.isExpired,
  });

  final String schoolId;
  final String schoolName;
  final int? daysLeft;
  final DateTime? expiryDate;
  final bool isExpired;

  String get summary {
    if (isExpired) {
      final ago = daysLeft == null ? 0 : -daysLeft!;
      return ago == 0 ? 'Expired today' : 'Expired $ago days ago';
    }
    if (daysLeft == null) return 'No expiry set';
    if (daysLeft == 0) return 'Expires today';
    if (daysLeft == 1) return 'Expires tomorrow';
    return 'Expires in $daysLeft days';
  }
}

class PlatformExpiryAlertService {
  PlatformExpiryAlertService._();
  static final instance = PlatformExpiryAlertService._();

  static const _lastNotifyKey = 'platform_expiry_last_notify';
  static const alertWithinDays = 30;

  List<ExpiryAlertItem> expiringSchools({int withinDays = alertWithinDays}) {
    final items = <ExpiryAlertItem>[];
    for (final school in SchoolRegistryService.instance.getAllSchools()) {
      final insight = SchoolPlatformInsight.forSchool(school);
      final expiry = school.subscriptionExpiresAt;
      if (expiry == null) continue;

      final days = insight.daysUntilExpiry;
      if (days == null) continue;

      final isExpired = days < 0;
      final inWindow = days <= withinDays;
      if (!isExpired && !inWindow) continue;

      items.add(
        ExpiryAlertItem(
          schoolId: school.id,
          schoolName: school.name,
          daysLeft: days,
          expiryDate: expiry,
          isExpired: isExpired,
        ),
      );
    }

    items.sort((a, b) {
      final da = a.daysLeft ?? 9999;
      final db = b.daysLeft ?? 9999;
      return da.compareTo(db);
    });
    return items;
  }

  List<ExpiryAlertItem> get urgentAlerts =>
      expiringSchools(withinDays: 7).where((e) => e.isExpired || (e.daysLeft ?? 99) <= 7).toList();

  bool get hasAlerts => expiringSchools().isNotEmpty;

  Future<void> checkAndNotifyOwner() async {
    final alerts = urgentAlerts;
    if (alerts.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final today = _dayKey(DateTime.now());
    if (prefs.getString(_lastNotifyKey) == today) return;

    final expired = alerts.where((a) => a.isExpired).length;
    final soon = alerts.where((a) => !a.isExpired).length;

    final parts = <String>[];
    if (expired > 0) parts.add('$expired expired');
    if (soon > 0) parts.add('$soon expiring within 7 days');

    await PushNotificationService.instance.showPlatformOwnerAlert(
      title: 'Maya Platform · subscription alert',
      body: parts.join(' · '),
    );
    await prefs.setString(_lastNotifyKey, today);
  }

  String _dayKey(DateTime dt) => '${dt.year}-${dt.month}-${dt.day}';
}
