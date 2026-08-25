import 'package:flutter/material.dart';

/// Horizontal scroller for wide [DataTable]s on phone web.
///
/// Keeps the table at least as wide as the parent so desktop layout is unchanged.
class WebErpHScroll extends StatelessWidget {
  const WebErpHScroll({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minWidth =
            constraints.maxWidth.isFinite ? constraints.maxWidth : 0.0;
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: minWidth),
            child: child,
          ),
        );
      },
    );
  }
}
