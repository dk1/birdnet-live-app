// =============================================================================
// Session Type Visuals — Centralized icon + color mapping per app mode
// =============================================================================
//
// The app has four modes — Live, Point Count, Survey, and File Analysis —
// and each is shown with a distinct icon throughout the UI: the home menu,
// the help screen, the session library, the session review header, etc.
//
// To make modes instantly recognizable at a glance we also give each mode
// a unique accent color that we apply to the *icon foreground* only (tile
// backgrounds are intentionally left untouched so the visual rhythm of
// list / grid surfaces stays calm).
//
// The colors are chosen to be:
//   - clearly distinguishable on both light and dark themes,
//   - accessible (sufficient contrast on neutral surfaces),
//   - thematically meaningful (red = recording, blue = pinned point,
//     green = movement / route, amber = file / archive).
//
// Centralizing the mapping here avoids drift between the home screen,
// help screen, and history list views.
// =============================================================================

import 'package:flutter/material.dart';

import '../../features/live/live_session.dart';

/// Returns the icon used to represent the given [SessionType] across the
/// app (home menu, help, session library, review header, etc.).
IconData sessionTypeIcon(SessionType type) {
  switch (type) {
    case SessionType.live:
      return Icons.mic_rounded;
    case SessionType.pointCount:
      return Icons.location_on_rounded;
    case SessionType.survey:
      return Icons.route_rounded;
    case SessionType.fileUpload:
      return Icons.audio_file_rounded;
  }
}

/// Accent color used for the *icon foreground* of the given [SessionType].
///
/// Tile backgrounds are deliberately not colored — only the glyph itself
/// is tinted so modes are recognizable at a glance without overwhelming
/// the surrounding layout.
Color sessionTypeIconColor(SessionType type) {
  switch (type) {
    // Red — evokes a "record" indicator: live, real-time microphone session.
    case SessionType.live:
      return const Color(0xFFE53935);
    // Blue — a fixed pin / stationary observation.
    case SessionType.pointCount:
      return const Color(0xFF1E88E5);
    // Green — movement along a route / transect.
    case SessionType.survey:
      return const Color(0xFF43A047);
    // Amber — an archived audio file being analyzed offline.
    case SessionType.fileUpload:
      return const Color(0xFFFB8C00);
  }
}
