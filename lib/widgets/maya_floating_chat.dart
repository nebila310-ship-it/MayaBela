import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/maya_assistant_service.dart';
import 'package:mayabela/widgets/maya_assistant_chat_body.dart';

/// Bottom-right floating Maya AI chat (FAB + expandable panel).
///
/// Always returns a [Positioned] so it never becomes an expanding Stack child
/// (that causes a full-screen grey wash on Flutter web hover).
class MayaFloatingChat extends StatefulWidget {
  const MayaFloatingChat({super.key});

  @override
  State<MayaFloatingChat> createState() => _MayaFloatingChatState();
}

class _MayaFloatingChatState extends State<MayaFloatingChat>
    with SingleTickerProviderStateMixin {
  static const _accent = Color(0xFF0F766E);

  final _chatKey = GlobalKey<MayaAssistantChatBodyState>();
  bool _open = false;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..addListener(() {
        if (mounted) setState(() {});
      });
    AuthService.sessionListenable.addListener(_onSession);
  }

  @override
  void dispose() {
    AuthService.sessionListenable.removeListener(_onSession);
    _anim.dispose();
    super.dispose();
  }

  void _onSession() {
    if (!mounted) return;
    if (AuthService.currentUser == null && _open) {
      _open = false;
      _anim.value = 0;
    }
    setState(() {});
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) {
      _anim.forward();
    } else {
      _anim.reverse();
    }
  }

  void _close() {
    if (!_open) return;
    setState(() => _open = false);
    _anim.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final user = AuthService.currentUser;

    // Keep Positioned as the Stack direct-path root even when logged out.
    return Positioned(
      right: 16,
      bottom: 16 + bottomInset,
      child: user == null
          ? const SizedBox.shrink()
          : _MayaChatBody(
              userRole: user.roleKey,
              open: _open,
              anim: _anim,
              chatKey: _chatKey,
              onToggle: _toggle,
              onClose: _close,
            ),
    );
  }
}

class _MayaChatBody extends StatelessWidget {
  const _MayaChatBody({
    required this.userRole,
    required this.open,
    required this.anim,
    required this.chatKey,
    required this.onToggle,
    required this.onClose,
  });

  final String userRole;
  final bool open;
  final AnimationController anim;
  final GlobalKey<MayaAssistantChatBodyState> chatKey;
  final VoidCallback onToggle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final title = MayaAssistantService.titleForRole(userRole);
    final size = MediaQuery.sizeOf(context);
    final panelWidth = size.width < 520 ? size.width - 24.0 : 400.0;
    final panelHeight = (size.height * 0.62).clamp(360.0, 560.0);
    final showPanel = open || anim.value > 0.01;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (showPanel)
          IgnorePointer(
            ignoring: !open,
            child: FadeTransition(
              opacity: anim,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFF0FDFA), Color(0xFFFAFAFA)],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      border: Border.all(
                        color: _MayaFloatingChatState._accent
                            .withValues(alpha: 0.2),
                      ),
                      boxShadow: kIsWeb
                          ? const []
                          : const [
                              BoxShadow(
                                color: Color(0x33000000),
                                blurRadius: 12,
                                offset: Offset(0, 4),
                              ),
                            ],
                    ),
                    child: SizedBox(
                      width: panelWidth,
                      height: panelHeight * anim.value.clamp(0.01, 1.0),
                      child: Column(
                        children: [
                          _FloatingHeader(
                            title: title,
                            subtitle: MayaAssistantService.subtitleForRole(
                              userRole,
                            ),
                            onClose: onClose,
                            onClear: () => chatKey.currentState?.clearChat(),
                          ),
                          Expanded(
                            child: MayaAssistantChatBody(
                              key: chatKey,
                              roleKey: userRole,
                              compact: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        _MayaFab(open: open, onPressed: onToggle),
      ],
    );
  }
}

class _FloatingHeader extends StatelessWidget {
  const _FloatingHeader({
    required this.title,
    required this.subtitle,
    required this.onClose,
    required this.onClear,
  });

  final String title;
  final String subtitle;
  final VoidCallback onClose;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF0F766E), Color(0xFF0D9488), Color(0xFF14B8A6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.auto_awesome, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          _HeaderIconButton(icon: Icons.refresh, onTap: onClear),
          _HeaderIconButton(icon: Icons.close, onTap: onClose),
        ],
      ),
    );
  }
}

class _HeaderIconButton extends StatelessWidget {
  const _HeaderIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, color: Colors.white, size: 20),
        ),
      ),
    );
  }
}

class _MayaFab extends StatelessWidget {
  const _MayaFab({required this.open, required this.onPressed});

  final bool open;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    // No Tooltip / Material / InkWell — those trigger Flutter web hover washout.
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: _MayaFloatingChatState._accent,
            shape: BoxShape.circle,
          ),
          child: SizedBox(
            width: 56,
            height: 56,
            child: Center(
              child: Icon(
                open ? Icons.close_rounded : Icons.auto_awesome,
                color: Colors.white,
                size: 26,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
