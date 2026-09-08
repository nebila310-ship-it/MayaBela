import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Horizontal scroller for wide [DataTable]s.
///
/// [minChildWidth] keeps columns from compressing. A thick, always-visible
/// scrollbar is shown when the table is wider than the parent. Mouse and
/// trackpad can drag the table on web.
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
  ScrollController? _owned;

  ScrollController get _controller => widget.controller ?? _owned!;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _owned = ScrollController();
    }
  }

  @override
  void didUpdateWidget(covariant WebErpHScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == null && widget.controller != null) {
      _owned?.dispose();
      _owned = null;
    } else if (oldWidget.controller != null && widget.controller == null) {
      _owned = ScrollController();
    }
  }

  @override
  void dispose() {
    _owned?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final parentHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
                ? constraints.maxHeight
                : 0.0;
        final width = math.max(parentWidth, widget.minChildWidth);
        final canScroll = parentWidth > 0 && width > parentWidth + 0.5;

        Widget table = widget.child;
        if (width > 0) {
          table = SizedBox(
            width: width,
            height: parentHeight > 0 ? parentHeight : null,
            child: parentHeight > 0
                ? SingleChildScrollView(
                    primary: false,
                    child: widget.child,
                  )
                : widget.child,
          );
        }

        Widget scroller = ScrollConfiguration(
          behavior: const _MouseAndTouchScrollBehavior(),
          child: Scrollbar(
            controller: _controller,
            thumbVisibility: true,
            trackVisibility: canScroll || kIsWeb,
            interactive: true,
            thickness: 12,
            radius: const Radius.circular(8),
            scrollbarOrientation: ScrollbarOrientation.bottom,
            child: SingleChildScrollView(
              controller: _controller,
              primary: false,
              scrollDirection: Axis.horizontal,
              child: table,
            ),
          ),
        );

        if (parentHeight > 0) {
          scroller = SizedBox(height: parentHeight, child: scroller);
        }
        return scroller;
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
