import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/maya_assistant_service.dart';
import 'package:mayabela/widgets/maya_assistant_chat_body.dart';

/// Role-branded Maya AI / guidance chatbot portal (full-screen).
class MayaAssistantScreen extends StatefulWidget {
  const MayaAssistantScreen({
    super.key,
    this.roleKey,
  });

  /// Portal role: admin/teacher/parent/student/driver/platform_owner.
  final String? roleKey;

  @override
  State<MayaAssistantScreen> createState() => _MayaAssistantScreenState();
}

class _MayaAssistantScreenState extends State<MayaAssistantScreen> {
  static const _bgTop = Color(0xFFF0FDFA);
  static const _bgBottom = Color(0xFFFAFAFA);

  final _chatKey = GlobalKey<MayaAssistantChatBodyState>();

  String get _role =>
      widget.roleKey ??
      AuthService.currentUser?.roleKey ??
      AuthService.roleAdmin;

  String get _title => MayaAssistantService.titleForRole(_role);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [_bgTop, _bgBottom],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _Header(
                title: _title,
                subtitle: MayaAssistantService.subtitleForRole(_role),
                onBack: () => Navigator.pop(context),
                onClear: () => _chatKey.currentState?.clearChat(),
              ),
              Expanded(
                child: MayaAssistantChatBody(
                  key: _chatKey,
                  roleKey: _role,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.subtitle,
    required this.onBack,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final VoidCallback onBack;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(4, 4, 8, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: AppLocale.instance.strings.mayaAssistantClear,
            onPressed: onClear,
            icon: const Icon(Icons.refresh, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
