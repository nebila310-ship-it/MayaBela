import 'package:flutter/material.dart';

import 'package:mayabela/l10n/app_strings.dart';
import 'package:mayabela/services/auth_service.dart';
import 'package:mayabela/services/maya_assistant_service.dart';

/// Shared Maya chat transcript + composer (used by full screen and floating panel).
class MayaAssistantChatBody extends StatefulWidget {
  const MayaAssistantChatBody({
    super.key,
    this.roleKey,
    this.compact = false,
    this.showSuggestions = true,
  });

  final String? roleKey;
  final bool compact;
  final bool showSuggestions;

  @override
  State<MayaAssistantChatBody> createState() => MayaAssistantChatBodyState();
}

class MayaAssistantChatBodyState extends State<MayaAssistantChatBody> {
  static const accent = Color(0xFF0F766E);

  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <MayaChatMessage>[];
  bool _busy = false;

  String get _role =>
      widget.roleKey ??
      AuthService.currentUser?.roleKey ??
      AuthService.roleAdmin;

  @override
  void initState() {
    super.initState();
    _resetWelcome();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void clearChat() {
    setState(_resetWelcome);
  }

  void _resetWelcome() {
    _messages
      ..clear()
      ..add(
        MayaChatMessage(
          id: 'welcome',
          text: MayaAssistantService.instance.welcomeMessage(_role),
          fromUser: false,
          at: DateTime.now(),
        ),
      );
  }

  Future<void> send([String? preset]) async {
    final text = (preset ?? _controller.text).trim();
    if (text.isEmpty || _busy) return;

    setState(() {
      _messages.add(
        MayaChatMessage(
          id: 'u-${DateTime.now().microsecondsSinceEpoch}',
          text: text,
          fromUser: true,
          at: DateTime.now(),
        ),
      );
      _busy = true;
      if (preset == null) _controller.clear();
    });
    _scrollToEnd();

    final reply = await MayaAssistantService.instance.reply(
      roleKey: _role,
      userMessage: text,
      history: List<MayaChatMessage>.from(_messages),
    );

    if (!mounted) return;
    setState(() {
      _messages.add(
        MayaChatMessage(
          id: 'a-${DateTime.now().microsecondsSinceEpoch}',
          text: reply,
          fromUser: false,
          at: DateTime.now(),
        ),
      );
      _busy = false;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = AppLocale.instance.strings;
    final suggestions = MayaAssistantService.suggestionsForRole(_role);
    final pad = widget.compact ? 12.0 : 16.0;

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.fromLTRB(pad, 8, pad, 12),
            itemCount: _messages.length + (_busy ? 1 : 0),
            itemBuilder: (context, index) {
              if (_busy && index == _messages.length) {
                return const _TypingBubble();
              }
              return _Bubble(
                message: _messages[index],
                compact: widget.compact,
              );
            },
          ),
        ),
        if (!_busy && widget.showSuggestions)
          SizedBox(
            height: 40,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: pad),
              itemCount: suggestions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tip = suggestions[index];
                return ActionChip(
                  label: Text(
                    tip,
                    style: TextStyle(fontSize: widget.compact ? 12 : 13),
                  ),
                  backgroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                  side: BorderSide(color: accent.withValues(alpha: 0.35)),
                  onPressed: () => send(tip),
                );
              },
            ),
          ),
        Padding(
          padding: EdgeInsets.fromLTRB(pad - 4, 8, pad - 4, pad - 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  minLines: 1,
                  maxLines: widget.compact ? 3 : 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => send(),
                  decoration: InputDecoration(
                    hintText: s.mayaAssistantHint,
                    filled: true,
                    fillColor: Colors.white,
                    isDense: widget.compact,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: widget.compact ? 10 : 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(22),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _busy ? null : () => send(),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.all(widget.compact ? 12 : 14),
                ),
                child: const Icon(Icons.send_rounded, size: 20),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, required this.compact});

  final MayaChatMessage message;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final mine = message.fromUser;
    final maxW = MediaQuery.sizeOf(context).width * (compact ? 0.92 : 0.82);
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: compact ? maxW.clamp(0, 340) : maxW),
        decoration: BoxDecoration(
          color: mine ? MayaAssistantChatBodyState.accent : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          message.text,
          style: TextStyle(
            color: mine ? Colors.white : const Color(0xFF134E4A),
            height: 1.35,
            fontSize: compact ? 13.5 : 14,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.teal.shade600,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              AppLocale.instance.strings.mayaAssistantThinking,
              style: TextStyle(color: Colors.teal.shade800),
            ),
          ],
        ),
      ),
    );
  }
}
