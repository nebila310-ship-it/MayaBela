import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:mayabela/l10n/app_strings.dart';

import 'package:mayabela/screens/login_screen.dart';

import 'package:mayabela/screens/settings_screen.dart';

import 'package:mayabela/services/app_lock_service.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/notification_preference_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/push_notification_service.dart';
import 'package:mayabela/services/platform_owner_service.dart';
import 'package:mayabela/services/platform_audit_log_service.dart';
import 'package:mayabela/services/school_audit_log_service.dart';
import 'package:mayabela/services/platform_expiry_alert_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/session_prefs_service.dart';
import 'package:mayabela/services/user_preferences_service.dart';

import 'package:mayabela/utils/app_navigator.dart';
import 'package:mayabela/utils/auth_navigation.dart';
import 'package:mayabela/utils/critical_bootstrap_gate.dart';
import 'package:mayabela/utils/startup_profiler.dart';

import 'package:mayabela/database/school_database_service.dart';
import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/enrollment_service.dart';
import 'package:mayabela/services/persistence/auth_persistence_service.dart';
import 'package:mayabela/services/persistence/enrollment_persistence_service.dart';
import 'package:mayabela/services/cloud_bootstrap_service.dart';
import 'package:mayabela/services/crash_reporting.dart';
import 'package:mayabela/services/persistence/cloud_connectivity_sync.dart';
import 'package:mayabela/services/persistence/cloud_outbox_service.dart';
import 'package:mayabela/services/persistence/daily_activity_persistence_service.dart';
import 'package:mayabela/services/persistence/grade_audit_persistence_service.dart';
import 'package:mayabela/services/persistence/grade_persistence_service.dart';
import 'package:mayabela/services/persistence/homework_persistence_service.dart';
import 'package:mayabela/services/persistence/inventory_persistence_service.dart';
import 'package:mayabela/services/persistence/learning_materials_persistence_service.dart';
import 'package:mayabela/services/material_purchase_service.dart';
import 'package:mayabela/services/persistence/message_persistence_service.dart';
import 'package:mayabela/services/persistence/school_content_persistence_service.dart';
import 'package:mayabela/services/persistence/student_persistence_service.dart';
import 'package:mayabela/services/persistence/driver_persistence_service.dart';
import 'package:mayabela/services/persistence/employee_persistence_service.dart';
import 'package:mayabela/services/persistence/bus_persistence_service.dart';
import 'package:mayabela/services/persistence/teacher_persistence_service.dart';
import 'package:mayabela/services/persistence/timetable_persistence_service.dart';

import 'package:mayabela/services/school_data_service.dart';
import 'package:mayabela/services/student_registry_service.dart';

import 'package:mayabela/database/supabase/supabase_storage_bootstrap.dart';
import 'package:mayabela/services/cloud/fcm_service.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';

import 'package:mayabela/setup/dashboard_setup.dart';

import 'package:mayabela/theme/app_theme.dart';
import 'package:mayabela/widgets/app_lock_gate.dart';
import 'package:mayabela/widgets/system_nav_safe_scope.dart';



Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  CrashReporting.install();
  await runZonedGuarded(() async {
    StartupProfiler.start('main.total');
    await StartupProfiler.track(
      'main.supabaseInitialize',
      () => SupabaseBootstrap.tryInitialize(deferAnonymousAuth: true),
    );
    CriticalBootstrapGate.bind(_bootstrapCriticalForLogin);
    await CloudOutboxService.instance.ensureLoaded();
    CloudConnectivityLifecycleObserver.instance.attach();
    unawaited(CloudConnectivitySync.start());
    StartupProfiler.end('main.total');
    runApp(const MayaSchoolApp());
  }, (error, stack) {
    unawaited(CrashReporting.report(error, stack, fatal: true));
  });
}

bool _backgroundBootstrapStarted = false;
bool _backgroundBootstrapDone = false;

/// Minimal work required before showing [LoginScreen] (<2s target).
Future<void> bootstrapCriticalForLogin() => CriticalBootstrapGate.ensureReady();

