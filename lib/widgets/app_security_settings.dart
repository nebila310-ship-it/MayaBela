import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/app_lock_service.dart';
import 'package:mayabela/widgets/settings_ui.dart';

class AppSecuritySettings extends StatefulWidget {
  const AppSecuritySettings({super.key});

  @override
  State<AppSecuritySettings> createState() => _AppSecuritySettingsState();
}

class _AppSecuritySettingsState extends State<AppSecuritySettings> {
  final _lock = AppLockService.instance;

  @override
  void initState() {
    super.initState();
    _lock.addListener(_rebuild);
  }

  @override
  void dispose() {
    _lock.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  String _timeoutLabel(AppStrings s, int minutes) {
    if (minutes == 0) return s.autoLockNever;
    return s.autoLockMinutes(minutes);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppLocale.instance,
      builder: (context, _) {
        final s = AppLocale.instance.strings;
        return SettingsSectionCard(
          title: s.appSecurity,
          subtitle: s.backgroundLockSectionHint,
          icon: Icons.shield_outlined,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.backgroundLockSectionTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: SettingsPalette.deep,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AppLockService.backgroundLockOptions.map((minutes) {
                  final selected = _lock.backgroundLockMinutes == minutes;
                  return AnimatedLockTimeoutChip(
                    label: _timeoutLabel(s, minutes),
                    selected: selected,
                    onTap: () => _lock.setBackgroundLockMinutes(minutes),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }
}
