import 'dart:ui_web' as ui_web;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mayabela/web_erp/utils/ios_web_input.dart';
import 'package:web/web.dart' as web;

Widget buildDomBackedTextField({
  required TextEditingController controller,
  required InputDecoration decoration,
  bool obscureText = false,
  bool readOnly = false,
  TextInputType? keyboardType,
  TextCapitalization textCapitalization = TextCapitalization.none,
  TextStyle? style,
  ValueChanged<String>? onChanged,
  ValueChanged<String>? onSubmitted,
  FocusNode? focusNode,
  String? autofillHint,
  List<TextInputFormatter>? inputFormatters,
  TextInputAction? textInputAction,
}) {
  return _DomBackedTextField(
    controller: controller,
    decoration: decoration,
    obscureText: obscureText,
    readOnly: readOnly,
    keyboardType: keyboardType,
    textCapitalization: textCapitalization,
    style: style,
    onChanged: onChanged,
    onSubmitted: onSubmitted,
    focusNode: focusNode,
    autofillHint: autofillHint,
  );
}

class _DomBackedTextField extends StatefulWidget {
  const _DomBackedTextField({
    required this.controller,
    required this.decoration,
    required this.obscureText,
    required this.readOnly,
    required this.keyboardType,
    required this.textCapitalization,
    required this.style,
    required this.onChanged,
    required this.onSubmitted,
    required this.focusNode,
    required this.autofillHint,
  });

  final TextEditingController controller;
  final InputDecoration decoration;
  final bool obscureText;
  final bool readOnly;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final TextStyle? style;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final String? autofillHint;

  @override
  State<_DomBackedTextField> createState() => _DomBackedTextFieldState();
}

class _DomBackedTextFieldState extends State<_DomBackedTextField> {
  late final String _viewType;
  late final web.HTMLInputElement _input;
  var _syncingFromFlutter = false;
  var _focused = false;

  @override
  void initState() {
    super.initState();
    _viewType = 'mayabela-dom-input-${identityHashCode(this)}';
    _input = web.HTMLInputElement();
    _applyInputAttrs();
    _input.value = widget.controller.text;
    _input.style.cssText = _cssFor(widget.style);

    _input.onInput.listen((_) => _onDomInput());
    _input.onChange.listen((_) => _onDomInput());
    _input.onKeyDown.listen((web.KeyboardEvent e) {
      if (e.key == 'Enter') {
        widget.onSubmitted?.call(_input.value);
      }
    });
    _input.onFocus.listen((_) {
      _focused = true;
      widget.focusNode?.requestFocus();
      if (mounted) setState(() {});
    });
    _input.onBlur.listen((_) {
      _focused = false;
      widget.focusNode?.unfocus();
      if (mounted) setState(() {});
    });

    widget.controller.addListener(_syncFromController);
    widget.focusNode?.addListener(_syncFocusFromNode);

    ui_web.platformViewRegistry.registerViewFactory(
      _viewType,
      (int viewId) => _input,
    );
  }

  void _applyInputAttrs() {
    _input.type = widget.obscureText ? 'password' : _htmlType();
    _input.readOnly = widget.readOnly;
    _input.placeholder = widget.decoration.hintText ?? '';
    _input.autocomplete = widget.autofillHint ?? 'off';
    _input.spellcheck = false;
    final label = widget.decoration.labelText;
    if (label != null && label.isNotEmpty) {
      _input.setAttribute('aria-label', label);
      _input.name = label.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    }
  }

  String _htmlType() {
    final t = widget.keyboardType;
    if (t == TextInputType.phone || t == TextInputType.number) return 'tel';
    if (t == TextInputType.emailAddress) return 'email';
    return 'text';
  }

  String _cssFor(TextStyle? style) {
    final color = style?.color ?? Colors.white;
    final size = IosWebInput.fontSize(style?.fontSize);
    final weight = switch (style?.fontWeight ?? FontWeight.w500) {
      FontWeight.w100 => 100,
      FontWeight.w200 => 200,
      FontWeight.w300 => 300,
      FontWeight.w400 => 400,
      FontWeight.w500 => 500,
      FontWeight.w600 => 600,
      FontWeight.w700 => 700,
      FontWeight.w800 => 800,
      FontWeight.w900 => 900,
      _ => 500,
    };
    final transform = widget.textCapitalization == TextCapitalization.characters
        ? 'uppercase'
        : 'none';
    final letter = style?.letterSpacing ?? 0;
    return '''
      width: 100%;
      height: 100%;
      border: 0;
      outline: none;
      background: transparent;
      color: ${_cssColor(color)};
      font-size: ${size}px;
      font-weight: $weight;
      letter-spacing: ${letter}px;
      text-transform: $transform;
      padding: 0;
      margin: 0;
      box-sizing: border-box;
      font-family: inherit;
      touch-action: manipulation;
      -webkit-text-size-adjust: 100%;
    ''';
  }

  String _cssColor(Color c) {
    final r = (c.r * 255.0).round().clamp(0, 255);
    final g = (c.g * 255.0).round().clamp(0, 255);
    final b = (c.b * 255.0).round().clamp(0, 255);
    final a = c.a;
    return 'rgba($r,$g,$b,$a)';
  }

  void _onDomInput() {
    var value = _input.value;
    if (widget.textCapitalization == TextCapitalization.characters) {
      value = value.toUpperCase();
      if (_input.value != value) _input.value = value;
    }
    if (widget.controller.text == value) {
      widget.onChanged?.call(value);
      return;
    }
    _syncingFromFlutter = true;
    widget.controller.value = TextEditingValue(
      text: value,
      selection: TextSelection.collapsed(offset: value.length),
    );
    _syncingFromFlutter = false;
    widget.onChanged?.call(value);
  }

  void _syncFromController() {
    if (_syncingFromFlutter) return;
    if (_input.value != widget.controller.text) {
      _input.value = widget.controller.text;
    }
  }

  void _syncFocusFromNode() {
    final node = widget.focusNode;
    if (node == null) return;
    if (node.hasFocus) {
      _input.focus();
    } else if (web.document.activeElement == _input) {
      _input.blur();
    }
  }

  @override
  void didUpdateWidget(covariant _DomBackedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
      _input.value = widget.controller.text;
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode?.removeListener(_syncFocusFromNode);
      widget.focusNode?.addListener(_syncFocusFromNode);
    }
    if (oldWidget.obscureText != widget.obscureText ||
        oldWidget.readOnly != widget.readOnly ||
        oldWidget.autofillHint != widget.autofillHint ||
        oldWidget.decoration.labelText != widget.decoration.labelText ||
        oldWidget.decoration.hintText != widget.decoration.hintText ||
        oldWidget.keyboardType != widget.keyboardType) {
      _applyInputAttrs();
    }
    if (oldWidget.style != widget.style ||
        oldWidget.textCapitalization != widget.textCapitalization) {
      _input.style.cssText = _cssFor(widget.style);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    widget.focusNode?.removeListener(_syncFocusFromNode);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effective = widget.decoration.applyDefaults(
      Theme.of(context).inputDecorationTheme,
    );
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      child: InputDecorator(
        isFocused: _focused,
        isEmpty: widget.controller.text.isEmpty,
        decoration: effective,
        child: SizedBox(
          height: 28,
          child: HtmlElementView(viewType: _viewType),
        ),
      ),
    );
  }
}
