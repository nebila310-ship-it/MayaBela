import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Which axis [WebErpHScroll] should claim from a mouse-wheel / trackpad event.
enum WebErpHScrollWheelClaim { none, horizontal, vertical }

/// Vertical wheel over a wide table must not steal the parent page scroll.
/// Shift+wheel or a real horizontal delta still pans the table.
WebErpHScrollWheelClaim webErpHScrollWheelClaim({
  required double dx,
  required double dy,
  required bool shift,
  required bool canScrollHorizontal,
  required bool canScrollVertical,
}) {
  final horizontalDelta = dx != 0 ? dx : (shift ? dy : 0.0);
  if (horizontalDelta != 0 && canScrollHorizontal) {
    return WebErpHScrollWheelClaim.horizontal;
  }
  if (dx == 0 && !shift && dy != 0 && canScrollVertical) {
    return WebErpHScrollWheelClaim.vertical;
  }
  return WebErpHScrollWheelClaim.none;
}

/// Horizontal scroller for wide [DataTable]s.
///
/// The scroll **viewport** is pinned to the parent width. If the scroller is
/// allowed to grow with the table, [ScrollPosition.maxScrollExtent] stays 0
/// and the extra columns are only clipped — they cannot be reached.
class WebErpHScroll extends StatefulWidget {
  const WebErpHScroll({
    super.key,
    required this.child,
    this.minChildWidth = 0,
    this.controller,
  });

  final Widget child;
  final double minChildWidth;
  final ScrollController? controller;

  @override
  State<WebErpHScroll> createState() => _WebErpHScrollState();
}

class _WebErpHScrollState extends State<WebErpHScroll> {
  ScrollController? _ownedHorizontal;
  final _vertical = ScrollController();

  ScrollController get _horizontal => widget.controller ?? _ownedHorizontal!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _ownedHorizontal = ScrollController();
    }
  }

  @override
  void didUpdateWidget(covariant WebErpHScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == null && widget.controller != null) {
      _ownedHorizontal?.dispose();
      _ownedHorizontal = null;
    } else if (oldWidget.controller != null && widget.controller == null) {
      _ownedHorizontal = ScrollController();
    }
  }

  @override
  void dispose() {
    _ownedHorizontal?.dispose();
    _vertical.dispose();
    super.dispose();
  }

  bool _shiftHeld() {
    final keys = HardwareKeyboard.instance.logicalKeysPressed;
    return keys.contains(LogicalKeyboardKey.shiftLeft) ||
        keys.contains(LogicalKeyboardKey.shiftRight) ||
        keys.contains(LogicalKeyboardKey.shift);
  }

  bool _canJump(ScrollController controller, double delta) {
    if (!controller.hasClients || delta == 0) return false;
    final pos = controller.position;
    if (!pos.hasContentDimensions || pos.maxScrollExtent <= 0) return false;
    final next = (pos.pixels + delta)
        .clamp(pos.minScrollExtent, pos.maxScrollExtent);
    return next != pos.pixels;
  }

  void _jump(ScrollController controller, double delta) {
    if (!_canJump(controller, delta)) return;
    final pos = controller.position;
    controller.jumpTo(
      (pos.pixels + delta).clamp(pos.minScrollExtent, pos.maxScrollExtent),
    );
  }

  /// Only consume wheel events we can actually apply.
  ///
  /// A plain vertical wheel over a wide table used to be remapped onto
  /// horizontal scroll, which made Administration Staff Directory (and other
  /// page-scrolled directories) feel stuck. Vertical wheel now bubbles to the
  /// parent page unless this pane has its own bounded vertical scroller.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    final dx = event.scrollDelta.dx;
    final dy = event.scrollDelta.dy;
    final horizontalDelta = dx != 0 ? dx : (_shiftHeld() ? dy : 0.0);
    final claim = webErpHScrollWheelClaim(
      dx: dx,
      dy: dy,
      shift: _shiftHeld(),
      canScrollHorizontal: _canJump(_horizontal, horizontalDelta),
      canScrollVertical: _canJump(_vertical, dy),
    );
    if (claim == WebErpHScrollWheelClaim.horizontal) {
      GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
        final e = resolved as PointerScrollEvent;
        final delta =
            e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy;
        _jump(_horizontal, delta);
      });
      return;
    }
    if (claim == WebErpHScrollWheelClaim.vertical) {
      GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
        final e = resolved as PointerScrollEvent;
        _jump(_vertical, e.scrollDelta.dy);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final mq = MediaQuery.sizeOf(context);
        final viewportWidth =
            constraints.maxWidth.isFinite && constraints.maxWidth > 0
                ? constraints.maxWidth
                : (constraints.minWidth > 0 ? constraints.minWidth : mq.width);
        final hasBoundedHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0;
        final viewportHeight = hasBoundedHeight ? constraints.maxHeight : null;
        final minTableWidth = math.max(viewportWidth, widget.minChildWidth);

        Widget table = ConstrainedBox(
          constraints: BoxConstraints(minWidth: minTableWidth),
          child: widget.child,
        );

        final hView = SingleChildScrollView(
          key: const ValueKey('web-erp-hscroll-view'),
          controller: _horizontal,
          primary: false,
          scrollDirection: Axis.horizontal,
          physics: const AlwaysScrollableScrollPhysics(),
          child: table,
        );

        // Pin width so the view cannot grow with the table.
        Widget pane = SizedBox(width: viewportWidth, child: hView);

        if (hasBoundedHeight) {
          pane = SizedBox(
            width: viewportWidth,
            height: viewportHeight,
            child: Scrollbar(
              controller: _vertical,
              thumbVisibility: true,
              interactive: true,
              thickness: 10,
              notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
              child: SingleChildScrollView(
                controller: _vertical,
                primary: false,
                child: SizedBox(width: viewportWidth, child: hView),
              ),
            ),
          );
        }

        return ScrollConfiguration(
          behavior: const _MouseAndTouchScrollBehavior(),
          child: Listener(
            onPointerSignal: _onPointerSignal,
            child: Scrollbar(
              controller: _horizontal,
              thumbVisibility: true,
              trackVisibility: true,
              interactive: true,
              thickness: 14,
              radius: const Radius.circular(8),
              scrollbarOrientation: ScrollbarOrientation.bottom,
              notificationPredicate: (n) => n.metrics.axis == Axis.horizontal,
              child: pane,
            ),
          ),
        );
      },
    );
  }
}

class _MouseAndTouchScrollBehavior extends MaterialScrollBehavior {
  const _MouseAndTouchScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
        PointerDeviceKind.stylus,
      };
}
