// =============================================================================
// ScoreColors — theme extension for confidence / geo-score color tokens
// =============================================================================
//
// Provides a unified red/amber/green scale for any "how confident is this
// number" badge across the app: Live confidence, Survey detection
// confidence, and Explore geo-model scores.
//
// Design rationale (see dev/STYLE_GUIDE.md → "Score & Confidence Color
// Tokens"):
//   • Three buckets only: low (< 0.40), mid (0.40–0.70), high (> 0.70).
//   • Color is never the only signal — pair with a label or shape change.
//
// Usage:
// ```dart
// final scoreColors = Theme.of(context).extension<ScoreColors>()!;
// final color = scoreColors.forScore(detection.confidence);
// ```
// =============================================================================

import 'package:flutter/material.dart';

/// Unified color tokens for confidence and geo-score badges.
@immutable
class ScoreColors extends ThemeExtension<ScoreColors> {
  const ScoreColors({
    required this.low,
    required this.mid,
    required this.high,
  });

  /// Color used for low-confidence values (< [midThreshold]).
  final Color low;

  /// Color used for mid-confidence values ([midThreshold] – [highThreshold]).
  final Color mid;

  /// Color used for high-confidence values (≥ [highThreshold]).
  final Color high;

  /// Threshold separating [low] from [mid].
  static const double midThreshold = 0.40;

  /// Threshold separating [mid] from [high].
  static const double highThreshold = 0.70;

  /// Returns the bucket color for a normalized 0–1 score.
  Color forScore(double score) {
    if (score < midThreshold) return low;
    if (score < highThreshold) return mid;
    return high;
  }

  /// Light-theme defaults (#E53935 / #FB8C00 / #43A047).
  static const ScoreColors light = ScoreColors(
    low: Color(0xFFE53935),
    mid: Color(0xFFFB8C00),
    high: Color(0xFF43A047),
  );

  /// Dark-theme defaults — slightly lighter for legibility on dark
  /// surfaces (#EF5350 / #FFB74D / #66BB6A).
  static const ScoreColors dark = ScoreColors(
    low: Color(0xFFEF5350),
    mid: Color(0xFFFFB74D),
    high: Color(0xFF66BB6A),
  );

  @override
  ScoreColors copyWith({Color? low, Color? mid, Color? high}) {
    return ScoreColors(
      low: low ?? this.low,
      mid: mid ?? this.mid,
      high: high ?? this.high,
    );
  }

  @override
  ScoreColors lerp(ThemeExtension<ScoreColors>? other, double t) {
    if (other is! ScoreColors) return this;
    return ScoreColors(
      low: Color.lerp(low, other.low, t) ?? low,
      mid: Color.lerp(mid, other.mid, t) ?? mid,
      high: Color.lerp(high, other.high, t) ?? high,
    );
  }
}
