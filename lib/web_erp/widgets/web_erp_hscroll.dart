import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

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

  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (resolved) {
      final e = resolved as PointerScrollEvent;
      if (_horizontal.hasClients) {
        final pos = _horizontal.position;
        if (pos.hasContentDimensions && pos.maxScrollExtent > 0) {
          final delta =
              e.scrollDelta.dx != 0 ? e.scrollDelta.dx : e.scrollDelta.dy;
          final next = (pos.pixels + delta)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          if (next != pos.pixels) {
            _horizontal.jumpTo(next);
            return;
          }
        }
      }
      if (_vertical.hasClients) {
        final pos = _vertical.position;
        if (pos.hasContentDimensions && pos.maxScrollExtent > 0) {
          final next = (pos.pixels + e.scrollDelta.dy)
              .clamp(pos.minScrollExtent, pos.maxScrollExtent);
          if (next != pos.pixels) {
            _vertical.jumpTo(next);
          }
        }
      }
    });
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
