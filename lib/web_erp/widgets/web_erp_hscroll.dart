import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Horizontal scroller for wide [DataTable]s.
///
/// [minChildWidth] keeps the table from compressing columns into clipped
/// text. If the parent is narrower, a visible scrollbar appears.
class WebErpHScroll extends StatefulWidget {
  const WebErpHScroll({
    super.key,
    required this.child,
    this.minChildWidth = 0,
  });

  final Widget child;
  final double minChildWidth;

  @override
  State<WebErpHScroll> createState() => _WebErpHScrollState();
}

class _WebErpHScrollState extends State<WebErpHScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final parentWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        final width = math.max(parentWidth, widget.minChildWidth);
        final canScroll = parentWidth > 0 && width > parentWidth + 0.5;
        return Scrollbar(
          controller: _controller,
          thumbVisibility: canScroll,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          child: SingleChildScrollView(
            controller: _controller,
            scrollDirection: Axis.horizontal,
            child: width <= 0
                ? widget.child
                : SizedBox(
                    width: width,
                    child: widget.child,
                  ),
          ),
        );
      },
    );
  }
}
