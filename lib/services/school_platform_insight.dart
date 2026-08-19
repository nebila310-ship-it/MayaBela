import 'package:flutter/material.dart';

import 'package:mayabela/models/school_lifecycle.dart';
import 'package:mayabela/services/school_admin_credentials_service.dart';
import 'package:mayabela/services/school_enrollment_metrics_service.dart';
import 'package:mayabela/services/school_registry_service.dart';

enum SchoolHealthStatus {
  good,
  expiringSoon,
  blocked,
  needsAttention,
}

class SchoolPlatformInsight {
  SchoolPlatformInsight({
    required this.school,
    required this.metrics,
  });

  final SchoolRecord school;
  final SchoolEnrollmentMetrics metrics;

  static SchoolPlatformInsight forSchool(SchoolRecord school) {
    return SchoolPlatformInsight(
      school: school,
      metrics: SchoolEnrollmentMetricsService.instance.forSchool(school.id),
    );
  }

  int? get daysUntilExpiry {
    final expiry = school.subscriptionExpiresAt;
    if (expiry == null) return null;
    return expiry.difference(DateTime.now()).inDays;
  }

  bool get expiryWarning {
    final days = daysUntilExpiry;
    return days != null && days >= 0 && days <= 30;
  }

  bool get isExpired => school.accessBlock == SchoolAccessBlock.expired;

  bool get hasAdminPhone {
    final phone = SchoolAdminCredentialsService.instance.adminPhoneForSchool(school);
    return phone != null && phone.trim().isNotEmpty;
  }

  bool get hasSavedPassword {
    final pwd = school.adminInitialPassword?.trim();
    return pwd != null && pwd.isNotEmpty;
  }

  SchoolHealthStatus get health {
    if (!school.isAccessible) return SchoolHealthStatus.blocked;
    if (expiryWarning || isExpired) return SchoolHealthStatus.expiringSoon;
    if (!hasAdminPhone || !hasSavedPassword || metrics.hasSeatOverage) {
      return SchoolHealthStatus.needsAttention;
    }
    return SchoolHealthStatus.good;
  }

  String get healthLabel => switch (health) {
        SchoolHealthStatus.good => 'Healthy',
        SchoolHealthStatus.expiringSoon => isExpired ? 'Expired' : 'Expiring soon',
        SchoolHealthStatus.blocked => _blockedLabel,
        SchoolHealthStatus.needsAttention => 'Needs attention',
      };

  String get _blockedLabel => switch (school.accessBlock) {
        SchoolAccessBlock.inactive => 'Deactivated',
        SchoolAccessBlock.suspended => 'Suspended',
        SchoolAccessBlock.expired => 'Expired',
        _ => 'Blocked',
      };

  Color get healthColor => switch (health) {
        SchoolHealthStatus.good => Colors.green,
        SchoolHealthStatus.expiringSoon => Colors.deepOrange,
        SchoolHealthStatus.blocked => Colors.red,
        SchoolHealthStatus.needsAttention => Colors.amber,
      };

  List<String> get alerts {
    final items = <String>[];
    if (!hasAdminPhone) items.add('No admin phone on file');
    if (!hasSavedPassword) items.add('Temp password not saved');
    if (isExpired) items.add('Subscription expired');
    if (expiryWarning && !isExpired) {
      items.add('Subscription ends in ${daysUntilExpiry!} days');
    }
    if (metrics.hasSeatOverage) {
      items.add('Over contracted seats by ${metrics.seatOverage}');
    }
    if (school.status == SchoolLifecycleStatus.suspended) {
      items.add('School is suspended');
    }
    if (school.status == SchoolLifecycleStatus.inactive) {
      items.add('School is deactivated');
    }
    if (metrics.billableStudents == 0) {
      items.add('No enrolled students yet');
    }
    return items;
  }

  String get expirySummary {
    final expiry = school.subscriptionExpiresAt;
    if (expiry == null) return 'Open subscription';
    final days = daysUntilExpiry!;
    if (days < 0) return 'Expired ${-days} days ago';
    if (days == 0) return 'Expires today';
    return '$days days left (${expiry.day}/${expiry.month}/${expiry.year})';
  }
}
