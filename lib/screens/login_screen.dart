import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mayabela/utils/critical_bootstrap_gate.dart';
import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/app_lock_service.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/login_prefs_service.dart';
import 'package:mayabela/services/school_auth_cloud_service.dart';
import 'package:mayabela/services/school_registry_service.dart';
import 'package:mayabela/services/notification_service.dart';
import 'package:mayabela/services/cloud/session_cloud_sync.dart';
import 'package:mayabela/services/cloud_sync_progress_service.dart';
import 'package:mayabela/services/session_prefs_service.dart';
import 'package:mayabela/theme/login_role_theme.dart';
import 'package:mayabela/utils/auth_navigation.dart';
import 'package:mayabela/utils/startup_profiler.dart';
import 'package:mayabela/utils/phone_utils.dart';
import 'package:mayabela/screens/enrollment_screens.dart';
import 'package:mayabela/screens/platform_console_screen.dart';
import 'package:mayabela/widgets/platform_pin_flows.dart';
import 'package:mayabela/screens/change_password_screen.dart';
import 'package:mayabela/screens/forgot_password_screen.dart';
import 'package:mayabela/screens/student_forgot_password_screen.dart';
import 'package:mayabela/utils/scroll_safe_area.dart';
import 'package:mayabela/widgets/login_brand_header.dart';
import 'package:mayabela/widgets/ethiopian_phone_field.dart';
import 'package:mayabela/widgets/dom_backed_text_field.dart';
import 'package:mayabela/web_erp/login/web_login_shell.dart';
import 'package:mayabela/web_erp/utils/web_viewport.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  String selectedRole = AuthService.roleTeacher;

  final TextEditingController schoolId = TextEditingController();
  final TextEditingController username = TextEditingController();
  final TextEditingController password = TextEditingController();

  bool rememberMe = false;
  bool _showPassword = false;
  bool _loggingIn = false;
  String message = '';
  bool _prefsLoaded = false;
  bool _schoolIdEditing = false;
  int _logoTapCount = 0;
  DateTime? _lastLogoTap;
  final FocusNode _schoolIdFocus = FocusNode();

  /// Strict phone-only roles (digits field with +251 prefix).
  /// Teacher / staff / admin use "Phone or username" free text instead —
  /// the old digits-only field silently dropped usernames and broke login.
  bool get _usesPhoneLogin {
    final apiRole = AuthService.apiRoleKeyForLogin(selectedRole);
    return apiRole == AuthService.roleParent ||
        apiRole == AuthService.roleDriver;
  }

  String _loginIdentifierValue() {
    final raw = username.text.trim();
    if (_usesPhoneLogin) {
      final local = EthiopianPhoneField.localFromInput(raw);
      if (local.isNotEmpty) return PhoneUtils.loginKey(local);
      return PhoneUtils.loginKey(raw);
    }
    // Phone or username: normalize Ethiopian mobiles, keep usernames as-is.
    final local = PhoneUtils.normalizeLocal(raw);
    if (local != null) return local;
    return raw;
  }

  AppStrings get s => AppLocale.instance.strings;
  LoginRoleTheme get _theme => LoginRoleTheme.forRole(selectedRole);

  bool get _schoolBrandLogoVisible {
    final id = schoolId.text.trim();
    if (id.isEmpty) return false;
    final record = SchoolRegistryService.instance.lookup(id);
    if (record == null) return false;
    return (record.logoPath?.isNotEmpty == true) ||
        (record.logoUrl?.isNotEmpty == true);
  }

  @override
  void initState() {
    super.initState();
    AppLocale.instance.addListener(_onLocaleChanged);
    _schoolIdFocus.addListener(_onSchoolIdFocusChanged);
    if (kIsWeb) {
      _prefsLoaded = true;
      unawaited(_restoreSavedLogin());
    } else {
      _restoreSavedLogin();
    }
  }

  void _onSchoolIdFocusChanged() {
    if (_schoolIdFocus.hasFocus) return;
    if (!_schoolIdEditing) return;
    final id = schoolId.text.trim();
    if (id.isNotEmpty) {
      LoginPrefsService.instance.saveLastSchoolId(id);
      _applySavedEntryForSchoolId(id);
    }
    if (mounted) setState(() => _schoolIdEditing = false);
  }

  Future<void> _restoreSavedLogin() async {
    await StartupProfiler.track('login.restoreSavedLogin', () async {
      await LoginPrefsService.instance.load();
    });
    final lastId = LoginPrefsService.instance.lastSchoolId;
    final entry = LoginPrefsService.instance.latestEntry;
    if (!mounted) return;

    if (lastId != null && lastId.isNotEmpty) {
      schoolId.text = lastId;
      _schoolIdEditing = false;
    } else {
      _schoolIdEditing = true;
    }

    if (LoginPrefsService.instance.rememberEnabled && entry != null) {
      setState(() {
        rememberMe = true;
        selectedRole = entry.roleKey;
        schoolId.text = entry.schoolId;
        username.text = entry.identifier;
        password.clear();
        _schoolIdEditing = false;
        _prefsLoaded = true;
      });
    } else {
      if (lastId != null && lastId.isNotEmpty) {
        _applySavedEntryForSchoolId(lastId);
      }
      setState(() => _prefsLoaded = true);
    }
  }

  void _applySavedEntryForSchoolId(String schoolIdValue) {
    final entry = LoginPrefsService.instance.findEntry(
          schoolId: schoolIdValue,
          roleKey: selectedRole,
        ) ??
        LoginPrefsService.instance.findEntry(schoolId: schoolIdValue);
    if (entry == null) return;
    setState(() {
      selectedRole = entry.roleKey;
      schoolId.text = entry.schoolId;
      username.text = entry.identifier;
      password.clear();
      rememberMe = true;
    });
  }

  void _selectRole(String roleKey) {
    setState(() => selectedRole = roleKey);
    if (schoolId.text.trim().isNotEmpty) {
      _applySavedEntryForSchoolId(schoolId.text.trim());
    }
  }

  @override
  void dispose() {
    AppLocale.instance.removeListener(_onLocaleChanged);
    _schoolIdFocus.removeListener(_onSchoolIdFocusChanged);
    _schoolIdFocus.dispose();
    schoolId.dispose();
    username.dispose();
    password.dispose();
    super.dispose();
  }

  void _onLocaleChanged() => setState(() {});

  Future<void> login() async {
    setState(() {
      message = '';
      _loggingIn = true;
    });

    try {
      await CriticalBootstrapGate.ensureReady().timeout(
        Duration(seconds: kIsWeb ? 8 : 12),
      );
    } catch (_) {}

    if (!kIsWeb) {
      await SessionCloudSync.applyLocalForCurrentUser();
    }

    var error = await AuthService.validateLoginAsync(
      roleKey: AuthService.apiRoleKeyForLogin(selectedRole),
      username: _loginIdentifierValue(),
      password: password.text,
      schoolId: schoolId.text.trim().toUpperCase(),
    );

    if (error != null) {
      setState(() {
        _loggingIn = false;
        message = switch (error) {
          'empty' => s.enterUsernamePassword,
          'invalid' => s.invalidCredentials,
          'role_mismatch' => s.useUsernameForRole,
          'school_mismatch' =>
            'School ID does not match this account. Check the School ID from your school admin.',
          'account_inactive' => 'This student account is not active. Contact your school admin.',
          'portal_disabled' => 'Student portal is disabled for this school.',
          'cloud_required' =>
            'Cloud login could not connect to Supabase. Check your internet and try again. If it keeps failing, the school-login function may be down.',
          'password_too_short' => s.passwordTooShort,
          'rate_limited' =>
            'Too many login attempts. Please wait a few minutes and try again.',
          'school_inactive' => s.schoolAccessMessage('school_inactive'),
          _ => s.invalidCredentials,
        };
      });
      return;
    }

    AuthService.applySchoolContext(schoolId.text.trim().toUpperCase());
    final schoolError = AuthService.schoolAccessError(AuthService.activeSchoolId);
    if (schoolError != null) {
      setState(() {
        _loggingIn = false;
        message = s.schoolAccessMessage(schoolError);
      });
      AuthService.clearSession();
      return;
    }

    // Teacher tile = classroom only; Administration Staff tile = staff roles only.
    if (selectedRole == AuthService.roleTeacher &&
        AuthService.isAdministrationStaff) {
      setState(() {
        _loggingIn = false;
        message =
            'This account is Administration Staff. Sign in as Administration Staff.';
      });
      AuthService.clearSession();
      unawaited(SchoolAuthCloudService.instance.signOutCloud());
      return;
    }
    if (selectedRole == AuthService.roleStaff &&
        !AuthService.isAdministrationStaff) {
      setState(() {
        _loggingIn = false;
        message =
            'This account is a classroom Teacher. Sign in as Teacher.';
      });
      AuthService.clearSession();
      unawaited(SchoolAuthCloudService.instance.signOutCloud());
      return;
    }

    if (selectedRole == AuthService.roleParent ||
        selectedRole == AuthService.roleTeacher ||
        selectedRole == AuthService.roleStaff ||
        selectedRole == AuthService.roleAdmin ||
        selectedRole == AuthService.roleDriver ||
        selectedRole == AuthService.roleStudent) {
      if (!kIsWeb) {
        await StartupProfiler.track(
          'login.applyLocalSession',
          SessionCloudSync.applyLocalForCurrentUser,
        );
      }
    }

    final savedIdentifier = _usesPhoneLogin
        ? _loginIdentifierValue()
        : username.text.trim();

    AppLockService.instance.handleLoginSuccess();

    if (!mounted) return;

    setState(() => _loggingIn = false);

    // New accounts get a unique temp password and must change it once.
    final Widget next = AuthService.requiresPasswordChange()
        ? const ChangePasswordScreen(forced: true)
        : AuthNavigation.homeForCurrentUser();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => next),
    );

    unawaited(SessionCloudSync.startSessionWithCloudSync());
    unawaited(_persistLoginSideEffects(savedIdentifier));
  }

  Future<void> _persistLoginSideEffects(String savedIdentifier) async {
    try {
      await LoginPrefsService.instance
          .saveLastSchoolId(schoolId.text)
          .timeout(const Duration(seconds: 3));
      await LoginPrefsService.instance
          .saveLogin(
            remember: rememberMe,
            schoolId: schoolId.text,
            roleKey: selectedRole,
            identifier: savedIdentifier,
            password: password.text,
          )
          .timeout(const Duration(seconds: 3));
      await SessionPrefsService.instance
          .saveActiveSession()
          .timeout(const Duration(seconds: 3));
      await NotificationService.instance
          .onSessionStarted()
          .timeout(const Duration(seconds: 4));
    } catch (_) {}
  }

  Future<void> _onLogoTap() async {
    final now = DateTime.now();
    if (_lastLogoTap == null ||
        now.difference(_lastLogoTap!) > const Duration(seconds: 4)) {
      _logoTapCount = 0;
    }
    _lastLogoTap = now;
    _logoTapCount++;
    if (_logoTapCount < 7) return;
    _logoTapCount = 0;

    final unlocked = await showPlatformPinDialog(context);
    if (!unlocked || !mounted) return;

    CloudSyncProgressService.instance.reset();
    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => const PlatformConsoleScreen()),
    );
  }

  Widget _buildTopBar(LoginRoleTheme theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: theme.shadowTint.withValues(alpha: 0.35),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _buildAnimatedLanguageSelector(theme),
    );
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    Widget? suffixIcon,
    Widget? prefixIcon,
  }) {
    if (kIsWeb) {
      return webLoginFieldDecoration(
        label: label,
        hint: hint,
        suffixIcon: suffixIcon,
        prefixIcon: prefixIcon,
      );
    }
    return InputDecoration(
      labelText: label,
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: _theme.primary, width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildAnimatedLanguageSelector(LoginRoleTheme theme) {
    const options = [
      ('en', 'EN'),
      ('am', 'አማ'),
      ('om', 'OM'),
    ];
    const segmentWidth = 42.0;
    const barHeight = 32.0;

    final selected = AppLocale.instance.code;
    final activeIndex = options.indexWhere((o) => o.$1 == selected);
    final index = activeIndex < 0 ? 0 : activeIndex;

    return SizedBox(
      width: segmentWidth * options.length,
      height: barHeight,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          AnimatedPositioned(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic,
            left: index * segmentWidth + 4,
            top: 4,
            bottom: 4,
            width: segmentWidth - 8,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.primary,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: theme.shadowTint.withValues(alpha: 0.45),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
            ),
          ),
          Row(
            children: [
              for (final (code, label) in options)
                SizedBox(
                  width: segmentWidth,
                  height: barHeight,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => AppLocale.instance.setLanguage(code),
                      child: Center(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          curve: Curves.easeOut,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: selected == code
                                ? Colors.white
                                : Colors.grey.shade700,
                          ),
                          child: Text(label),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  static const _webFieldTextStyle = TextStyle(color: Colors.white);

  Widget _buildWebRoleTile(String roleKey) {
    final selected = selectedRole == roleKey;
    final roleTheme = LoginRoleTheme.forRole(roleKey);

    return Material(
      color: selected
          ? WebLoginCard.accentOrange.withValues(alpha: 0.18)
          : const Color(0xFF1E2F45),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => _selectRole(roleKey),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? WebLoginCard.accentOrange
                  : Colors.white.withValues(alpha: 0.12),
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                roleTheme.icon,
                size: 20,
                color: selected ? WebLoginCard.accentOrange : Colors.white70,
              ),
              const SizedBox(height: 4),
              Text(
                s.roleLabel(roleKey),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : Colors.white60,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTile(String roleKey) {
    if (kIsWeb) return _buildWebRoleTile(roleKey);
    final selected = selectedRole == roleKey;
    final roleTheme = LoginRoleTheme.forRole(roleKey);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      child: Material(
        color: selected ? roleTheme.primary : Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16),
        elevation: selected ? 4 : 0,
        shadowColor: roleTheme.shadowTint,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _selectRole(roleKey),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? roleTheme.primary : roleTheme.borderTint,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  roleTheme.icon,
                  size: 22,
                  color: selected ? Colors.white : roleTheme.primary,
                ),
                const SizedBox(height: 6),
                Text(
                  s.roleLabel(roleKey),
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : roleTheme.taglineColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _beginSchoolIdEdit() {
    setState(() => _schoolIdEditing = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _schoolIdFocus.requestFocus();
        schoolId.selection = TextSelection(
          baseOffset: 0,
          extentOffset: schoolId.text.length,
        );
      }
    });
  }

  Widget _buildSchoolIdField() {
    if (!_prefsLoaded && !kIsWeb) {
      return const SizedBox(
        height: 56,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final savedIds = LoginPrefsService.instance.savedSchoolIds;
    final hasValue = schoolId.text.trim().isNotEmpty;
    final settled = hasValue && !_schoolIdEditing;

    final decoration = _fieldDecoration(
      label: s.schoolId,
      hint: settled ? null : 'TB-001',
      suffixIcon: settled
          ? IconButton(
              tooltip: 'Edit School ID',
              icon: Icon(
                Icons.edit_outlined,
                color: kIsWeb ? Colors.white54 : Colors.grey.shade600,
                size: 20,
              ),
              onPressed: _beginSchoolIdEdit,
            )
          : savedIds.isNotEmpty
              ? IconButton(
                  tooltip: s.savedSchoolIdsHint,
                  icon: Icon(
                    Icons.history,
                    color: kIsWeb ? WebLoginCard.accentOrange : _theme.primary,
                  ),
                  onPressed: () => _showSavedSchoolIdsMenu(savedIds),
                )
              : null,
    );
    final style = kIsWeb
        ? _webFieldTextStyle.copyWith(
            fontWeight: settled ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: settled ? 0.6 : 0,
          )
        : TextStyle(
            fontWeight: settled ? FontWeight.w700 : FontWeight.w500,
            fontSize: settled ? 16 : 14,
            letterSpacing: settled ? 0.6 : 0,
          );

    return DomBackedTextField(
      controller: schoolId,
      focusNode: _schoolIdFocus,
      readOnly: settled,
      decoration: decoration,
      textCapitalization: TextCapitalization.characters,
      autofillHint: 'organization',
      style: style,
      onChanged: (_) {
        if (!_schoolIdEditing) setState(() => _schoolIdEditing = true);
        setState(() {});
      },
      onSubmitted: (value) {
        final id = value.trim();
        if (id.isNotEmpty) {
          LoginPrefsService.instance.saveLastSchoolId(id);
          _applySavedEntryForSchoolId(id);
        }
        _schoolIdFocus.unfocus();
      },
    );
  }

  Future<void> _showSavedSchoolIdsMenu(List<String> ids) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                s.savedSchoolIdsHint,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            ...ids.map(
              (id) => ListTile(
                leading: Icon(Icons.school_outlined, color: _theme.primary),
                title: Text(id),
                onTap: () => Navigator.pop(context, id),
              ),
            ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        schoolId.text = picked;
        _schoolIdEditing = false;
      });
      LoginPrefsService.instance.saveLastSchoolId(picked);
      _applySavedEntryForSchoolId(picked);
    }
  }

  Widget _buildBackgroundDecor(LoginRoleTheme theme) {
    return Stack(
      children: [
        Positioned(
          top: -60,
          right: -40,
          child: _SoftOrb(
            color: Colors.white.withValues(alpha: 0.12),
            size: 220,
          ),
        ),
        Positioned(
          top: 120,
          left: -50,
          child: _SoftOrb(
            color: theme.primaryLight.withValues(alpha: 0.25),
            size: 160,
          ),
        ),
        Positioned(
          bottom: 40,
          right: -30,
          child: _SoftOrb(
            color: Colors.black.withValues(alpha: 0.08),
            size: 140,
          ),
        ),
        Positioned(
          bottom: 180,
          left: 24,
          child: Icon(
            theme.icon,
            size: 120,
            color: Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginFormFields(LoginRoleTheme theme) {
    // Six login roles don't fit as tiles (esp. phone). Prefer dropdown.
    final useRoleDropdown =
        AuthService.loginRoles.length > 5 || (kIsWeb && WebViewport.isNarrow(context));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (useRoleDropdown)
          DropdownButtonFormField<String>(
            key: ValueKey('login-role-$selectedRole'),
            initialValue: selectedRole,
            isExpanded: true,
            dropdownColor: const Color(0xFF1E2F45),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            iconEnabledColor: Colors.white70,
            decoration: _fieldDecoration(
              label: s.signInAs,
              prefixIcon: const Icon(Icons.badge_outlined, color: Colors.white54),
            ),
            selectedItemBuilder: (context) => [
              for (final role in AuthService.loginRoles)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    s.roleLabel(role),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
            items: [
              for (final role in AuthService.loginRoles)
                DropdownMenuItem(
                  value: role,
                  child: Text(
                    s.roleLabel(role),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
            ],
            onChanged: (v) {
              if (v != null) _selectRole(v);
            },
          )
        else
          Row(
            children: [
              for (var i = 0; i < AuthService.loginRoles.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                Expanded(child: _buildRoleTile(AuthService.loginRoles[i])),
              ],
            ],
          ),
        const SizedBox(height: 20),
        _buildSchoolIdField(),
        const SizedBox(height: 12),
        if (_usesPhoneLogin)
          Theme(
            data: kIsWeb
                ? Theme.of(context).copyWith(
                    textTheme: Theme.of(context)
                        .textTheme
                        .apply(bodyColor: Colors.white),
                    colorScheme: Theme.of(context).colorScheme.copyWith(
                          primary: WebLoginCard.accentOrange,
                        ),
                  )
                : Theme.of(context),
            child: EthiopianPhoneField(
              controller: username,
              decoration: _fieldDecoration(
                label: s.loginIdentifierLabel(selectedRole),
                hint: s.phoneLoginHint,
                prefixIcon: kIsWeb
                    ? const Icon(Icons.person_outline, color: Colors.white54)
                    : null,
              ),
            ),
          )
        else
          DomBackedTextField(
            controller: username,
            keyboardType: TextInputType.text,
            style: kIsWeb ? _webFieldTextStyle : null,
            autofillHint: 'username',
            decoration: _fieldDecoration(
              label: s.loginIdentifierLabel(selectedRole),
              prefixIcon: kIsWeb
                  ? const Icon(Icons.person_outline, color: Colors.white54)
                  : null,
            ),
          ),
        const SizedBox(height: 12),
        DomBackedTextField(
          controller: password,
          obscureText: !_showPassword,
          style: kIsWeb ? _webFieldTextStyle : null,
          autofillHint: 'current-password',
          decoration: _fieldDecoration(
            label: s.password,
            prefixIcon: kIsWeb
                ? const Icon(Icons.lock_outline, color: Colors.white54)
                : null,
            suffixIcon: IconButton(
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
              icon: Icon(
                _showPassword
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: kIsWeb ? Colors.white54 : Colors.grey.shade600,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Checkbox(
              value: rememberMe,
              activeColor:
                  kIsWeb ? WebLoginCard.accentOrange : theme.primary,
              checkColor: kIsWeb ? const Color(0xFF162236) : null,
              side: kIsWeb
                  ? BorderSide(color: Colors.white.withValues(alpha: 0.4))
                  : null,
              onChanged: (v) async {
                final checked = v ?? false;
                setState(() => rememberMe = checked);
                if (!checked) {
                  await LoginPrefsService.instance.clearAll();
                }
              },
            ),
            Expanded(
              child: Text(
                s.rememberMe,
                style: kIsWeb
                    ? const TextStyle(color: Colors.white70)
                    : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildSignInButton(theme),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: kIsWeb
                  ? Colors.red.withValues(alpha: 0.15)
                  : Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: kIsWeb
                    ? Colors.redAccent.withValues(alpha: 0.5)
                    : Colors.red.shade200,
              ),
            ),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: kIsWeb ? Colors.redAccent.shade100 : Colors.red.shade800,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSignInButton(LoginRoleTheme theme) {
    if (kIsWeb) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loggingIn ? null : login,
          style: ElevatedButton.styleFrom(
            backgroundColor: WebLoginCard.accentOrange,
            foregroundColor: const Color(0xFF162236),
            disabledBackgroundColor:
                WebLoginCard.accentOrange.withValues(alpha: 0.5),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: const StadiumBorder(),
            elevation: 6,
            shadowColor: WebLoginCard.accentOrange.withValues(alpha: 0.45),
          ),
          child: _loggingIn
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFF162236),
                  ),
                )
              : Text(
                  s.login.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.4,
                  ),
                ),
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [theme.primary, theme.primaryLight]),
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: theme.shadowTint,
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: _loggingIn ? null : login,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: _loggingIn
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : Text(
                  s.login,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildWebLogin(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = WebViewport.isNarrow(context);
    final phone = WebViewport.isCompactPhone(context);
    final cardMaxWidth = phone
        ? width - 32
        : width < 480
            ? width - 24
            : 440.0;

    final loginCard = ConstrainedBox(
      constraints: BoxConstraints(
        maxWidth: cardMaxWidth,
        minWidth: compact ? 0 : 360,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: phone ? 0 : (compact ? 12 : 28),
          horizontal: phone ? 0 : (compact ? 12 : 20),
        ),
        child: WebLoginCard(
          showNotch: !phone,
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              compact ? 20 : 28,
              compact ? 22 : 28,
              compact ? 20 : 28,
              20,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GestureDetector(
                    onTap: _onLogoTap,
                    child: Row(
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            const Icon(
                              Icons.school_rounded,
                              color: Color(0xFF42A5F5),
                              size: 34,
                            ),
                            Positioned(
                              right: -2,
                              bottom: -2,
                              child: Icon(
                                Icons.school_rounded,
                                color: WebLoginCard.accentOrange,
                                size: 18,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'SIGN IN',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${s.signInAs} ${s.roleLabel(selectedRole)}',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.55),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 22),
                  _buildLoginFormFields(_theme),
                  const SizedBox(height: 16),
                  Center(
                    child: TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => selectedRole ==
                                    AuthService.roleStudent
                                ? const StudentForgotPasswordScreen()
                                : const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        s.forgotPassword,
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      'v1.0.4-bus',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const WebLoginBackground(),
          if (!phone) const WebLoginWatermark(),
          if (phone)
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - 28,
                      ),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: _buildTopBar(_theme),
                          ),
                          const SizedBox(height: 12),
                          loginCard,
                          const SizedBox(height: 16),
                          TextButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const ParentSignUpScreen(),
                                ),
                              );
                            },
                            child: Text(
                              s.registerAsParent,
                              style: const TextStyle(
                                color: Color(0xFF0D47A1),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            )
          else
            SafeArea(
              child: compact
                  ? SingleChildScrollView(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: loginCard,
                      ),
                    )
                  : Row(
                      children: [
                        const Spacer(flex: 3),
                        loginCard,
                        const Spacer(flex: 2),
                      ],
                    ),
            ),
          if (!phone) ...[
            Positioned(
              top: 16,
              right: compact ? 12 : 24,
              child: SafeArea(child: _buildTopBar(_theme)),
            ),
            Positioned(
              bottom: compact ? 12 : 20,
              left: 0,
              right: 0,
              child: Center(
                child: TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ParentSignUpScreen(),
                      ),
                    );
                  },
                  child: Text(
                    s.registerAsParent,
                    style: const TextStyle(
                      color: Color(0xFF0D47A1),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMobileLogin(BuildContext context) {
    final theme = _theme;

    return Scaffold(
      body: AnimatedContainer(
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: theme.gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _buildBackgroundDecor(theme),
            Positioned(
              top: 0,
              left: 0,
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12, top: 4),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    child: Icon(
                      theme.icon,
                      key: ValueKey(selectedRole),
                      size: 68,
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              bottom: false,
              child: SingleChildScrollView(
                padding: listPagePadding(context),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildTopBar(theme),
                    ),
                    const SizedBox(height: 12),
                    LoginBrandHeader(
                      schoolId: schoolId.text,
                      onSecretTap: _onLogoTap,
                      accentColor: theme.onPrimary,
                      height: 118,
                    ),
                    const SizedBox(height: 8),
                    if (!_schoolBrandLogoVisible)
                      Text(
                        s.tagline,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: theme.onPrimary.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.2,
                        ),
                      ),
                    if (!_schoolBrandLogoVisible)
                      const SizedBox(height: 20)
                    else
                      const SizedBox(height: 12),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 350),
                      curve: Curves.easeOutCubic,
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.97),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: theme.borderTint),
                        boxShadow: [
                          BoxShadow(
                            color: theme.shadowTint,
                            blurRadius: 24,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: theme.surfaceTint,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Icon(
                                  theme.icon,
                                  color: theme.primary,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      s.signInAs,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    AnimatedDefaultTextStyle(
                                      duration:
                                          const Duration(milliseconds: 300),
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: theme.primary,
                                      ),
                                      child: Text(s.roleLabel(selectedRole)),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          _buildLoginFormFields(theme),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ParentSignUpScreen(),
                          ),
                        );
                      },
                      child: Text(
                        s.registerAsParent,
                        style: TextStyle(
                          color: theme.onPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => selectedRole == AuthService.roleStudent
                                ? const StudentForgotPasswordScreen()
                                : const ForgotPasswordScreen(),
                          ),
                        );
                      },
                      child: Text(
                        s.forgotPassword,
                        style: TextStyle(
                          color: theme.onPrimary.withValues(alpha: 0.88),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      s.loginCopyright,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.onPrimary.withValues(alpha: 0.78),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.loginPoweredBy,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.onPrimary.withValues(alpha: 0.92),
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) return _buildWebLogin(context);
    return _buildMobileLogin(context);
  }
}

class _SoftOrb extends StatelessWidget {
  const _SoftOrb({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
    );
  }
}
