import 'package:flutter/material.dart';

import 'package:mayabela/database/supabase/supabase_bootstrap.dart';
import 'package:mayabela/database/supabase/supabase_storage_bootstrap.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/screens/change_password_screen.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/golive_service.dart';
import 'package:mayabela/services/rbac/module_access.dart';
import 'package:mayabela/web_erp/theme/web_erp_theme.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';
import 'package:mayabela/web_erp/widgets/mail_preflight_card.dart';
import 'package:mayabela/widgets/mfa_settings_card.dart';
import 'package:mayabela/widgets/settings_ui.dart';

/// One leadership settings desk. Does not add a second campus or school list.
class WebSettingsHubPage extends StatelessWidget {
  const WebSettingsHubPage({super.key, this.onNavigate});

  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final narrow = WebViewport.isNarrow(context);
    final s = AppLocale.instance.strings;
    return ListenableBuilder(
      listenable: GoliveService.instance,
      builder: (context, _) {
        final cap = GoliveService.instance.capacitySnapshot();
        return ListView(
          padding: EdgeInsets.all(narrow ? 12 : 20),
          children: [
            Text('Settings', style: WebErpTheme.sectionTitle(context)),
            const SizedBox(height: 4),
            Text(
              'Language, password, authenticator, and the leadership checks '
              'for mail, storage, and go-live. School and campus names stay '
              'on their own desks.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
            if (cap.currentUserMustEnroll) ...[
              const SizedBox(height: 12),
              Material(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
                child: const ListTile(
                  leading: Icon(Icons.phonelink_lock_outlined),
                  title: Text('Authenticator required'),
                  subtitle: Text(
                    'School Admin must enroll a second factor on this hub.',
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            Text(
              'Leadership preflight',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                _statusChip(
                  context,
                  'Cloud',
                  SupabaseBootstrap.isInitialized,
                ),
                _statusChip(
                  context,
                  'Storage',
                  !SupabaseStorageBootstrap.deferred &&
                      SupabaseStorageBootstrap.lastError == null &&
                      SupabaseBootstrap.isInitialized,
                ),
                _statusChip(
                  context,
                  cap.mfaRequired ? 'MFA required' : 'MFA optional',
                  !cap.currentUserMustEnroll,
                ),
                const MailPreflightCard(),
              ],
            ),
            const SizedBox(height: 16),
            SettingsSectionCard(
              title: s.changeLanguage,
              subtitle: s.settingsLanguageHint,
              icon: Icons.translate_rounded,
              child: const AnimatedLanguageSelector(),
            ),
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
            Text(
              'Related desks',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (ModuleAccess.canView('go_live'))
                  _jump(context, 'go_live', 'Go-live & compliance'),
                if (ModuleAccess.canView('system_health'))
                  _jump(context, 'system_health', 'System health'),
                if (ModuleAccess.canView('staff_roles'))
                  _jump(context, 'staff_roles', 'Role permissions'),
                if (ModuleAccess.canView('grade_workflow_settings'))
                  _jump(context, 'grade_workflow_settings', 'Grade workflow'),
                if (ModuleAccess.canView('student_portal_settings'))
                  _jump(
                    context,
                    'student_portal_settings',
                    'Student portal',
                  ),
                if (ModuleAccess.canView('quality_assurance'))
                  _jump(context, 'quality_assurance', 'QA desk'),
                _jump(context, 'profile', 'Full account settings'),
              ],
            ),
            if (AuthService.currentUser != null) ...[
              const SizedBox(height: 16),
              Text(
                'Signed in as ${AuthService.currentUser!.username} '
                '(${AuthService.currentUser!.roleKey}).',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _statusChip(BuildContext context, String label, bool ok) {
    return Container(
      width: 180,
      padding: const EdgeInsets.all(16),
      decoration: WebErpTheme.cardDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.radio_button_unchecked,
            color: ok ? Colors.teal : Colors.orange,
          ),
          const SizedBox(height: 8),
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          Text(
            ok ? 'Ready' : 'Needs attention',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _jump(BuildContext context, String routeId, String label) {
    return OutlinedButton.icon(
      onPressed: onNavigate == null ? null : () => onNavigate!(routeId),
      icon: const Icon(Icons.arrow_outward, size: 16),
      label: Text(label),
    );
  }
}