Future<void> _bootstrapCriticalForLogin() async {
  StartupProfiler.start('bootstrap.critical.total');

  registerAllDashboards();

  final firebaseReady = await SupabaseBootstrap.tryInitialize(
    deferAnonymousAuth: true,
  );

  await StartupProfiler.track('bootstrap.critical.localPersistence', () async {
    await Future.wait([
      AuthPersistenceService.instance.loadMerged(),
      EnrollmentPersistenceService.instance.loadIntoEnrollmentService(),
      StudentPersistenceService.instance.loadRegistryIntoService(),
      TeacherPersistenceService.instance.loadRegistryIntoService(),
      DriverPersistenceService.instance.loadRegistryIntoService(),
      EmployeePersistenceService.instance.loadRegistryIntoService(),
      BusPersistenceService.instance.loadIntoService(),
      AppLocale.instance.load(),
      UserPreferencesService.instance.load(),
      SchoolRegistryService.instance.load(),
      LoginPrefsService.instance.load(),
      NotificationPreferenceService.instance.load(),
    ]);
  });

  AuthService.ensureRegistryLoginAccounts();
  EnrollmentService.instance.ensureSeeded();

  await StartupProfiler.track(
    'bootstrap.critical.appLock',
    AppLockService.instance.init,
  );

  StartupProfiler.end('bootstrap.critical.total');
  if (!firebaseReady && kDebugMode) {
    debugPrint('[Startup] Firebase not ready — using local data only');
  }
}

