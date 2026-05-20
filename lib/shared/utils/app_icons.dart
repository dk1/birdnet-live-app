// =============================================================================
// App Icons — Centralized icon mapping for third-party icon packages
// =============================================================================
//
// This file isolates icon selections that come from external icon packages.
// Keeping a small app-level mapping lets us swap icon packages safely without
// touching many feature files.
// =============================================================================

import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

abstract final class AppIcons {
  /// Generic species icon used in stats chips and bird placeholders.
  static const IconData species = Symbols.raven;

  /// Placeholder icon used when a species image is unavailable.
  static const IconData speciesFallback = Symbols.raven;

  /// Summary/chart icon used for tab and stats affordances.
  static const IconData summaryChart = Symbols.bar_chart;
}
