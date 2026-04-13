// =============================================================================
// Content Width Constraint — Max-width wrapper for tablet layouts
// =============================================================================
//
// Centers content and caps its width at [maxWidth] (default 600 dp) to prevent
// stretched layouts on tablets in landscape.  Uses a simple Center + Constrained
// Box pattern so the scaffold background still fills edge-to-edge.
// =============================================================================

import 'package:flutter/material.dart';

/// Maximum content width for readable layouts on tablets.
const double kContentMaxWidth = 600;

/// Wraps [child] in a centered max-width constraint.
///
/// Use as the outermost wrapper inside a Scaffold body (or around a ListView,
/// Column, etc.) to prevent content from stretching across the full width on
/// large screens while keeping the scaffold background edge-to-edge.
class ContentWidthConstraint extends StatelessWidget {
  const ContentWidthConstraint({
    super.key,
    required this.child,
    this.maxWidth = kContentMaxWidth,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