/// Non-essential startup work (Firestore pull, FCM, notifications, full DB).
Future<void> bootstrapBackgroundServices() async {
  if (_backgroundBootstrapDone) return;

  if (_backgroundBootstrapStarted && CloudBootstrapService.pullCompleted) {
    _backgroundBootstrapDone = true;
    return;
  }
  _backgroundBootstrapStarted = true;

  StartupProfiler.start('bootstrap.background.total');

  await StartupProfiler.track('bootstrap.background.heavyPersistence', () async {
    await Future.wait([
      StudentPersistenceService.instance.loadMedicalOverrides(),
      GradePersistenceService.instance.loadIntoSchoolDataService(),
      GradeAuditPersistenceService.instance.loadIntoService(),
      DailyActivityPersistenceService.instance.loadIntoSchoolDataService(),
      HomeworkPersistenceService.instance.loadIntoSchoolDataService(),
      LearningMaterialsPersistenceService.instance.loadIntoSchoolDataService(),
      MaterialPurchaseService.instance.load(),
      InventoryPersistenceService.instance.loadIntoService(),
      MessagePersistenceService.instance.loadIntoSchoolDataService(),
      SchoolContentPersistenceService.instance.loadIntoSchoolDataService(),
      TimetablePersistenceService.instance.loadIntoTimetableService(),
      PlatformOwnerService.instance.load(),
      PlatformAuditLogService.instance.load(),
      SchoolAuditLogService.instance.load(),
    ]);
  });

  AuthService.ensureRegistryLoginAccounts();

  _backgroundBootstrapDone = true;

  EnrollmentService.instance.ensureSeeded();

  final firebaseReady = SupabaseBootstrap.isInitialized;

  await StartupProfiler.track(
    'bootstrap.background.schoolDatabase',
    () => SchoolDatabaseService.instance.initialize(
      useFirestore: firebaseReady,
    ),
  );

  if (firebaseReady && SchoolDatabaseService.instance.useFirestore) {
    try {
      await SchoolDatabaseService.instance
          .syncFromRegistries()
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
  }

  if (firebaseReady) {
    unawaited(StartupProfiler.track('bootstrap.background.fcm', FcmService.instance.init));
    unawaited(
      StartupProfiler.track(
        'bootstrap.background.firebaseStorage',
        SupabaseStorageBootstrap.ensureReady,
      ),
    );
  }

  SchoolDataService.instance.syncEnrollmentFromRegistry();

  unawaited(StartupProfiler.track(
    'bootstrap.background.pushNotifications',
    PushNotificationService.instance.init,
  ));
  unawaited(StartupProfiler.track(
    'bootstrap.background.platformExpiryAlerts',
    PlatformExpiryAlertService.instance.checkAndNotifyOwner,
  ));

  unawaited(_syncStudentsInBackground());

  StartupProfiler.end('bootstrap.background.total');
  StartupProfiler.printSummary();
}

@Deprecated('Use bootstrapCriticalForLogin + bootstrapBackgroundServices')
Future<void> bootstrapAppServices() async {
  await bootstrapCriticalForLogin();
  await bootstrapBackgroundServices();
}

Future<void> _syncStudentsInBackground() async {
  for (final student in StudentRegistryService.instance.getAllStudents()) {
    SchoolDataService.instance.syncChildFromRegistry(student.studentId);
  }
  SchoolDataService.instance.publishDueCalendarAnnouncements();
}



class MayaSchoolApp extends StatefulWidget {

  const MayaSchoolApp({super.key});



  @override

  State<MayaSchoolApp> createState() => _MayaSchoolAppState();

}



class _MayaSchoolAppState extends State<MayaSchoolApp> {

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_rebuild);
    UserPreferencesService.instance.addListener(_rebuild);
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_rebuild);
    UserPreferencesService.instance.removeListener(_rebuild);
    super.dispose();
  }



  void _rebuild() => setState(() {});



  @override

  Widget build(BuildContext context) {

    final prefs = UserPreferencesService.instance;
    return MaterialApp(
      navigatorKey: rootNavigatorKey,
      debugShowCheckedModeBanner: false,
      title: AppLocale.instance.strings.appTitle,
      locale: Locale(AppLocale.instance.materialLocaleCode),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('am'),
      ],
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: prefs.darkMode ? ThemeMode.dark : ThemeMode.light,
      builder: (context, child) {
        // Do NOT put sync/Maya overlays in a Stack here. On Flutter web,
        // builder-level Stack siblings of the navigator grey the whole page
        // when those chips are hovered. Overlays live in [AppFloatingChrome].
        return SystemNavSafeScope(
          child: AppLockGate(child: child ?? const SizedBox.shrink()),
        );
      },
      routes: {
        '/settings': (_) => const SettingsScreen(),
      },
      home: const AppBootstrap(),
    );

  }

}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  late Widget _home = kIsWeb
      ? const LoginScreen()
      : const Scaffold(body: Center(child: CircularProgressIndicator()));

  @override
  void initState() {
    super.initState();
    if (kIsWeb) {
      unawaited(_boot());
    } else {
      _boot();
    }
  }

  Future<void> _boot() async {
    var restored = false;

    try {
      await bootstrapCriticalForLogin().timeout(
        Duration(seconds: kIsWeb ? 8 : 15),
      );
    } catch (e, stack) {
      if (kDebugMode) {
        debugPrint('[AppBootstrap] critical bootstrap failed: $e');
      }
      unawaited(CrashReporting.report(e, stack, fatal: false));
    }

    try {
      unawaited(bootstrapBackgroundServices());

      restored = await StartupProfiler.track(
        'bootstrap.sessionRestore',
        () => SessionPrefsService.instance
            .restoreActiveSession()
            .timeout(const Duration(seconds: 2)),
      );
      if (restored) {
        AppLockService.instance.ensureSessionMonitoring();
        unawaited(SessionCloudSync.startSessionWithCloudSync());
        unawaited(NotificationService.instance.onSessionStarted());
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[AppBootstrap] session bootstrap failed: $e');
      }
      restored = false;
    }

    StartupProfiler.printSummary(title: 'Cold Start Summary');

    if (!mounted) return;
    if (restored) {
      setState(() {
        _home = AuthNavigation.homeForCurrentUser();
      });
    } else if (!kIsWeb) {
      setState(() => _home = const LoginScreen());
    }
  }

  @override
  Widget build(BuildContext context) => _home;
}

