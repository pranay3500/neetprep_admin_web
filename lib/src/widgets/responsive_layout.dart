import 'package:flutter/material.dart';

/// Width below which the admin shell uses a drawer instead of a fixed sidebar.
const double kAdminCompactBreakpoint = 720;

bool isAdminCompactLayout(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  // shortestSide catches phones in landscape; width catches narrow viewports.
  return size.width < kAdminCompactBreakpoint || size.shortestSide < 600;
}

/// Stacks [leading] above [actions] on narrow widths; keeps a horizontal row on wide.
Widget responsiveToolbar({
  required BuildContext context,
  required Widget leading,
  required List<Widget> actions,
  double breakpoint = kAdminCompactBreakpoint,
  double spacing = 8,
}) {
  return LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < breakpoint) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            leading,
            if (actions.isNotEmpty) ...[
              SizedBox(height: spacing),
              Wrap(
                spacing: spacing,
                runSpacing: spacing,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: actions,
              ),
            ],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(child: leading),
          for (final action in actions) ...[
            SizedBox(width: spacing),
            action,
          ],
        ],
      );
    },
  );
}
